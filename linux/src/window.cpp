#include "window.h"
#include <QApplication>
#include <QCheckBox>
#include <QClipboard>
#include <QCloseEvent>
#include <QDBusConnection>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusServiceWatcher>
#include <QDialog>
#include <QDialogButtonBox>
#include <QGroupBox>
#include <QLabel>
#include <QMenu>
#include <QPainter>
#include <QPushButton>
#include <QScrollArea>
#include <QShortcut>
#include <QSignalBlocker>
#include <QVBoxLayout>
namespace boop {
namespace {
QString observationLabel(ObservationKind kind) {
  switch (kind) {
  case ObservationKind::Attached:
    return "Connected";
  case ObservationKind::Detached:
    return "Disconnected";
  case ObservationKind::FirstSeen:
    return "First seen";
  case ObservationKind::NoLongerDetected:
    return "No longer detected";
  }
  return {};
}
QWidget *row(const Device &device, QWidget *parent) {
  auto *widget = new QWidget(parent);
  widget->setAccessibleName(device.name + ", " + linkSpeedSummary(device));
  widget->setToolTip("<qt>" + copyText(device).toHtmlEscaped().replace('\n', "<br>") + "</qt>");
  widget->setContextMenuPolicy(Qt::CustomContextMenu);
  QObject::connect(
      widget, &QWidget::customContextMenuRequested, widget, [widget, device](const QPoint &point) {
        QMenu menu(widget);
        menu.addAction("Copy device info", widget,
                       [device] { QApplication::clipboard()->setText(copyText(device)); });
        menu.exec(widget->mapToGlobal(point));
      });
  auto *layout = new QVBoxLayout(widget);
  auto *heading = new QHBoxLayout;
  auto *name = new QLabel(device.name, widget);
  name->setTextFormat(Qt::PlainText);
  name->setWordWrap(true);
  name->setTextInteractionFlags(Qt::TextSelectableByMouse);
  heading->addWidget(name, 1);
  auto *copy = new QPushButton("Copy", widget);
  copy->setAccessibleName("Copy info for " + device.name);
  QObject::connect(copy, &QPushButton::clicked, widget,
                   [device] { QApplication::clipboard()->setText(copyText(device)); });
  heading->addWidget(copy);
  layout->addLayout(heading);
  auto *speed = new QLabel(linkSpeedSummary(device), widget);
  speed->setTextFormat(Qt::PlainText);
  QFont font = speed->font();
  font.setBold(true);
  speed->setFont(font);
  const QString color = device.speed == Speed::Gen2 || device.speed == Speed::Gen2x2 ? "#16823b"
                        : device.speed == Speed::Gen1                                ? "#1874c5"
                        : device.speed == Speed::High                                ? "#b06509"
                                                                                     : "";
  if (!color.isEmpty())
    speed->setStyleSheet("color: " + color);
  layout->addWidget(speed);
  QStringList details;
  if (!technicalLabel(device.speed).isEmpty())
    details << technicalLabel(device.speed);
  if (!device.manufacturer.isEmpty())
    details << device.manufacturer;
  if (!details.isEmpty()) {
    auto *description = new QLabel(details.join(" · "), widget);
    description->setTextFormat(Qt::PlainText);
    description->setWordWrap(true);
    layout->addWidget(description);
  }
  const bool attached = device.connectedAt.isValid();
  auto *time = new QLabel((device.isHub ? "Hub · " : "") +
                              QString(attached ? "Connected at " : "Seen since ") +
                              (attached ? device.connectedAt : device.firstSeenAt)
                                  .toLocalTime()
                                  .toString("yyyy-MM-dd HH:mm"),
                          widget);
  layout->addWidget(time);
  return widget;
}
void clear(QLayout *layout) {
  while (auto *item = layout->takeAt(0)) {
    if (item->widget())
      delete item->widget();
    if (item->layout())
      clear(item->layout());
    delete item;
  }
}
} // namespace
MainWindow::MainWindow(AppModel *model, bool trayEnabled, QWidget *parent)
    : QMainWindow(parent), model_(model),
      tray_(new QSystemTrayIcon(QIcon(":/icons/tray.png"), this)) {
  setWindowTitle("usb-boop");
  setWindowIcon(QIcon(":/icons/app.png"));
  resize(470, 650);
  setAccessibleName("USB connection speeds");
  auto *central = new QWidget(this);
  auto *layout = new QVBoxLayout(central);
  status_ = new QLabel(central);
  status_->setWordWrap(true);
  status_->setTextFormat(Qt::PlainText);
  status_->setAccessibleName("Monitoring status");
  layout->addWidget(status_);
  auto *scroll = new QScrollArea(central);
  scroll->setWidgetResizable(true);
  auto *content = new QWidget(scroll);
  content_ = new QVBoxLayout(content);
  scroll->setWidget(content);
  layout->addWidget(scroll, 1);
  auto *controls = new QHBoxLayout;
  auto *refresh = new QPushButton("Refresh", central);
  refresh->setAccessibleName("Refresh device list");
  connect(refresh, &QPushButton::clicked, model_, &AppModel::refresh);
  controls->addWidget(refresh);
  auto *settings = new QPushButton("Settings…", central);
  connect(settings, &QPushButton::clicked, this, &MainWindow::showSettings);
  controls->addWidget(settings);
  controls->addStretch();
  auto *quit = new QPushButton("Quit", central);
  connect(quit, &QPushButton::clicked, qApp, &QApplication::quit);
  controls->addWidget(quit);
  layout->addLayout(controls);
  setCentralWidget(central);
  auto *menu = new QMenu(this);
  menu->addAction("Show usb-boop", this, &MainWindow::showWindow);
  menu->addAction("Settings…", this, &MainWindow::showSettings);
  menu->addSeparator();
  menu->addAction("Quit", qApp, &QApplication::quit);
  tray_->setContextMenu(menu);
  tray_->setToolTip("usb-boop — USB connection speeds");
  auto bus = QDBusConnection::sessionBus();
  bus.connect("org.freedesktop.portal.Desktop", "/org/freedesktop/portal/desktop",
              "org.freedesktop.portal.Settings", "SettingChanged", this,
              SLOT(appearanceChanged(QString, QString, QDBusVariant)));
  auto *appearanceWatch = new QDBusServiceWatcher("org.freedesktop.portal.Desktop", bus,
                                                  QDBusServiceWatcher::WatchForOwnerChange, this);
  connect(appearanceWatch, &QDBusServiceWatcher::serviceOwnerChanged, this,
          [this](const QString &, const QString &, const QString &owner) {
            ++appearanceRevision_;
            appearancePreference_ = 0;
            updateTrayIcon();
            if (!owner.isEmpty())
              readAppearance();
          });
  updateTrayIcon();
  readAppearance();
  if (trayEnabled && QSystemTrayIcon::isSystemTrayAvailable())
    tray_->show();
  connect(tray_, &QSystemTrayIcon::activated, this,
          [this](QSystemTrayIcon::ActivationReason reason) {
            if (reason == QSystemTrayIcon::Trigger || reason == QSystemTrayIcon::DoubleClick)
              showWindow();
          });
  connect(model_, &AppModel::changed, this, &MainWindow::render);
  auto *trayWatch = new QTimer(this);
  trayWatch->setInterval(2000);
  connect(trayWatch, &QTimer::timeout, this, [this, trayEnabled] {
    if (trayEnabled && QSystemTrayIcon::isSystemTrayAvailable()) {
      if (!tray_->isVisible())
        tray_->show();
    } else if (!isVisible())
      showWindow();
  });
  trayWatch->start();
  auto *refreshShortcut = new QShortcut(QKeySequence("Ctrl+R"), this);
  connect(refreshShortcut, &QShortcut::activated, model_, &AppModel::refresh);
  auto *settingsShortcut = new QShortcut(QKeySequence("Ctrl+,"), this);
  connect(settingsShortcut, &QShortcut::activated, this, &MainWindow::showSettings);
  auto *quitShortcut = new QShortcut(QKeySequence("Ctrl+Q"), this);
  connect(quitShortcut, &QShortcut::activated, qApp, &QApplication::quit);
  render();
}
bool MainWindow::usableTray() const {
  return tray_->isVisible() && QSystemTrayIcon::isSystemTrayAvailable();
}
void MainWindow::readAppearance() {
  auto message = QDBusMessage::createMethodCall("org.freedesktop.portal.Desktop",
                                                "/org/freedesktop/portal/desktop",
                                                "org.freedesktop.portal.Settings", "Read");
  message << QString("org.freedesktop.appearance") << QString("color-scheme");
  const auto revision = appearanceRevision_;
  auto *watcher =
      new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(message, 1000), this);
  connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, revision, watcher] {
    QDBusPendingReply<QDBusVariant> reply = *watcher;
    watcher->deleteLater();
    if (!reply.isError() && revision == appearanceRevision_)
      appearanceChanged("org.freedesktop.appearance", "color-scheme", reply.value());
  });
}
void MainWindow::appearanceChanged(const QString &group, const QString &key,
                                   const QDBusVariant &value) {
  if (group != "org.freedesktop.appearance" || key != "color-scheme")
    return;
  QVariant preference = value.variant();
  // Older Settings.Read replies wrap the setting in an additional variant.
  if (preference.metaType() == QMetaType::fromType<QDBusVariant>())
    preference = qvariant_cast<QDBusVariant>(preference).variant();
  bool valid = false;
  const auto scheme = preference.toUInt(&valid);
  if (!valid)
    return;
  ++appearanceRevision_;
  appearancePreference_ = scheme <= 2 ? scheme : 0;
  updateTrayIcon();
}
void MainWindow::updateTrayIcon() {
  const bool dark =
      appearancePreference_ == 1 ||
      (appearancePreference_ == 0 && palette().color(QPalette::Window).lightness() < 128);
  QPixmap icon(":/icons/tray.png");
  if (icon.isNull())
    return;
  QPainter painter(&icon);
  painter.setCompositionMode(QPainter::CompositionMode_SourceIn);
  painter.fillRect(icon.rect(), dark ? Qt::white : Qt::black);
  painter.end();
  tray_->setIcon(QIcon(icon));
}
void MainWindow::changeEvent(QEvent *event) {
  QMainWindow::changeEvent(event);
  if (event->type() == QEvent::PaletteChange || event->type() == QEvent::ApplicationPaletteChange)
    updateTrayIcon();
}
void MainWindow::closeEvent(QCloseEvent *event) {
  if (usableTray()) {
    hide();
    event->ignore();
  } else
    QMainWindow::closeEvent(event);
}
void MainWindow::showWindow() {
  show();
  raise();
  activateWindow();
}
void MainWindow::render() {
  status_->setText(statusMessage(model_->status()));
  clear(content_);
  if (model_->preference("pinLatest")) {
    auto *group = new QGroupBox("Latest connection", this);
    auto *layout = new QVBoxLayout(group);
    if (auto latest = model_->latest()) {
      layout->addWidget(row(*latest, group));
      layout->addWidget(new QLabel(model_->latestStatus(), group));
    } else
      layout->addWidget(new QLabel("Plug in a USB device to see its link speed.", group));
    content_->addWidget(group);
  }
  auto *devices = new QGroupBox("Connected devices", this);
  auto *layout = new QVBoxLayout(devices);
  const auto visible = model_->devices();
  if (visible.isEmpty())
    layout->addWidget(new QLabel(model_->emptyDevicesMessage(), devices));
  for (const auto &device : visible)
    layout->addWidget(row(device, devices));
  auto *note = new QLabel(
      "Link speed is the negotiated connection rate, not measured file-transfer speed.", devices);
  note->setWordWrap(true);
  layout->addWidget(note);
  content_->addWidget(devices);
  auto *history = new QGroupBox("Recent activity — this session, last 50 observations", this);
  auto *historyLayout = new QVBoxLayout(history);
  auto *clearButton = new QPushButton("Clear history", history);
  clearButton->setEnabled(!model_->history().isEmpty());
  connect(clearButton, &QPushButton::clicked, model_, &AppModel::clearHistory);
  historyLayout->addWidget(clearButton);
  if (model_->history().isEmpty())
    historyLayout->addWidget(new QLabel("No recent activity.", history));
  for (const auto &observation : model_->history()) {
    auto *label = new QLabel(observation.device.name + "\n" + observationLabel(observation.kind) +
                                 " · " + speedLabel(observation.device.speed) + " · " +
                                 observation.observedAt.toLocalTime().toString("HH:mm:ss"),
                             history);
    label->setTextFormat(Qt::PlainText);
    label->setWordWrap(true);
    historyLayout->addWidget(label);
  }
  content_->addWidget(history);
  content_->addStretch();
}
void MainWindow::showSettings() {
  if (settings_) {
    settings_->show();
    settings_->raise();
    return;
  }
  settings_ = new QDialog(this);
  settings_->setWindowTitle("usb-boop Settings");
  settings_->setAttribute(Qt::WA_DeleteOnClose);
  connect(settings_, &QObject::destroyed, this, [this] { settings_ = nullptr; });
  auto *layout = new QVBoxLayout(settings_);
  auto addPreference = [this, layout](const QString &text, const QString &key) {
    auto *checkbox = new QCheckBox(text, settings_);
    checkbox->setAccessibleName(text);
    checkbox->setChecked(model_->preference(key));
    connect(checkbox, &QCheckBox::toggled, model_,
            [this, key](bool value) { model_->setPreference(key, value); });
    layout->addWidget(checkbox);
    return checkbox;
  };
  auto *notifications = addPreference("Show quiet connection banners", "notifications");
  auto *summary = new QLabel(model_->notifications()->summary(), settings_);
  summary->setWordWrap(true);
  summary->setTextFormat(Qt::PlainText);
  layout->addWidget(summary);
  auto *sound = addPreference("Play a sound", "sound");
  auto update = [this, summary, sound] {
    summary->setText(model_->notifications()->summary());
    sound->setEnabled(model_->preference("notifications") &&
                      model_->notifications()->supportsSound());
  };
  connect(model_, &AppModel::changed, settings_, update);
  connect(notifications, &QCheckBox::toggled, settings_, update);
  update();
  layout->addWidget(new QLabel(
      "Hub connections are silent. Devices connected together share one banner.", settings_));
  auto *startup = new QCheckBox("Launch at login", settings_);
  startup->setAccessibleName("Launch at login");
  startup->setChecked(model_->autostart()->enabled());
  layout->addWidget(startup);
  auto *error = new QLabel(settings_);
  error->setWordWrap(true);
  error->setTextFormat(Qt::PlainText);
  layout->addWidget(error);
  connect(startup, &QCheckBox::toggled, settings_, [this, startup, error](bool enabled) {
    if (!model_->autostart()->setEnabled(enabled)) {
      QSignalBlocker blocker(startup);
      startup->setAccessibleName("Launch at login");
      startup->setChecked(model_->autostart()->enabled());
    }
    error->setText(model_->autostart()->error());
  });
  addPreference("Pin latest result", "pinLatest");
  addPreference("Show USB hubs", "showHubs");
  auto *privacy = new QLabel("History is cleared when usb-boop quits. usb-boop reads USB metadata "
                             "only; it never opens device files or reads or writes your media.",
                             settings_);
  privacy->setWordWrap(true);
  layout->addWidget(privacy);
  layout->addWidget(new QLabel("Version " + QCoreApplication::applicationVersion(), settings_));
  auto *source = new QLabel(
      R"(<a href="https://github.com/alexcatdad/usb-boop">View on GitHub</a>)", settings_);
  source->setOpenExternalLinks(true);
  layout->addWidget(source);
  auto *buttons = new QDialogButtonBox(QDialogButtonBox::Close, settings_);
  connect(buttons, &QDialogButtonBox::rejected, settings_, &QDialog::close);
  layout->addWidget(buttons);
  settings_->resize(480, 400);
  settings_->show();
}
} // namespace boop
