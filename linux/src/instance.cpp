#include "instance.h"
#include <QDir>
#include <QLocalSocket>
#include <QStandardPaths>
namespace boop {
SingleInstance::SingleInstance(QObject *parent) : QObject(parent) {
  server_.setSocketOptions(QLocalServer::UserAccessOption);
  connect(&server_, &QLocalServer::newConnection, this, [this] {
    while (auto *socket = server_.nextPendingConnection()) {
      connect(socket, &QLocalSocket::disconnected, socket, &QObject::deleteLater);
      auto activate = [this, socket] {
        if (socket->readAll().contains("activate"))
          emit activationRequested();
        socket->disconnectFromServer();
      };
      connect(socket, &QLocalSocket::readyRead, this, activate);
      if (socket->bytesAvailable())
        activate();
    }
  });
}
SingleInstance::Result SingleInstance::acquire() {
  const QString runtime = QStandardPaths::writableLocation(QStandardPaths::RuntimeLocation);
  if (runtime.isEmpty() || !QDir(runtime).exists())
    return Result::Failed;
  QByteArray session = qgetenv("XDG_SESSION_ID");
  if (session.isEmpty())
    session = qgetenv("DBUS_SESSION_BUS_ADDRESS");
  if (session.isEmpty())
    session = qgetenv("DISPLAY") + qgetenv("WAYLAND_DISPLAY");
  const QString path = runtime + "/usb-boop-" + QString::number(qHash(session, 0), 16);
  lock_ = std::make_unique<QLockFile>(path + ".lock");
  lock_->setStaleLockTime(0);
  if (!lock_->tryLock(0)) {
    for (int attempt = 0; attempt < 10; ++attempt) {
      QLocalSocket socket;
      socket.connectToServer(path);
      if (socket.waitForConnected(100)) {
        socket.write("activate\n");
        socket.flush();
        socket.waitForBytesWritten(100);
        return Result::ActivatedExisting;
      }
    }
    return Result::Failed;
  }
  QLocalServer::removeServer(path);
  if (!server_.listen(path)) {
    lock_->unlock();
    return Result::Failed;
  }
  return Result::Primary;
}
} // namespace boop
