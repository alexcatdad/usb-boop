add_library(boop_desktop app.cpp app.h notifications.cpp notifications.h autostart.cpp autostart.h window.cpp window.h instance.cpp instance.h)
target_link_libraries(boop_desktop PUBLIC boop_backend Qt6::Widgets Qt6::DBus Qt6::Network)
target_include_directories(boop_desktop PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
