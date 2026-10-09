#pragma once
#include <QLocalServer>
#include <QLockFile>
#include <QObject>
#include <memory>
namespace boop {
class SingleInstance : public QObject {
  Q_OBJECT
public:
  enum class Result { Primary, ActivatedExisting, Failed };
  explicit SingleInstance(QObject *parent = nullptr);
  Result acquire();
signals:
  void activationRequested();

private:
  QLocalServer server_;
  std::unique_ptr<QLockFile> lock_;
};
} // namespace boop
