#include "app.h"
#include "instance.h"
#include "window.h"
#include <QCheckBox>
#include <QClipboard>
#include <QFile>
#include <QLabel>
#include <QPushButton>
#include <QTemporaryDir>
#include <QtTest>
using namespace boop;
class FakeMonitor final : public Monitor {
public:
  using Monitor::Monitor;
  Snapshot value;
  Status current{State::Monitoring, Issue::None};
  int refreshes = 0, wakes = 0;
  void start() override {}
  void stop() override {}
  void refresh() override { ++refreshes; }
  void reconcileAfterWake() override { ++wakes; }
  Snapshot snapshot() const override { return value; }
  Status status() const override { return current; }
  void attach(Device device) {
    value.devices.append(device);
    emit devicesChanged(value.devices);
    emit attached(device);
    emit observation({ObservationKind::Attached, device, QDateTime::currentDateTimeUtc()});
  }
  void detach(Device device) {
    value.devices.removeIf([&](const Device &item) { return item.id == device.id; });
    emit devicesChanged(value.devices);
    emit detached(device);
    emit observation({ObservationKind::Detached, device, QDateTime::currentDateTimeUtc()});
  }
};
class FakeNotifications final : public NotificationService {
public:
  bool ready = true, sound = false;
  QList<QList<Device>> groups;
  QStringList cancelled;
  int cancellations = 0;
  bool played = false;
  bool available() const override { return ready; }
  bool supportsSound() const override { return sound; }
  QString summary() const override { return ready ? "Available" : "Unavailable"; }
  void deliver(const QList<Device> &devices, bool enabled) override {
    if (ready) {
      groups.append(devices);
      played = enabled && sound;
    }
  }
  void cancel(const QString &id) override { cancelled.append(id); }
  void cancelAll() override { ++cancellations; }
};
class FakeAutostart final : public AutostartService {
public:
  bool value = false;
  bool enabled() const override { return value; }
  bool setEnabled(bool enabled) override {
    value = enabled;
    return true;
  }
  QString error() const override { return {}; }
};
Device device(QString id = "1", bool hub = false) {
  Device result;
  result.id = id;
  result.name = "USB keyboard";
  result.manufacturer = "Example";
  result.serialNumber = "sensitive serial";
  result.speed = Speed::High;
  result.isHub = hub;
  result.firstSeenAt = QDateTime::currentDateTimeUtc();
  result.connectedAt = result.firstSeenAt;
  return result;
}

