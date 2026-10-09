#include "reconciliation.h"
#include <QSocketNotifier>
#include <libudev.h>

namespace boop {
namespace {
class UdevMonitor final : public ReconciliationMonitor {
public:
  explicit UdevMonitor(QObject *parent)
      : ReconciliationMonitor([] { return readSysfs(); }, parent) {
    registrationRetry.setInterval(5000);
    connect(&registrationRetry, &QTimer::timeout, this, [this] {
      if (status().issue == Issue::AccessRestricted)
        return;
      if (subscribe()) {
        registrationRetry.stop();
        setRegistrationAvailable(true);
        drain();
      }
    });
  }
  ~UdevMonitor() override { stop(); }
  void start() override {
    if (running)
      return;
    const bool available = subscribe();
    setRegistrationAvailable(available);
    ReconciliationMonitor::start();
    if (!available && status().issue != Issue::AccessRestricted)
      registrationRetry.start();
    else
      drain();
  }
  void refresh() override {
    if (!running) {
      start();
      return;
    }
    const bool available = subscribe();
    setRegistrationAvailable(available, false);
    ReconciliationMonitor::refresh();
    if (!available && status().issue != Issue::AccessRestricted)
      registrationRetry.start();
    else if (available)
      drain();
  }
  void stop() override {
    suspendSubscription();
    ReconciliationMonitor::stop();
  }

protected:
  void onAccessRestricted() override { suspendSubscription(); }

private:
  void suspendSubscription() {
    registrationRetry.stop();
    if (notifier) {
      notifier->setEnabled(false);
      notifier->deleteLater();
      notifier = nullptr;
    }
    if (events)
      udev_monitor_unref(events);
    events = nullptr;
    if (context)
      udev_unref(context);
    context = nullptr;
  }
  bool subscribe() {
    if (events)
      return true;
    context = udev_new();
    if (!context)
      return false;
    events = udev_monitor_new_from_netlink(context, "udev");
    if (!events ||
        udev_monitor_filter_add_match_subsystem_devtype(events, "usb", "usb_device") < 0 ||
        udev_monitor_enable_receiving(events) < 0 || udev_monitor_get_fd(events) < 0) {
      if (events)
        udev_monitor_unref(events);
      events = nullptr;
      udev_unref(context);
      context = nullptr;
      return false;
    }
    notifier = new QSocketNotifier(udev_monitor_get_fd(events), QSocketNotifier::Read, this);
    connect(notifier, &QSocketNotifier::activated, this, [this] { drain(); });
    return true;
  }
  void drain() {
    while (events) {
      auto *device = udev_monitor_receive_device(events);
      if (!device)
        break;
      const QString type = QString::fromUtf8(udev_device_get_devtype(device));
      const QString action = QString::fromUtf8(udev_device_get_action(device));
      const QString name = QString::fromUtf8(udev_device_get_sysname(device));
      QString instance;
      const auto bus = QString::fromUtf8(udev_device_get_property_value(device, "BUSNUM"));
      const auto number = QString::fromUtf8(udev_device_get_property_value(device, "DEVNUM"));
      bool busOk = false, numberOk = false;
      const auto busNumber = bus.toUInt(&busOk);
      const auto deviceNumber = number.toUInt(&numberOk);
      if (busOk && numberOk)
        instance = name + QLatin1Char('@') + QString::number(busNumber) + QLatin1Char(':') +
                   QString::number(deviceNumber);
      // Release the received device before dispatch can suspend the subscription.
      udev_device_unref(device);
      if (type == QStringLiteral("usb_device")) {
        if (action == QStringLiteral("add"))
          deviceEvent(true, name, instance);
        else if (action == QStringLiteral("remove"))
          deviceEvent(false, name, instance);
        else
          ReconciliationMonitor::refresh();
      }
    }
  }
  udev *context = nullptr;
  udev_monitor *events = nullptr;
  QSocketNotifier *notifier = nullptr;
  QTimer registrationRetry;
};
Snapshot fixtures() {
  Snapshot result;
  for (const auto &pair : {std::pair{QStringLiteral("iPhone 17 Pro Max"), QStringLiteral("1-1")},
                           std::pair{QStringLiteral("Samsung T7"), QStringLiteral("1-2")}}) {
    Device device;
    device.id = pair.second + QStringLiteral("@1:2");
    device.topology = pair.second;
    device.name = pair.first;
    device.manufacturer = pair.first.startsWith(QStringLiteral("iPhone"))
                              ? QStringLiteral("Apple")
                              : QStringLiteral("Samsung");
    device.speed = Speed::Gen2;
    device.rawSpeed = QStringLiteral("10000");
    device.vendorId = device.manufacturer == QStringLiteral("Apple") ? 0x05ac : 0x04e8;
    device.productId = device.manufacturer == QStringLiteral("Apple") ? 0x12ab : 0x61f5;
    result.devices.append(device);
  }
  return result;
}
} // namespace
Monitor *makeMonitor(bool fixtureMode, QObject *parent) {
  if (fixtureMode)
    return new ReconciliationMonitor(fixtures, parent);
  return new UdevMonitor(parent);
}
} // namespace boop
