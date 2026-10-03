#include "include/window_capture/window_capture_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "window_capture_plugin.h"

void WindowCapturePluginCApiRegisterWithRegistrar(FlutterDesktopPluginRegistrarRef registrar) {
  window_capture::WindowCapturePlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
