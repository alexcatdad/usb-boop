add_library(boop_backend STATIC
  domain.cpp sysfs.cpp reconciliation.cpp reconciliation.h udev_monitor.cpp monitor.h domain.h)
target_include_directories(boop_backend PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
target_link_libraries(boop_backend PUBLIC Qt6::Core PkgConfig::UDEV)
