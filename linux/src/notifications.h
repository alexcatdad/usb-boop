#pragma once
#include "domain.h"
#include <QObject>
#include <QSet>
#include <QStringList>
namespace boop {
class NotificationService : public QObject {
  Q_OBJECT
public:
  using QObject::QObject;
  virtual bool available() const = 0;
  virtual bool supportsSound() const = 0;
  virtual QString summary() const = 0;
  virtual void deliver(const QList<Device> &devices, bool sound) = 0;
  virtual void cancel(const QString &deviceId) = 0;
  virtual void cancelAll() = 0;
signals:
  void changed();
};
NotificationService *makeNotificationService(QObject *parent = nullptr);
} // namespace boop
