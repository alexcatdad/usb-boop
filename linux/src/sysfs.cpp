#include "monitor.h"
#include <QDir>
#include <QFile>
#include <QFileInfo>

namespace boop {
namespace {
QString attribute(const QString &path, const QString &name, bool *readable = nullptr) {
  QFile file(path + QLatin1Char('/') + name);
  const bool ok = file.open(QIODevice::ReadOnly);
  if (readable)
    *readable = ok;
  return ok ? QString::fromUtf8(file.read(4096)).trimmed() : QString();
}
std::optional<unsigned> hexId(const QString &raw) {
  bool ok;
  unsigned value = raw.toUInt(&ok, 16);
  return ok && value <= 65535 ? std::optional<unsigned>(value) : std::nullopt;
}
} // namespace
Snapshot readSysfs(const QString &root) {
  Snapshot result;
  QFileInfo rootInfo(root);
  if (!rootInfo.isDir() || !rootInfo.isReadable() || !rootInfo.isExecutable()) {
    result.failed = true;
    result.issue = rootInfo.exists() ? Issue::AccessRestricted : Issue::EnumerationFailed;
    return result;
  }
  QDir directory(root);
  for (const auto &entry :
       directory.entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot | QDir::System, QDir::Name)) {
    if (entry.fileName().contains(QLatin1Char(':')))
      continue;
    const auto path = entry.absoluteFilePath();
    // USB device directories have busnum and devnum. Interface nodes never do.
    bool busReadable = false, deviceReadable = false;
    const auto bus = attribute(path, QStringLiteral("busnum"), &busReadable);
    const auto number = attribute(path, QStringLiteral("devnum"), &deviceReadable);
    bool busValid = false, numberValid = false;
    const auto busValue = bus.toUInt(&busValid);
    const auto numberValue = number.toUInt(&numberValid);
    if (!busReadable || !deviceReadable || !busValid || !numberValid) {
      result.issue = Issue::IncompleteResults;
      continue;
    }
    Device device;
    device.topology = entry.fileName();
    device.id = device.topology + QLatin1Char('@') + QString::number(busValue) + QLatin1Char(':') +
                QString::number(numberValue);
    device.vendorId = hexId(attribute(path, QStringLiteral("idVendor")));
    device.productId = hexId(attribute(path, QStringLiteral("idProduct")));
    device.name = sanitize(attribute(path, QStringLiteral("product")));
    device.manufacturer = sanitize(attribute(path, QStringLiteral("manufacturer")));
    device.serialNumber = sanitize(attribute(path, QStringLiteral("serial")));
    if (device.name.isEmpty()) {
      if (!device.manufacturer.isEmpty())
        device.name = device.manufacturer + QStringLiteral(" USB Device");
      else if (device.vendorId && device.productId)
        device.name = QStringLiteral("USB Device %1:%2")
                          .arg(*device.vendorId, 4, 16, QLatin1Char('0'))
                          .arg(*device.productId, 4, 16, QLatin1Char('0'))
                          .toUpper()
                          .replace(QStringLiteral("USB DEVICE"), QStringLiteral("USB Device"));
      else
        device.name = QStringLiteral("USB Device");
    }
    bool speedReadable = false;
    device.rawSpeed = sanitize(attribute(path, QStringLiteral("speed"), &speedReadable));
    device.speed = parseSpeed(device.rawSpeed);
    device.isHub = attribute(path, QStringLiteral("bDeviceClass")).toUInt(nullptr, 16) == 9;
    if (!speedReadable)
      result.issue = Issue::IncompleteResults;
    // Do not combine attributes across a connection that vanished during reading.
    if (attribute(path, QStringLiteral("devnum")) != number ||
        attribute(path, QStringLiteral("busnum")) != bus) {
      result.issue = Issue::IncompleteResults;
      continue;
    }
    result.devices.append(device);
  }
  return result;
}
} // namespace boop
