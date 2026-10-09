#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QProcessEnvironment>
#include <QTest>

class CliTest : public QObject {
  Q_OBJECT
private slots:
  void headlessEntryPoints() {
    for (const auto &arguments :
         QList<QStringList>{{"--version"}, {"--help"}, {"--fixtures", "--list", "--json"}}) {
      QProcess process;
      auto environment = QProcessEnvironment::systemEnvironment();
      environment.remove("DISPLAY");
      environment.remove("WAYLAND_DISPLAY");
      environment.remove("QT_QPA_PLATFORM");
      process.setProcessEnvironment(environment);
      process.start(QStringLiteral(USB_BOOP_BINARY), arguments);
      QVERIFY(process.waitForFinished(10000));
      QCOMPARE(process.exitStatus(), QProcess::NormalExit);
      QCOMPARE(process.exitCode(), 0);
      if (arguments.contains("--json")) {
        QJsonParseError error;
        const auto bytes = process.readAllStandardOutput();
        const auto document = QJsonDocument::fromJson(bytes, &error);
        QCOMPARE(error.error, QJsonParseError::NoError);
        QVERIFY(document.isObject());
        QVERIFY(document.object().value("reliable").toBool());
        QVERIFY(document.object().value("devices").isArray());
        QVERIFY(!bytes.contains("serial"));
      }
    }
  }
  void jsonRequiresSnapshot() {
    QProcess process;
    process.start(QStringLiteral(USB_BOOP_BINARY), {"--json"});
    QVERIFY(process.waitForFinished(10000));
    QCOMPARE(process.exitCode(), 2);
    QVERIFY(process.readAllStandardError().contains("Use --json with --list"));
  }
};
QTEST_GUILESS_MAIN(CliTest)
#include "cli_test.moc"
