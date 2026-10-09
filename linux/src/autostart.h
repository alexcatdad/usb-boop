#pragma once
#include <QObject>
#include <QString>
namespace boop {
class AutostartService : public QObject {
  Q_OBJECT
public:
  using QObject::QObject;
  virtual bool enabled() const = 0;
  virtual bool setEnabled(bool value) = 0;
  virtual QString error() const = 0;
};
class XdgAutostart final : public AutostartService {
public:
  explicit XdgAutostart(QString executable, QString configDirectory = {},
                        QObject *parent = nullptr);
  bool enabled() const override;
  bool setEnabled(bool value) override;
  QString error() const override { return error_; }

private:
  QString executable_, path_, error_;
};
} // namespace boop
