#include "notifications.h"
#include "app.h"
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusInterface>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusServiceWatcher>
#include <QMap>
namespace boop {
class DBusNotifications final : public NotificationService {
  Q_OBJECT
public:
  explicit DBusNotifications(QObject *parent)
      : NotificationService(parent),
        watcher_("org.freedesktop.Notifications", QDBusConnection::sessionBus(),
                 QDBusServiceWatcher::WatchForOwnerChange, this) {
    connect(&watcher_, &QDBusServiceWatcher::serviceOwnerChanged, this, [this] {
      ++generation_;
      available_ = false;
      capabilities_.clear();
      deliveries_.clear();
      probe();
    });
    probe();
    QDBusConnection::sessionBus().connect("org.freedesktop.Notifications",
                                          "/org/freedesktop/Notifications",
                                          "org.freedesktop.Notifications", "NotificationClosed",
                                          this, SLOT(notificationClosed(uint, uint)));
  }
  bool available() const override { return available_; }
  bool supportsSound() const override { return capabilities_.contains("sound"); }
  QString summary() const override {
    return error_.isEmpty() ? (available_ ? "Connection banners available."
                                          : "Desktop notification service unavailable.")
                            : error_;
  }
  void deliver(const QList<Device> &devices, bool sound) override {
    if (!available_ || devices.isEmpty())
      return;
    while (deliveries_.size() >= 100) {
      auto first = deliveries_.begin();
      if (first->notification)
        close(first->notification);
      deliveries_.erase(first);
    }
    const quint64 token = ++sequence_;
    Delivery delivery;
    for (const auto &device : devices)
      delivery.devices.insert(device.id);
    deliveries_.insert(token, delivery);
    QStringList names;
    for (const auto &device : devices)
      names << device.name + " · " + speedLabel(device.speed);
    const QString title = devices.size() == 1
                              ? devices.first().name
                              : QString("%1 USB devices connected").arg(devices.size());
    const QString body =
        devices.size() == 1 ? "Connected · " + linkSpeedSummary(devices.first()) : names.join('\n');
    QVariantMap hints{{"desktop-entry", "usb-boop"},
                      {"urgency", QVariant::fromValue<uchar>(0)},
                      {"suppress-sound", !sound || !supportsSound()}};
    if (sound && supportsSound())
      hints.insert("sound-name", "device-added");
    QDBusMessage message = QDBusMessage::createMethodCall(
        "org.freedesktop.Notifications", "/org/freedesktop/Notifications",
        "org.freedesktop.Notifications", "Notify");
    message << QString("usb-boop") << uint(0) << QString("usb-boop") << title
            << body.toHtmlEscaped() << QStringList{} << hints << 5000;
    auto *call =
        new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(message), this);
    const quint64 generation = generation_;
    connect(call, &QDBusPendingCallWatcher::finished, this,
            [this, token, generation](QDBusPendingCallWatcher *watcher) {
              QDBusPendingReply<uint> reply = *watcher;
              watcher->deleteLater();
              if (generation != generation_)
                return;
              auto found = deliveries_.find(token);
              if (reply.isError()) {
                error_ = "Could not deliver connection banner: " + reply.error().message();
                deliveries_.remove(token);
                emit changed();
                return;
              }
              if (found == deliveries_.end() || found->cancelled) {
                close(reply.value());
                deliveries_.remove(token);
                return;
              }
              found->notification = reply.value();
              if (!error_.isEmpty()) {
                error_.clear();
                emit changed();
              }
            });
  }
  void cancel(const QString &deviceId) override {
    for (auto it = deliveries_.begin(); it != deliveries_.end(); ++it)
      if (it->devices.contains(deviceId)) {
        it->cancelled = true;
        if (it->notification)
          close(it->notification);
      }
  }
  void cancelAll() override {
    for (auto it = deliveries_.begin(); it != deliveries_.end(); ++it) {
      it->cancelled = true;
      if (it->notification)
        close(it->notification);
    }
  }
public slots:
  void notificationClosed(uint id, uint reason) {
    Q_UNUSED(reason);
    for (auto it = deliveries_.begin(); it != deliveries_.end();) {
      if (it->notification == id)
        it = deliveries_.erase(it);
      else
        ++it;
    }
  }

private:
  struct Delivery {
    QSet<QString> devices;
    uint notification = 0;
    bool cancelled = false;
  };
  QDBusServiceWatcher watcher_;
  bool available_ = false;
  QStringList capabilities_;
  QString error_;
  quint64 sequence_ = 0, generation_ = 0;
  QMap<quint64, Delivery> deliveries_;
  void close(uint id) {
    QDBusMessage message = QDBusMessage::createMethodCall(
        "org.freedesktop.Notifications", "/org/freedesktop/Notifications",
        "org.freedesktop.Notifications", "CloseNotification");
    message << id;
    QDBusConnection::sessionBus().asyncCall(message);
  }
  void probe() {
    error_.clear();
    QDBusMessage message = QDBusMessage::createMethodCall(
        "org.freedesktop.Notifications", "/org/freedesktop/Notifications",
        "org.freedesktop.Notifications", "GetCapabilities");
    auto *call =
        new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(message), this);
    const quint64 generation = generation_;
    connect(call, &QDBusPendingCallWatcher::finished, this,
            [this, generation](QDBusPendingCallWatcher *watcher) {
              QDBusPendingReply<QStringList> reply = *watcher;
              watcher->deleteLater();
              if (generation != generation_)
                return;
              available_ = !reply.isError();
              capabilities_ = available_ ? reply.value() : QStringList{};
              emit changed();
            });
  }
};
NotificationService *makeNotificationService(QObject *parent) {
  return new DBusNotifications(parent);
}
} // namespace boop

#include "notifications.moc"
