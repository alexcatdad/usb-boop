#include "app.h"
#include <QDBusConnection>
#include <algorithm>
namespace boop {
AppModel::AppModel(Monitor *monitor, NotificationService *notifications,
                   AutostartService *autostart, QSettings *settings, QObject *parent)
    : QObject(parent), monitor_(monitor), notifications_(notifications), autostart_(autostart),
      settings_(settings), devices_(monitor->snapshot().devices) {
  batch_.setSingleShot(true);
  batch_.setInterval(1000);
  connect(&batch_, &QTimer::timeout, this, &AppModel::flushNotifications);
  connect(monitor_, &Monitor::devicesChanged, this, [this](const QList<Device> &devices) {
    devices_ = devices;
    QSet<QString> current;
    for (const auto &device : devices_)
      current.insert(device.id);
    announced_.intersect(current);
    emit changed();
  });
  connect(monitor_, &Monitor::statusChanged, this, [this] {
    if (!status().reliable()) {
      batch_.stop();
      pending_.clear();
      notifications_->cancelAll();
    }
    emit changed();
  });
  connect(notifications_, &NotificationService::changed, this, [this] {
    if (!notifications_->available()) {
      batch_.stop();
      pending_.clear();
      notifications_->cancelAll();
    }
    emit changed();
  });
  connect(monitor_, &Monitor::attached, this, [this](const Device &device) {
    if (!device.isHub)
      latest_ = device;
    if (preference("notifications") && status().reliable() && notifications_->available() &&
        !device.isHub && !announced_.contains(device.id)) {
      bool duplicate = false;
      for (const auto &pending : pending_)
        if (pending.id == device.id)
          duplicate = true;
      if (!duplicate) {
        pending_.append(device);
        announced_.insert(device.id);
      }
      if (!batch_.isActive())
        batch_.start();
    }
    emit changed();
  });
  connect(monitor_, &Monitor::detached, this, [this](const Device &device) {
    announced_.remove(device.id);
    pending_.removeIf([&](const Device &pending) { return pending.id == device.id; });
    notifications_->cancel(device.id);
    emit changed();
  });
  connect(monitor_, &Monitor::observation, this, [this](Observation observation) {
    observation.device.serialNumber.clear();
    history_.prepend(observation);
    while (history_.size() > 50)
      history_.removeLast();
    emit changed();
  });
  QDBusConnection::systemBus().connect("org.freedesktop.login1", "/org/freedesktop/login1",
                                       "org.freedesktop.login1.Manager", "PrepareForSleep", this,
                                       SLOT(prepareForSleep(bool)));
}
bool AppModel::preference(const QString &key) const {
  return settings_->value(key, key == "pinLatest").toBool();
}
void AppModel::setPreference(const QString &key, bool value) {
  settings_->setValue(key, value);
  if (key == "notifications" && !value) {
    batch_.stop();
    pending_.clear();
    notifications_->cancelAll();
  }
  emit changed();
}
QList<Device> AppModel::devices() const {
  auto result = devices_;
  if (!preference("showHubs"))
    result.removeIf([](const Device &device) { return device.isHub; });
  std::sort(result.begin(), result.end(), [](const Device &left, const Device &right) {
    if (left.firstSeenAt == right.firstSeenAt)
      return QString::compare(left.name, right.name, Qt::CaseInsensitive) < 0;
    return left.firstSeenAt > right.firstSeenAt;
  });
  return result;
}
QList<Observation> AppModel::history() const {
  auto result = history_;
  if (!preference("showHubs"))
    result.removeIf([](const Observation &observation) { return observation.device.isHub; });
  return result;
}
QString AppModel::emptyDevicesMessage() const {
  if (!status().reliable())
    return "USB device information is unavailable or incomplete.";
  return devices_.isEmpty() ? "No USB devices detected." : "USB hubs are hidden.";
}
QString AppModel::latestStatus() const {
  if (!latest_)
    return {};
  for (const auto &device : devices_)
    if (device.id == latest_->id)
      return status().reliable() ? "Connected" : "Connection status uncertain — cached result";
  return status().reliable() ? "Disconnected" : "No longer detected — cached result";
}
void AppModel::prepareForSleep(bool sleeping) {
  if (!sleeping)
    monitor_->reconcileAfterWake();
}
void AppModel::refresh() { monitor_->refresh(); }
void AppModel::clearHistory() {
  history_.clear();
  emit changed();
}
void AppModel::flushNotifications() {
  batch_.stop();
  const auto devices = pending_;
  pending_.clear();
  if (preference("notifications") && status().reliable() && notifications_->available() &&
      !devices.isEmpty())
    notifications_->deliver(devices, preference("sound"));
}
QString linkSpeedSummary(const Device &device) {
  return device.speed == Speed::Unknown || device.speed == Speed::Other
             ? speedLabel(device.speed)
             : "Link speed: " + speedLabel(device.speed);
}
QString copyText(const Device &device) {
  QStringList lines{device.name, linkSpeedSummary(device)};
  if (!technicalLabel(device.speed).isEmpty())
    lines << technicalLabel(device.speed);
  if (!device.manufacturer.isEmpty())
    lines << "Manufacturer: " + device.manufacturer;
  if (device.vendorId && device.productId)
    lines << QString("VID %1 / PID %2")
                 .arg(*device.vendorId, 4, 16, QChar('0'))
                 .arg(*device.productId, 4, 16, QChar('0'));
  return lines.join('\n');
}
} // namespace boop
