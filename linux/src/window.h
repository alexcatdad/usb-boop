#pragma once
#include "app.h"
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

private:
  AppModel *model_;
  QSystemTrayIcon *tray_;
  QLabel *status_;
  QVBoxLayout *content_;
  QDialog *settings_ = nullptr;
  void render();
};
} // namespace boop
