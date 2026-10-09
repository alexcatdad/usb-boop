#include "reconciliation.h"
#include <QHash>
#include <algorithm>

namespace boop {
ReconciliationMonitor::ReconciliationMonitor(std::function<Snapshot()> scan, QObject *parent)
    : Monitor(parent), reader(std::move(scan)) {
  retry.setInterval(2000);
  connect(&retry, &QTimer::timeout, this, [this] { ReconciliationMonitor::refresh(); });
}
void ReconciliationMonitor::updateStatus(Status status) {
  if (currentStatus == status)
    return;
  currentStatus = status;
  emit statusChanged(status);
}
void ReconciliationMonitor::setRegistrationAvailable(bool available, bool reconcileNow) {
  registered = available;
  if (running && reconcileNow && currentStatus.issue != Issue::AccessRestricted)
    reconcile(false);
}
void ReconciliationMonitor::start() {
  if (running)
    return;
  running = true;
  updateStatus({State::Starting, Issue::None});
  reconcile(true);
}
void ReconciliationMonitor::stop() {
  running = false;
  retry.stop();
  pendingAttachments.clear();
  initialIds.clear();
  updateStatus({State::Stopped, Issue::None});
}
void ReconciliationMonitor::refresh() {
  if (!running) {
    start();
    return;
  }
  reconcile(false);
}
void ReconciliationMonitor::reconcileAfterWake() {
  if (running && currentStatus.issue != Issue::AccessRestricted)
    reconcile(false);
}
void ReconciliationMonitor::publishObservation(ObservationKind kind, const Device &device) {
  auto safe = device;
  safe.serialNumber.clear();
  emit observation({kind, safe, QDateTime::currentDateTimeUtc()});
}
void ReconciliationMonitor::deviceEvent(bool added, const QString &topology,
                                        const QString &instanceId) {
  if (!running || currentStatus.issue == Issue::AccessRestricted)
    return;
  if (added) {
    pendingAttachments.insert(topology, instanceId);
  } else {
    if (pendingAttachments.value(topology) == instanceId || instanceId.isEmpty())
      pendingAttachments.remove(topology);
    for (qsizetype i = current.devices.size(); i > 0; --i) {
      if (current.devices[i - 1].topology != topology ||
          (!instanceId.isEmpty() && current.devices[i - 1].id != instanceId))
        continue;
      const auto removed = current.devices.takeAt(i - 1);
      initialIds.remove(removed.id);
      emit detached(removed);
      publishObservation(ObservationKind::Detached, removed);
    }
    emit devicesChanged(current.devices);
  }
  reconcile(false);
}
void ReconciliationMonitor::reconcile(bool baseline) {
  auto next = reader();
  if (next.failed) {
    current.failed = true;
    current.issue = next.issue;
    updateStatus({current.devices.isEmpty() ? State::Unavailable : State::Degraded, next.issue});
    if (next.issue == Issue::AccessRestricted) {
      retry.stop();
      pendingAttachments.clear();
      onAccessRestricted();
    } else
      retry.start();
    return;
  }
  QList<Observation> deferred;
  QHash<QString, Device> old;
  for (const auto &device : current.devices)
    old.insert(device.id, device);
  const auto now = QDateTime::currentDateTimeUtc();
  for (auto &device : next.devices) {
    if (baseline)
      initialIds.insert(device.id);
    const bool eventMatches = pendingAttachments.contains(device.topology) &&
                              (pendingAttachments.value(device.topology).isEmpty() ||
                               pendingAttachments.value(device.topology) == device.id);
    if (old.contains(device.id)) {
      const auto previous = old.take(device.id);
      if (device.manufacturer.isEmpty())
        device.manufacturer = previous.manufacturer;
      if (!device.vendorId)
        device.vendorId = previous.vendorId;
      if (!device.productId)
        device.productId = previous.productId;
      if (device.serialNumber.isEmpty())
        device.serialNumber = previous.serialNumber;
      device.firstSeenAt = previous.firstSeenAt;
      device.connectedAt = previous.connectedAt;
      if (eventMatches) {
        pendingAttachments.remove(device.topology);
        if (!baseline && !initialIds.contains(device.id) && !device.connectedAt.isValid()) {
          device.connectedAt = now;
          deferred.append({ObservationKind::Attached, device, now});
        }
      }
    } else {
      device.firstSeenAt = now;
      if (!baseline && eventMatches) {
        pendingAttachments.remove(device.topology);
        device.connectedAt = now;
        deferred.append({ObservationKind::Attached, device, now});
      } else if (!baseline) {
        deferred.append({ObservationKind::FirstSeen, device, now});
      }
    }
  }
  for (const auto &previous : old) {
    if (next.issue != Issue::None)
      next.devices.append(previous);
    else if (!baseline) {
      initialIds.remove(previous.id);
      deferred.prepend({ObservationKind::NoLongerDetected, previous, now});
    }
  }
  std::sort(next.devices.begin(), next.devices.end(), [](const Device &left, const Device &right) {
    if (left.firstSeenAt != right.firstSeenAt)
      return left.firstSeenAt > right.firstSeenAt;
    return QString::compare(left.name, right.name, Qt::CaseInsensitive) < 0;
  });
  current = next;
  const auto issue = next.issue != Issue::None ? next.issue
                     : registered              ? Issue::None
                                               : Issue::RegistrationFailed;
  updateStatus({issue == Issue::None ? State::Monitoring : State::Degraded, issue});
  if (issue == Issue::AccessRestricted) {
    pendingAttachments.clear();
    onAccessRestricted();
  }
  if (issue != Issue::AccessRestricted && (issue != Issue::None || !pendingAttachments.isEmpty()))
    retry.start();
  else
    retry.stop();
  emit devicesChanged(current.devices);
  // Consumers must see the reconciled snapshot and status before connection callbacks.
  for (const auto &event : deferred) {
    if (event.kind == ObservationKind::Attached)
      emit attached(event.device);
    else if (event.kind == ObservationKind::NoLongerDetected)
      emit detached(event.device);
    publishObservation(event.kind, event.device);
  }
}
} // namespace boop
