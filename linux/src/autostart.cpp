#include "autostart.h"
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QSaveFile>
#include <QStandardPaths>
namespace boop {
XdgAutostart::XdgAutostart(QString executable, QString directory, QObject *parent)
    : AutostartService(parent), executable_(QFileInfo(executable).absoluteFilePath()) {
  if (directory.isEmpty())
    directory = QStandardPaths::writableLocation(QStandardPaths::ConfigLocation);
  path_ = directory + "/autostart/usb-boop.desktop";
}
bool XdgAutostart::enabled() const { return QFileInfo::exists(path_); }
bool XdgAutostart::setEnabled(bool value) {
  error_.clear();
  if (!value) {
    if (!enabled() || QFile::remove(path_))
      return true;
    error_ = "Could not remove login entry.";
    return false;
  }
  if (!QFileInfo(executable_).isExecutable() || executable_.contains('\n') ||
      executable_.contains('\r') || executable_.contains('\t') || executable_.contains('=')) {
    error_ = "The installed executable is unavailable.";
    return false;
  }
  QDir().mkpath(QFileInfo(path_).absolutePath());
  // Encode both Desktop Entry string-value and quoted Exec argument escaping.
  // A literal backslash requires four written backslashes; $, ` and quotes
  // require two before the character. Percent is a literal field-code escape.
  QString escaped;
  for (const QChar character : executable_) {
    if (character == QLatin1Char('\\'))
      escaped += QStringLiteral("\\\\\\\\");
    else if (character == QLatin1Char('"') || character == QLatin1Char('`') ||
             character == QLatin1Char('$'))
      escaped += QStringLiteral("\\\\") + character;
    else if (character == QLatin1Char('%'))
      escaped += QStringLiteral("%%");
    else
      escaped += character;
  }
  QSaveFile file(path_);
  if (!file.open(QIODevice::WriteOnly)) {
    error_ = file.errorString();
    return false;
  }
  const QByteArray data =
      QString(
          "[Desktop Entry]\nType=Application\nName=usb-boop\nExec=\"%1\" "
          "--background\nIcon=usb-boop\nTerminal=false\nComment=Monitor USB connection speeds\n")
          .arg(escaped)
          .toUtf8();
  if (file.write(data) != data.size() || !file.commit()) {
    error_ = file.errorString();
    return false;
  }
  return true;
}
} // namespace boop
