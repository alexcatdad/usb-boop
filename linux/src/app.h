#pragma once
#include "autostart.h"
#include "monitor.h"
#include "notifications.h"
#include <QSettings>
#include <QTimer>
namespace boop {
class AppModel : public QObject {
  Q_OBJECT
public:
  AppModel(Monitor *monitor, NotificationService *notifications, AutostartService *autostart,
           QSettings *settings, QObject *parent = nullptr);
  QList<Device> devices() const;
  QList<Observation> history() const;
  std::optional<Device> latest() const { return latest_; }
  QString latestStatus() const;
  QString emptyDevicesMessage() const;
  Status status() const { return monitor_->status(); }
  NotificationService *notifications() const { return notifications_; }
  AutostartService *autostart() const { return autostart_; }
  bool preference(const QString &key) const;
  void setPreference(const QString &key, bool value);
  void refresh();
  void clearHistory();
  void flushNotifications();
public slots:
  void prepareForSleep(bool sleeping);
signals:
  void changed();

private:
  Monitor *monitor_;
  NotificationService *notifications_;
  AutostartService *autostart_;
  QSettings *settings_;
  QList<Device> devices_, pending_;
  QSet<QString> announced_;
  QList<Observation> history_;
  std::optional<Device> latest_;
  QTimer batch_;
};
QString linkSpeedSummary(const Device &device);
QString copyText(const Device &device);
} // namespace boop
