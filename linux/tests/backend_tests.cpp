#include "reconciliation.h"
#include <QDir>
#include <QFile>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QtTest>
#include <unistd.h>

using namespace boop;
namespace {
Device makeDevice(QString id = QStringLiteral("1-1@1:2")) {
  Device device;
  device.id = id;
  device.topology = QStringLiteral("1-1");
  device.name = QStringLiteral("Test drive");
  device.serialNumber = QStringLiteral("private-serial");
  device.speed = Speed::Gen1;
  return device;
}
void writeAttribute(const QString &directory, const QString &name, const QByteArray &value) {
  QFile file(directory + QLatin1Char('/') + name);
  QVERIFY(file.open(QIODevice::WriteOnly));
  QCOMPARE(file.write(value), value.size());
}
} // namespace
class BackendTests : public QObject {
  Q_OBJECT
private slots:
  void speeds() {
    QCOMPARE(parseSpeed(QStringLiteral("1.5")), Speed::Low);
    QCOMPARE(parseSpeed(QStringLiteral("12")), Speed::Full);
    QCOMPARE(parseSpeed(QStringLiteral("480")), Speed::High);
    QCOMPARE(parseSpeed(QStringLiteral("5000")), Speed::Gen1);
    QCOMPARE(parseSpeed(QStringLiteral("10000")), Speed::Gen2);
    QCOMPARE(parseSpeed(QStringLiteral("20000")), Speed::Gen2x2);
    QCOMPARE(parseSpeed(QStringLiteral("40000")), Speed::Other);
    for (const auto &value :
         {QString(), QStringLiteral("NaN"), QStringLiteral("-1"), QStringLiteral("oops")})
      QCOMPARE(parseSpeed(value), Speed::Unknown);
    QCOMPARE(speedLabel(Speed::Gen2), QStringLiteral("10 Gbps"));
  }
  void sanitization() {
    QCOMPARE(sanitize(QString::fromUtf8(" \x01Hello\xe2\x80\xae ")), QStringLiteral("Hello"));
    QCOMPARE(sanitize(QString(200, QLatin1Char('x'))).size(), 128);
  }
  void sysfsMetadata() {
    QTemporaryDir temporary;
    QVERIFY(temporary.isValid());
    auto root = temporary.path();
    auto device = root + QStringLiteral("/1-1");
    QVERIFY(QDir().mkpath(device));
    QVERIFY(QDir().mkpath(root + QStringLiteral("/1-1:1.0")));
    writeAttribute(device, QStringLiteral("busnum"), "1\n");
    writeAttribute(device, QStringLiteral("devnum"), "2\n");
    writeAttribute(device, QStringLiteral("idVendor"), "05ac\n");
    writeAttribute(device, QStringLiteral("idProduct"), "1234\n");
    writeAttribute(device, QStringLiteral("speed"), "10000\n");
    writeAttribute(device, QStringLiteral("bDeviceClass"), "09\n");
    writeAttribute(device, QStringLiteral("serial"), "private\n");
    auto result = readSysfs(root);
    QCOMPARE(result.issue, Issue::None);
    QCOMPARE(result.devices.size(), 1);
    QCOMPARE(result.devices.first().name, QStringLiteral("USB Device 05AC:1234"));
    QCOMPARE(result.devices.first().speed, Speed::Gen2);
    QVERIFY(result.devices.first().isHub);
    QCOMPARE(result.devices.first().serialNumber, QStringLiteral("private"));
    writeAttribute(device, QStringLiteral("manufacturer"), "Maker\n");
    QCOMPARE(readSysfs(root).devices.first().name, QStringLiteral("Maker USB Device"));
    QVERIFY(QFile::remove(device + QStringLiteral("/speed")));
    QCOMPARE(readSysfs(root).issue, Issue::IncompleteResults);
    QVERIFY(QFile::remove(device + QStringLiteral("/devnum")));
    QCOMPARE(readSysfs(root).devices.size(), 0);
    QVERIFY(readSysfs(root + QStringLiteral("/absent")).failed);
  }
  void directorySearchPermission() {
    if (geteuid() == 0)
      QSKIP(
          "Root bypasses directory DAC permissions; deterministic access-denial tests still run.");
    QTemporaryDir temporary;
    QVERIFY(temporary.isValid());
    const auto original = QFile::permissions(temporary.path());
    QVERIFY(QFile::setPermissions(temporary.path(), QFile::ReadOwner | QFile::WriteOwner));
    const auto result = readSysfs(temporary.path());
    QVERIFY(QFile::setPermissions(temporary.path(), original));
    QVERIFY(result.failed);
    QCOMPARE(result.issue, Issue::AccessRestricted);
  }
  void startupAndDuplicateEvents() {
    Snapshot source{{makeDevice()}};
    ReconciliationMonitor monitor([&] { return source; });
    QSignalSpy attached(&monitor, &Monitor::attached);
    QSignalSpy observations(&monitor, &Monitor::observation);
    monitor.start();
    QCOMPARE(attached.count(), 0);
    QCOMPARE(observations.count(), 0);
    QVERIFY(monitor.snapshot().devices.first().firstSeenAt.isValid());
    QVERIFY(!monitor.snapshot().devices.first().connectedAt.isValid());
    monitor.deviceEvent(true, QStringLiteral("1-1"));
    QCOMPARE(attached.count(), 0);
    QCOMPARE(observations.count(), 0);
    monitor.stop();
    QCOMPARE(monitor.status().state, State::Stopped);
    monitor.start();
    monitor.deviceEvent(true, QStringLiteral("1-1"));
    QCOMPARE(attached.count(), 0);
  }
  void delayedMetadataAndReconnect() {
    Snapshot source;
    ReconciliationMonitor monitor([&] { return source; });
    QSignalSpy attached(&monitor, &Monitor::attached);
    QSignalSpy observations(&monitor, &Monitor::observation);
    monitor.start();
    monitor.deviceEvent(true, QStringLiteral("1-1"));
    source.devices = {makeDevice()};
    monitor.refresh();
    QCOMPARE(attached.count(), 1);
    QVERIFY(monitor.snapshot().devices.first().connectedAt.isValid());
    auto observation = qvariant_cast<Observation>(observations.first().first());
    QCOMPARE(observation.kind, ObservationKind::Attached);
    QVERIFY(observation.device.serialNumber.isEmpty());
    source.devices.clear();
    monitor.deviceEvent(false, QStringLiteral("1-1"));
    source.devices = {makeDevice(QStringLiteral("1-1@1:3"))};
    monitor.deviceEvent(true, QStringLiteral("1-1"));
    QCOMPARE(attached.count(), 2);
    QCOMPARE(monitor.snapshot().devices.first().id, QStringLiteral("1-1@1:3"));
    monitor.refresh();
    QCOMPARE(attached.count(), 2);
  }
  void failuresAndResume() {
    Snapshot source{{makeDevice()}};
    ReconciliationMonitor monitor([&] { return source; });
    QSignalSpy attached(&monitor, &Monitor::attached);
    QSignalSpy observations(&monitor, &Monitor::observation);
    monitor.start();
    source = {{}, Issue::IncompleteResults};
    monitor.refresh();
    QCOMPARE(monitor.snapshot().devices.size(), 1);
    QCOMPARE(monitor.status().state, State::Degraded);
    QCOMPARE(observations.count(), 0);
    source = {{}, Issue::EnumerationFailed, true};
    monitor.refresh();
    QCOMPARE(monitor.snapshot().devices.size(), 1);
    QCOMPARE(monitor.status().state, State::Degraded);
    source = {{makeDevice(QStringLiteral("1-1@1:3"))}};
    monitor.reconcileAfterWake();
    QCOMPARE(monitor.status().state, State::Monitoring);
    QCOMPARE(monitor.snapshot().devices.size(), 1);
    QCOMPARE(attached.count(), 0);
    QCOMPARE(observations.count(), 2);
    QVERIFY(qvariant_cast<Observation>(observations.first().first()).device.serialNumber.isEmpty());
  }
  void metadataMergingAndSorting() {
    auto original = makeDevice();
    original.manufacturer = QStringLiteral("Maker");
    original.vendorId = 0x1234;
    original.productId = 0x5678;
    Snapshot source{{original}};
    ReconciliationMonitor monitor([&] { return source; });
    monitor.start();
    const auto time = monitor.snapshot().devices.first().firstSeenAt;
    auto update = makeDevice();
    update.serialNumber.clear();
    update.speed = Speed::Unknown;
    auto newer = makeDevice(QStringLiteral("1-2@1:3"));
    newer.topology = QStringLiteral("1-2");
    source.devices = {update, newer};
    QTest::qWait(2);
    monitor.refresh();
    QCOMPARE(monitor.snapshot().devices.first().id, newer.id);
    const auto existing = monitor.snapshot().devices.last();
    QCOMPARE(existing.manufacturer, original.manufacturer);
    QCOMPARE(existing.vendorId, original.vendorId);
    QCOMPARE(existing.productId, original.productId);
    QCOMPARE(existing.serialNumber, original.serialNumber);
    QCOMPARE(existing.firstSeenAt, time);
    QCOMPARE(existing.speed, Speed::Unknown);
  }
  void queuedEventsAndRegistrationRecovery() {
    Snapshot source{{makeDevice()}};
    class RecoverableMonitor : public ReconciliationMonitor {
    public:
      using ReconciliationMonitor::ReconciliationMonitor;
      using ReconciliationMonitor::setRegistrationAvailable;
    };
    RecoverableMonitor monitor([&] { return source; });
    QSignalSpy attached(&monitor, &Monitor::attached);
    monitor.setRegistrationAvailable(false);
    monitor.start();
    QCOMPARE(monitor.status().issue, Issue::RegistrationFailed);
    monitor.setRegistrationAvailable(true);
    QCOMPARE(monitor.status().state, State::Monitoring);
    source.devices = {makeDevice(QStringLiteral("1-1@1:3"))};
    // By the time an old remove is dispatched, sysfs already contains a new connection.
    monitor.deviceEvent(false, QStringLiteral("1-1"), QStringLiteral("1-1@1:2"));
    QCOMPARE(monitor.snapshot().devices.size(), 1);
    monitor.deviceEvent(true, QStringLiteral("1-1"), QStringLiteral("1-1@1:3"));
    QCOMPARE(attached.count(), 1);
    monitor.deviceEvent(false, QStringLiteral("1-1"), QStringLiteral("1-1@1:2"));
    QCOMPARE(monitor.snapshot().devices.size(), 1);
    QCOMPARE(attached.count(), 1);
  }
  void automaticRetry() {
    Snapshot source{{}, Issue::EnumerationFailed, true};
    ReconciliationMonitor monitor([&] { return source; });
    monitor.start();
    QCOMPARE(monitor.status().state, State::Unavailable);
    source = {{makeDevice()}};
    QTRY_COMPARE_WITH_TIMEOUT(monitor.status().state, State::Monitoring, 3000);
    QCOMPARE(monitor.snapshot().devices.size(), 1);
    monitor.stop();
  }
  void recoveryCallbacksSeeReliableSnapshot() {
    Snapshot source;
    ReconciliationMonitor monitor([&] { return source; });
    monitor.start();
    source = {{}, Issue::IncompleteResults};
    monitor.deviceEvent(true, QStringLiteral("1-1"));
    QCOMPARE(monitor.status().state, State::Degraded);
    bool callback = false;
    connect(&monitor, &Monitor::attached, this, [&](const Device &device) {
      callback = true;
      QVERIFY(monitor.status().reliable());
      QCOMPARE(monitor.snapshot().devices.first().id, device.id);
    });
    source = {{makeDevice()}};
    monitor.refresh();
    QVERIFY(callback);
  }
  void accessDenialRequiresExplicitRetry() {
    Snapshot source{{}, Issue::AccessRestricted, true};
    int reads = 0;
    ReconciliationMonitor monitor([&] {
      ++reads;
      return source;
    });
    monitor.start();
    QCOMPARE(reads, 1);
    QTest::qWait(2200);
    QCOMPARE(reads, 1);
    source = {{makeDevice()}};
    monitor.refresh();
    QCOMPARE(monitor.status().state, State::Monitoring);
  }
  void accessDenialSuspendsAdapterAndResume() {
    Snapshot source{{makeDevice()}};
    int reads = 0;
    class Adapter : public ReconciliationMonitor {
    public:
      using ReconciliationMonitor::ReconciliationMonitor;
      using ReconciliationMonitor::setRegistrationAvailable;
      bool subscribed = true;
      void refresh() override {
        subscribed = true;
        ReconciliationMonitor::refresh();
      }

    protected:
      void onAccessRestricted() override { subscribed = false; }
    };
    Adapter monitor([&] {
      ++reads;
      return source;
    });
    monitor.start();
    source = {{}, Issue::AccessRestricted, true};
    monitor.refresh();
    QCOMPARE(reads, 2);
    QVERIFY(!monitor.subscribed);
    QCOMPARE(monitor.snapshot().devices.size(), 1);
    monitor.deviceEvent(false, QStringLiteral("1-1"));
    monitor.deviceEvent(true, QStringLiteral("1-2"));
    monitor.reconcileAfterWake();
    monitor.setRegistrationAvailable(true);
    QCOMPARE(reads, 2);
    QCOMPARE(monitor.snapshot().devices.size(), 1);
    monitor.refresh();
    QCOMPARE(reads, 3);
    QVERIFY(!monitor.subscribed);
    source = {{makeDevice()}};
    monitor.refresh();
    QVERIFY(monitor.subscribed);
    QCOMPARE(monitor.status().state, State::Monitoring);
  }
  void fixtures() {
    QScopedPointer<Monitor> monitor(makeMonitor(true));
    QSignalSpy attached(monitor.data(), &Monitor::attached);
    monitor->start();
    QCOMPARE(monitor->snapshot().devices.size(), 2);
    QCOMPARE(attached.count(), 0);
    QCOMPARE(monitor->status().state, State::Monitoring);
  }
};
QTEST_GUILESS_MAIN(BackendTests)
#include "backend_tests.moc"