// Independent reader of the two Desktop Entry parsing layers, restricted to
// literal arguments (our login entry deliberately has no variable field codes).
std::optional<QStringList> desktopArguments(const QByteArray &data) {
  QString command;
  for (const QByteArray &line : data.split('\n')) {
    if (line.startsWith("Exec="))
      command = QString::fromUtf8(line.mid(5));
  }
  QString decoded;
  for (qsizetype index = 0; index < command.size(); ++index) {
    QChar character = command[index];
    if (character == QLatin1Char('\\')) {
      if (++index == command.size())
        return std::nullopt;
      character = command[index];
      if (character == QLatin1Char('s'))
        character = QLatin1Char(' ');
      else if (character == QLatin1Char('n'))
        character = QLatin1Char('\n');
      else if (character == QLatin1Char('t'))
        character = QLatin1Char('\t');
      else if (character == QLatin1Char('r'))
        character = QLatin1Char('\r');
      else if (character != QLatin1Char('\\'))
        return std::nullopt;
    }
    decoded += character;
  }
  QStringList arguments;
  QString argument;
  bool quoted = false, started = false;
  for (qsizetype index = 0; index < decoded.size(); ++index) {
    QChar character = decoded[index];
    if (character == QLatin1Char('"')) {
      quoted = !quoted;
      started = true;
      continue;
    }
    if (character == QLatin1Char('\\')) {
      if (!quoted || ++index == decoded.size())
        return std::nullopt;
      character = decoded[index];
      if (character != QLatin1Char('"') && character != QLatin1Char('\\') &&
          character != QLatin1Char('$') && character != QLatin1Char('`'))
        return std::nullopt;
    } else if (quoted && (character == QLatin1Char('$') || character == QLatin1Char('`'))) {
      return std::nullopt;
    } else if (character == QLatin1Char('%')) {
      if (++index == decoded.size() || decoded[index] != QLatin1Char('%'))
        return std::nullopt;
    } else if (!quoted && character.isSpace()) {
      if (started) {
        arguments.append(argument);
        argument.clear();
        started = false;
      }
      continue;
    }
    argument += character;
    started = true;
  }
  if (quoted)
    return std::nullopt;
  if (started)
    arguments.append(argument);
  return arguments;
}
class DesktopTests : public QObject {
  Q_OBJECT
private slots:
  void batchPrivacyPreferences() {
    QTemporaryDir dir;
    QSettings settings(dir.filePath("settings.ini"), QSettings::IniFormat);
    FakeMonitor monitor;
    FakeNotifications alerts;
    FakeAutostart startup;
    AppModel model(&monitor, &alerts, &startup, &settings);
    QVERIFY(!model.preference("notifications"));
    QVERIFY(model.preference("pinLatest"));
    monitor.attach(device());
    model.flushNotifications();
    QVERIFY(alerts.groups.isEmpty());
    model.setPreference("notifications", true);
    monitor.attach(device("2"));
    monitor.attach(device("2"));
    monitor.attach(device("3"));
    monitor.attach(device("hub", true));
    model.flushNotifications();
    QCOMPARE(alerts.groups.size(), 1);
    QCOMPARE(alerts.groups.first().size(), 2);
    QVERIFY(model.history().first().device.serialNumber.isEmpty());
    QVERIFY(!copyText(device()).contains("sensitive serial"));
    QCOMPARE(model.devices().size(), 4);
    model.setPreference("showHubs", true);
    QCOMPARE(model.devices().size(), 5);
    QCOMPARE(model.history().size(), 5);
    monitor.attach(device("cancel"));
    monitor.detach(device("cancel"));
    model.flushNotifications();
    QCOMPARE(alerts.groups.size(), 1);
    QVERIFY(alerts.cancelled.contains("cancel"));
    monitor.attach(device("disable"));
    model.setPreference("notifications", false);
    model.flushNotifications();
    QCOMPARE(alerts.groups.size(), 1);
    QCOMPARE(alerts.cancellations, 1);
    settings.sync();
    QSettings reloaded(dir.filePath("settings.ini"), QSettings::IniFormat);
    QVERIFY(reloaded.value("showHubs").toBool());
  }
  void fixedWindowHistoryResume() {
    QTemporaryDir dir;
    QSettings settings(dir.filePath("settings.ini"), QSettings::IniFormat);
    FakeMonitor monitor;
    FakeNotifications alerts;
    FakeAutostart startup;
    AppModel model(&monitor, &alerts, &startup, &settings);
    model.setPreference("notifications", true);
    monitor.attach(device("one"));
    QTest::qWait(600);
    monitor.attach(device("two"));
    QTRY_COMPARE_WITH_TIMEOUT(alerts.groups.size(), 1, 600);
    QCOMPARE(alerts.groups.first().size(), 2);
    for (int i = 0; i < 60; ++i)
      monitor.attach(device(QString::number(i)));
    QCOMPARE(model.history().size(), 50);
    for (const auto &observation : model.history())
      QVERIFY(observation.device.serialNumber.isEmpty());
    model.prepareForSleep(true);
    QCOMPARE(monitor.wakes, 0);
    model.prepareForSleep(false);
    QCOMPARE(monitor.wakes, 1);
    model.refresh();
    QCOMPARE(monitor.refreshes, 1);
    model.clearHistory();
    QVERIFY(model.history().isEmpty());
  }
  void desktopStatesClipboardSettings() {
    QTemporaryDir dir;
    QSettings settings(dir.filePath("settings.ini"), QSettings::IniFormat);
    FakeMonitor monitor;
    FakeNotifications alerts;
    FakeAutostart startup;
    AppModel model(&monitor, &alerts, &startup, &settings);
    MainWindow window(&model, false);
    window.showWindow();
    QVERIFY(!window.usableTray());
    auto text = [&window](QString match) {
      for (auto *label : window.findChildren<QLabel *>())
        if (label->text().contains(match))
          return true;
      return false;
    };
    QVERIFY(text("No USB devices detected"));
    monitor.attach(device());
    QVERIFY(text("480 Mbps"));
    QVERIFY(text("USB keyboard"));
    QVERIFY(text("Example"));
    QVERIFY(text(technicalLabel(Speed::High)));
    if (qEnvironmentVariableIsSet("USB_BOOP_TEST_SCREENSHOT")) {
      window.resize(600, 800);
      QApplication::processEvents();
      QVERIFY(window.grab().save(qEnvironmentVariable("USB_BOOP_TEST_SCREENSHOT")));
    }
    bool copied = false;
    for (auto *button : window.findChildren<QPushButton *>())
      if (button->accessibleName() == "Copy info for USB keyboard") {
        button->click();
        copied = true;
        break;
      }
    QVERIFY(copied);
    QVERIFY(QApplication::clipboard()->text().contains("USB keyboard"));
    QVERIFY(!QApplication::clipboard()->text().contains("serial"));
    monitor.detach(device());
    QVERIFY(text("Disconnected"));
    monitor.current = {State::Degraded, Issue::IncompleteResults};
    emit monitor.statusChanged(monitor.current);
    QVERIFY(text("cached result"));
    window.showSettings();
    auto *sound = window.findChild<QCheckBox *>(QString());
    Q_UNUSED(sound);
    bool foundStartup = false;
    for (auto *check : window.findChildren<QCheckBox *>()) {
      QVERIFY(!check->accessibleName().isEmpty() || check->text() == "Launch at login");
      if (check->text() == "Launch at login") {
        check->setChecked(true);
        foundStartup = true;
      }
      if (check->text() == "Play a sound")
        QVERIFY(!check->isEnabled());
    }
    QVERIFY(foundStartup);
    QVERIFY(startup.enabled());
    window.close();
    QVERIFY(!window.isVisible());
  }
  void latestMetadataRecoveryAndDisconnectedCache() {
    QTemporaryDir dir;
    QSettings settings(dir.filePath("settings.ini"), QSettings::IniFormat);
    FakeMonitor monitor;
    FakeNotifications alerts;
    FakeAutostart startup;
    AppModel model(&monitor, &alerts, &startup, &settings);
    Device partial = device("recover");
    partial.name = "USB Device";
    partial.speed = Speed::Unknown;
    monitor.attach(partial);
    QVERIFY(model.latest());
    QCOMPARE(model.latest()->speed, Speed::Unknown);
    Device recovered = partial;
    recovered.name = "Recovered SSD";
    recovered.speed = Speed::Gen2;
    recovered.manufacturer = "Recovered manufacturer";
    monitor.value.devices = {recovered};
    emit monitor.devicesChanged(monitor.value.devices);
    QCOMPARE(model.latest()->speed, Speed::Gen2);
    QCOMPARE(model.latest()->name, QString("Recovered SSD"));
    QCOMPARE(model.latest()->connectedAt, partial.connectedAt);
    monitor.detach(recovered);
    QVERIFY(model.latest());
    QCOMPARE(model.latest()->name, QString("Recovered SSD"));
    QCOMPARE(model.latestStatus(), QString("Disconnected"));
  }
  void hiddenHubEmptyAndSorting() {
    QTemporaryDir dir;
    QSettings settings(dir.filePath("settings.ini"), QSettings::IniFormat);
    FakeMonitor monitor;
    FakeNotifications alerts;
    FakeAutostart startup;
    AppModel model(&monitor, &alerts, &startup, &settings);
    monitor.attach(device("hub", true));
    QVERIFY(model.devices().isEmpty());
    QCOMPARE(model.emptyDevicesMessage(), QString("USB hubs are hidden."));
    Device old = device("old");
    old.name = "A device";
    old.firstSeenAt = QDateTime::fromSecsSinceEpoch(1);
    monitor.attach(old);
    Device recent = device("new");
    recent.name = "Z device";
    monitor.attach(recent);
    QCOMPARE(model.devices().first().id, QString("new"));
  }
  void singleInstanceActivation() {
    QTemporaryDir dir;
    const QByteArray previous = qgetenv("XDG_RUNTIME_DIR");
    qputenv("XDG_RUNTIME_DIR", dir.path().toUtf8());
    SingleInstance first;
    QCOMPARE(first.acquire(), SingleInstance::Result::Primary);
    QSignalSpy activation(&first, &SingleInstance::activationRequested);
    SingleInstance second;
    QCOMPARE(second.acquire(), SingleInstance::Result::ActivatedExisting);
    QTRY_COMPARE(activation.size(), 1);
    qputenv("XDG_RUNTIME_DIR", previous);
  }
  void unavailableServicesAndDegradedCancel() {
    QTemporaryDir dir;
    QSettings settings(dir.filePath("settings.ini"), QSettings::IniFormat);
    FakeMonitor monitor;
    FakeNotifications alerts;
    FakeAutostart startup;
    AppModel model(&monitor, &alerts, &startup, &settings);
    model.setPreference("notifications", true);
    alerts.ready = false;
    monitor.attach(device("unavailable"));
    alerts.ready = true;
    model.flushNotifications();
    QVERIFY(alerts.groups.isEmpty());
    monitor.attach(device("pending"));
    monitor.current = {State::Degraded, Issue::IncompleteResults};
    emit monitor.statusChanged(monitor.current);
    model.flushNotifications();
    QVERIFY(alerts.groups.isEmpty());
    QCOMPARE(alerts.cancellations, 1);
    monitor.attach(device("degraded"));
    monitor.current = {State::Monitoring, Issue::None};
    emit monitor.statusChanged(monitor.current);
    model.flushNotifications();
    QVERIFY(alerts.groups.isEmpty());
  }
  void autostartQuotedPathRoundtrip() {
    QTemporaryDir dir;
    const QString executable = dir.filePath(QStringLiteral("app space \\ $ \" ` % end"));
    QFile file(executable);
    QVERIFY(file.open(QIODevice::WriteOnly));
    file.write("#!/bin/sh\n");
    file.close();
    QVERIFY(file.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner |
                                QFileDevice::ExeOwner));
    XdgAutostart startup(executable, dir.path());
    QVERIFY(startup.setEnabled(true));
    QFile entry(dir.filePath("autostart/usb-boop.desktop"));
    QVERIFY(entry.open(QIODevice::ReadOnly));
    const auto arguments = desktopArguments(entry.readAll());
    QVERIFY(arguments);
    QCOMPARE(*arguments, QStringList({executable, "--background"}));
    const QString unsupported = dir.filePath("app=bad");
    QVERIFY(QFile::copy(executable, unsupported));
    XdgAutostart bad(unsupported, dir.path());
    QVERIFY(!bad.setEnabled(true));
  }
  void autostartRoundtrip() {
    QTemporaryDir dir;
    const QString executable = dir.filePath("app path");
    QFile file(executable);
    QVERIFY(file.open(QIODevice::WriteOnly));
    file.write("#!/bin/sh\n");
    file.close();
    QVERIFY(file.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner |
                                QFileDevice::ExeOwner));
    XdgAutostart startup(executable, dir.path());
    QVERIFY(!startup.enabled());
    QVERIFY(startup.setEnabled(true));
    QVERIFY(startup.enabled());
    QFile entry(dir.filePath("autostart/usb-boop.desktop"));
    QVERIFY(entry.open(QIODevice::ReadOnly));
    QVERIFY(entry.readAll().contains(" --background"));
    QVERIFY(startup.setEnabled(false));
    QVERIFY(!startup.enabled());
    XdgAutostart bad(dir.filePath("missing"), dir.path());
    QVERIFY(!bad.setEnabled(true));
    QVERIFY(!bad.error().isEmpty());
  }
};
QTEST_MAIN(DesktopTests)
#include "desktop_test.moc"
