#pragma once
#include "monitor.h"
#include <QHash>
#include <QSet>
#include <QTimer>
#include <functional>

namespace boop {
class ReconciliationMonitor : public Monitor {
public:
  explicit ReconciliationMonitor(std::function<Snapshot()> reader, QObject *parent = nullptr);
  void start() override;
  void stop() override;
  void refresh() override;
  void reconcileAfterWake() override;
  Snapshot snapshot() const override { return current; }
  Status status() const override { return currentStatus; }
  void deviceEvent(bool added, const QString &topology, const QString &instanceId = {});

protected:
  void setRegistrationAvailable(bool available, bool reconcileNow = true);
  virtual void onAccessRestricted() {}
  void updateStatus(Status status);
  bool running = false;

private:
  void reconcile(bool baseline, bool resumed = false);
  void publishObservation(ObservationKind kind, const Device &device);
  std::function<Snapshot()> reader;
  Snapshot current;
  Status currentStatus;
  QHash<QString, QString> pendingAttachments;
  QSet<QString> initialIds;
  QTimer retry;
  bool registered = true;
};
} // namespace boop
