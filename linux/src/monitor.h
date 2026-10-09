#pragma once
#include "domain.h"
#include <QObject>

namespace boop {
class Monitor : public QObject {
  Q_OBJECT
public:
  using QObject::QObject;
  virtual void start() = 0;
  virtual void stop() = 0;
  virtual void refresh() = 0;
  virtual void reconcileAfterWake() = 0;
  virtual Snapshot snapshot() const = 0;
  virtual Status status() const = 0;
signals:
  void devicesChanged(const QList<boop::Device> &devices);
  void attached(const boop::Device &device);
  void detached(const boop::Device &device);
  void statusChanged(boop::Status status);
  void observation(const boop::Observation &observation);
};
Monitor *makeMonitor(bool fixtures, QObject *parent = nullptr);
Snapshot readSysfs(const QString &root = QStringLiteral("/sys/bus/usb/devices"));
} // namespace boop
