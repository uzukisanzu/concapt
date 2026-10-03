cmake_minimum_required(VERSION 3.14)

set(PROJECT_NAME "window_capture")
project(${PROJECT_NAME} LANGUAGES CXX)

set(PLUGIN_NAME "window_capture_plugin")

add_library(${PLUGIN_NAME} SHARED
  "window_capture_plugin_c_api.cpp"
  "window_capture_plugin.cpp"
)

# apply_standard_settings is skipped: it defines _HAS_EXCEPTIONS=0, and
# C++/WinRT reports failures as exceptions.
target_compile_features(${PLUGIN_NAME} PRIVATE cxx_std_20)
target_compile_options(${PLUGIN_NAME} PRIVATE /W4 /WX /EHsc /permissive- /bigobj)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL NOMINMAX)
set_target_properties(${PLUGIN_NAME} PROPERTIES CXX_VISIBILITY_PRESET hidden)

target_include_directories(${PLUGIN_NAME} INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin windowsapp)

set(window_capture_bundled_libraries "" PARENT_SCOPE)
