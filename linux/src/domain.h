#pragma once
#include <QDateTime>
#include <QList>
#include <QMetaType>
#include <QString>
#include <optional>

namespace boop {
enum class Speed { Unknown, Low, Full, High, Gen1, Gen2, Gen2x2, Other };
Speed parseSpeed(const QString &raw);
QString speedLabel(Speed speed);
QString technicalLabel(Speed speed);
QString sanitize(const QString &raw);
struct Device {
  QString id;
  QString topology;
  QString name;
  QString manufacturer;
  QString serialNumber;
  std::optional<unsigned> vendorId;
  std::optional<unsigned> productId;
  Speed speed = Speed::Unknown;
  QString rawSpeed;
  bool isHub = false;
  QDateTime firstSeenAt;
  QDateTime connectedAt;
  bool operator==(const Device &) const = default;
};
enum class Issue {
  None,
  AccessRestricted,
  RegistrationFailed,
  EnumerationFailed,
  IncompleteResults
};
enum class State { Stopped, Starting, Monitoring, Degraded, Unavailable };
struct Status {
  State state = State::Stopped;
  Issue issue = Issue::None;
  bool reliable() const { return state == State::Monitoring; }
  bool operator==(const Status &) const = default;
};
QString statusMessage(Status status);
enum class ObservationKind { Attached, Detached, FirstSeen, NoLongerDetected };
struct Observation {
  ObservationKind kind;
  Device device; // Serial number must be removed before creating history.
  QDateTime observedAt;
};
struct Snapshot {
  QList<Device> devices;
  Issue issue = Issue::None;
  bool failed = false;
};
} // namespace boop
Q_DECLARE_METATYPE(boop::Device)
Q_DECLARE_METATYPE(boop::Status)
Q_DECLARE_METATYPE(boop::Observation)
