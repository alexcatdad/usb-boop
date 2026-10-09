#include "domain.h"
#include <QChar>
#include <QStringList>
#include <cmath>

namespace boop {
Speed parseSpeed(const QString &raw) {
  bool ok = false;
  const double rate = raw.trimmed().toDouble(&ok);
  if (!ok || !std::isfinite(rate) || rate <= 0)
    return Speed::Unknown;
  if (rate == 1.5)
    return Speed::Low;
  if (rate == 12)
    return Speed::Full;
  if (rate == 480)
    return Speed::High;
  if (rate == 5000)
    return Speed::Gen1;
  if (rate == 10000)
    return Speed::Gen2;
  if (rate == 20000)
    return Speed::Gen2x2;
  return Speed::Other;
}
QString speedLabel(Speed speed) {
  switch (speed) {
  case Speed::Low:
    return QStringLiteral("1.5 Mbps");
  case Speed::Full:
    return QStringLiteral("12 Mbps");
  case Speed::High:
    return QStringLiteral("480 Mbps");
  case Speed::Gen1:
    return QStringLiteral("5 Gbps");
  case Speed::Gen2:
    return QStringLiteral("10 Gbps");
  case Speed::Gen2x2:
    return QStringLiteral("20 Gbps");
  default:
    return QStringLiteral("Link speed unavailable");
  }
}
QString technicalLabel(Speed speed) {
  switch (speed) {
  case Speed::Low:
    return QStringLiteral("USB 1.x low speed");
  case Speed::Full:
    return QStringLiteral("USB 1.1 full speed");
  case Speed::High:
    return QStringLiteral("USB 2.0 high speed");
  case Speed::Gen1:
    return QStringLiteral("USB 3.2 Gen 1");
  case Speed::Gen2:
    return QStringLiteral("USB 3.2 Gen 2");
  case Speed::Gen2x2:
    return QStringLiteral("USB 3.2 Gen 2x2");
  case Speed::Other:
    return QStringLiteral("Unclassified USB connection speed");
  default:
    return {};
  }
}
QString sanitize(const QString &raw) {
  QString cleaned;
  for (auto cp : raw.toUcs4()) {
    auto category = QChar::category(cp);
    if (category == QChar::Other_Control || category == QChar::Other_Format ||
        category == QChar::Other_Surrogate || category == QChar::Other_PrivateUse ||
        category == QChar::Other_NotAssigned)
      continue;
    const char32_t scalar = cp;
    cleaned += QString::fromUcs4(&scalar, 1);
  }
  auto result = cleaned.trimmed().toStdU32String();
  if (result.size() > 128)
    result.resize(128);
  return QString::fromStdU32String(result);
}
QString statusMessage(Status status) {
  switch (status.issue) {
  case Issue::AccessRestricted:
    return QStringLiteral("USB metadata access is restricted.");
  case Issue::RegistrationFailed:
    return QStringLiteral("USB event monitoring is unavailable. Retrying automatically.");
  case Issue::EnumerationFailed:
    return QStringLiteral("USB devices could not be read. Previous results may be stale.");
  case Issue::IncompleteResults:
    return QStringLiteral("Some USB metadata is unavailable. Previous results may be stale.");
  default:
    return status.state == State::Stopped ? QStringLiteral("Monitoring stopped")
                                          : QStringLiteral("Monitoring USB connections");
  }
}
} // namespace boop
