#pragma once
#include "app.h"
#include <QDBusVariant>
#include <QMainWindow>
#include <QSystemTrayIcon>
class QVBoxLayout;
class QLabel;
class QDialog;
namespace boop {
class MainWindow : public QMainWindow {
  Q_OBJECT
public:
  explicit MainWindow(AppModel *model, bool trayEnabled = true, QWidget *parent = nullptr);
  void showWindow();
  void showSettings();
  bool usableTray() const;

protected:
  void closeEvent(QCloseEvent *event) override;
  void changeEvent(QEvent *event) override;

private slots:
  void appearanceChanged(const QString &group, const QString &key, const QDBusVariant &value);

private:
  AppModel *model_;
  QSystemTrayIcon *tray_;
  QLabel *status_;
  QVBoxLayout *content_;
  QDialog *settings_ = nullptr;
  uint appearancePreference_ = 0;
  quint64 appearanceRevision_ = 0;
  void readAppearance();
  void updateTrayIcon();
  void render();
};
} // namespace boop
