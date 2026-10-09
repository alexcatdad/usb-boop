#include "app.h"
#include "autostart.h"
#include "instance.h"
#include "monitor.h"
#include "notifications.h"
#include "window.h"
#include <QApplication>
#include <QCommandLineParser>
#include <QDir>
#include <QFileInfo>
#include <QIcon>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSettings>
#include <QTextStream>
#include <QTimer>
#include <memory>

namespace {
QJsonObject deviceJson(const boop::Device &device) {
  return {
      {"id", device.id},
      {"topology", device.topology},
      {"name", device.name},
      {"manufacturer", device.manufacturer},
      {"vendorId", device.vendorId ? QJsonValue(static_cast<int>(*device.vendorId)) : QJsonValue()},
      {"productId",
       device.productId ? QJsonValue(static_cast<int>(*device.productId)) : QJsonValue()},
      {"speed", boop::speedLabel(device.speed)},
      {"rawSpeed", device.rawSpeed},
      {"isHub", device.isHub}};
}

QString stableExecutable() {
  const QString path = QCoreApplication::applicationFilePath();
  const QString marker = QStringLiteral("/Cellar/usb-boop/");
  const auto index = path.indexOf(marker);
  if (index >= 0) {
    const QString stable = path.left(index) + QStringLiteral("/opt/usb-boop/bin/usb-boop");
    if (QFileInfo::exists(stable))
      return stable;
  }
  return path;
}
} // namespace

int main(int argc, char **argv) {
  bool headless = false;
  for (int i = 1; i < argc; ++i) {
    const QString argument = QString::fromLocal8Bit(argv[i]);
    headless |= argument == "--list" || argument == "--json" || argument == "--version" ||
                argument == "-v" || argument == "--help" || argument == "-h" ||
                argument == "--help-all";
  }
  std::unique_ptr<QCoreApplication> application;
  if (headless)
    application = std::make_unique<QCoreApplication>(argc, argv);
  else
    application = std::make_unique<QApplication>(argc, argv);
  QCoreApplication::setApplicationName(QStringLiteral("usb-boop"));
  QCoreApplication::setOrganizationName(QStringLiteral("com.alexcatdad"));
  QCoreApplication::setApplicationVersion(QStringLiteral(USB_BOOP_VERSION));

  QCommandLineParser parser;
  parser.setApplicationDescription(QStringLiteral("Report negotiated USB connection speeds"));
  parser.addHelpOption();
  parser.addVersionOption();
  parser.addOptions({{"list", "Print a read-only device snapshot and exit."},
                     {"json", "Format the device snapshot as JSON (requires --list)."},
                     {"fixtures", "Use simulated USB devices instead of hardware."},
                     {"smoke-test", "Open the application briefly and exit."},
                     {"no-tray", "Use a regular window without a tray icon."},
                     {"background", "Start hidden if a usable tray host is available."}});
  parser.process(*application);
  if (!parser.positionalArguments().isEmpty() || (parser.isSet("json") && !parser.isSet("list"))) {
    QTextStream(stderr) << "Use --json with --list; positional arguments are not supported.\n";
    return 2;
  }

  std::unique_ptr<boop::Monitor> monitor(boop::makeMonitor(parser.isSet("fixtures")));
  if (parser.isSet("list")) {
    if (parser.isSet("fixtures"))
      monitor->start();
    const auto snapshot = parser.isSet("fixtures") ? monitor->snapshot() : boop::readSysfs();
    const bool reliable = !snapshot.failed && snapshot.issue == boop::Issue::None;
    const boop::Status status{reliable ? boop::State::Monitoring : boop::State::Unavailable,
                              snapshot.issue};
    QJsonArray devices;
    for (const auto &device : snapshot.devices)
      devices.append(deviceJson(device));
    QTextStream output(stdout);
    if (parser.isSet("json")) {
      output << QJsonDocument(QJsonObject{{"devices", devices},
                                          {"status", boop::statusMessage(status)},
                                          {"reliable", reliable}})
                    .toJson(QJsonDocument::Indented);
    } else {
      for (const auto &device : snapshot.devices)
        output << device.name << "\t" << boop::speedLabel(device.speed) << "\t" << device.topology
               << '\n';
      if (!reliable)
        QTextStream(stderr) << boop::statusMessage(status) << '\n';
    }
    monitor->stop();
    return reliable ? 0 : 1;
  }

  QApplication::setWindowIcon(QIcon(QStringLiteral(":/icons/app.png")));
  boop::SingleInstance instance;
  const auto ownership = instance.acquire();
  if (ownership == boop::SingleInstance::Result::ActivatedExisting)
    return 0;
  if (ownership == boop::SingleInstance::Result::Failed) {
    QTextStream(stderr) << "Could not establish a single application instance.\n";
    return 1;
  }
  QSettings preferences;
  std::unique_ptr<boop::NotificationService> notifications(boop::makeNotificationService());
  boop::XdgAutostart autostart(stableExecutable());
  boop::AppModel model(monitor.get(), notifications.get(), &autostart, &preferences);
  boop::MainWindow window(&model, !parser.isSet("no-tray"));
  QObject::connect(&instance, &boop::SingleInstance::activationRequested, &window,
                   &boop::MainWindow::showWindow);
  monitor->start();
  if (!parser.isSet("background") || !window.usableTray())
    window.showWindow();
  if (parser.isSet("smoke-test"))
    QTimer::singleShot(1000, application.get(), &QCoreApplication::quit);
  const int result = application->exec();
  monitor->stop();
  notifications->cancelAll();
  return result;
}
