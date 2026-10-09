#include "notifications.h"
#include <QDBusConnection>
#include <QDBusContext>
#include <QDBusMessage>
#include <QTimer>
#include <QtTest>
#include <memory>
using namespace boop;
class NotificationServer : public QObject, protected QDBusContext {
  Q_OBJECT
  Q_CLASSINFO("D-Bus Interface", "org.freedesktop.Notifications")
public:
  QStringList capabilities{"sound", "body-markup"};
  QString body;
  QVariantMap hints;
  QList<uint> closed;
  uint next = 1;
  bool fail = false, delay = false;
public slots:
  QStringList GetCapabilities() { return capabilities; }
  uint Notify(const QString &, uint, const QString &, const QString &, const QString &text,
              const QStringList &, const QVariantMap &options, int) {
    body = text;
    hints = options;
    if (fail) {
      sendErrorReply(QDBusError::Failed, "Fixture service failure");
      return 0;
    }
    const uint id = next++;
    if (delay) {
      setDelayedReply(true);
      const QDBusMessage request = message();
      const auto bus = connection();
      QTimer::singleShot(30, this, [request, bus, id] {
        bus.send(request.createReply(QVariantList{QVariant::fromValue(id)}));
      });
    }
    return id;
  }
  void CloseNotification(uint id) {
    closed.append(id);
    emit NotificationClosed(id, 3);
  }
signals:
  void NotificationClosed(uint id, uint reason);
};
class NotificationTests : public QObject {
  Q_OBJECT
private slots:
  void notificationProtocol() {
    auto bus = QDBusConnection::connectToBus(QDBusConnection::SessionBus, "notification-fixture");
    QVERIFY(bus.isConnected());
    NotificationServer server;
    QVERIFY(bus.registerService("org.freedesktop.Notifications"));
    QVERIFY(
        bus.registerObject("/org/freedesktop/Notifications", &server,
                           QDBusConnection::ExportAllSlots | QDBusConnection::ExportAllSignals));
    std::unique_ptr<NotificationService> service(makeNotificationService());
    QTRY_VERIFY(service->available());
    QVERIFY(service->supportsSound());
    Device one;
    one.id = "one";
    one.name = "<b>device & name</b>";
    one.speed = Speed::High;
    Device two = one;
    two.id = "two";
    service->deliver({one, two}, true);
    QTRY_VERIFY(!server.body.isEmpty());
    QVERIFY(server.body.contains("&lt;b&gt;"));
    QVERIFY(!server.body.contains("<b>"));
    QCOMPARE(server.hints.value("sound-name").toString(), QString("device-added"));
    QVERIFY(!server.hints.value("suppress-sound").toBool());
    service->cancel("one");
    QTRY_COMPARE(server.closed.size(), 1);
    server.delay = true;
    service->deliver({one}, false);
    service->cancel("one");
    QTRY_COMPARE(server.closed.size(), 2);
    QVERIFY(server.hints.value("suppress-sound").toBool());
    server.fail = true;
    service->deliver({two}, false);
    QTRY_VERIFY(service->summary().contains("Fixture service failure"));
    bus.unregisterService("org.freedesktop.Notifications");
    QTRY_VERIFY(!service->available());
    QVERIFY(!service->supportsSound());
    server.fail = false;
    server.capabilities.clear();
    QVERIFY(bus.registerService("org.freedesktop.Notifications"));
    QTRY_VERIFY(service->available());
    QVERIFY(!service->supportsSound());
    service->deliver({two}, true);
    QTRY_COMPARE(server.next, uint(4));
    QVERIFY(server.hints.value("suppress-sound").toBool());
    service->deliver({two}, false);
    QTRY_VERIFY(!service->summary().contains("Fixture service failure"));
    bus.unregisterObject("/org/freedesktop/Notifications");
    bus.unregisterService("org.freedesktop.Notifications");
    QDBusConnection::disconnectFromBus("notification-fixture");
  }
};
QTEST_GUILESS_MAIN(NotificationTests)
#include "desktop_dbus_test.moc"
