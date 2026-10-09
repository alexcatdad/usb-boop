add_executable(backend_tests backend_tests.cpp)
target_link_libraries(backend_tests PRIVATE boop_backend Qt6::Test)
add_test(NAME backend_tests COMMAND backend_tests)
