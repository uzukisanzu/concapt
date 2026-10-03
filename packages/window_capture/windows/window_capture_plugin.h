#ifndef FLUTTER_PLUGIN_WINDOW_CAPTURE_PLUGIN_H_
#define FLUTTER_PLUGIN_WINDOW_CAPTURE_PLUGIN_H_

#include <windows.h>

#include <flutter/encodable_value.h>
#include <flutter/event_channel.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <map>
#include <memory>
#include <mutex>
#include <optional>
#include <string>

namespace window_capture {

class WindowCapturePlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  explicit WindowCapturePlugin(flutter::PluginRegistrarWindows* registrar);
  ~WindowCapturePlugin() override;

  WindowCapturePlugin(const WindowCapturePlugin&) = delete;
  WindowCapturePlugin& operator=(const WindowCapturePlugin&) = delete;

 private:
  using Result = std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>;

  // An OCR read running on a worker thread.
  struct OcrJob {
    Result result;
    flutter::EncodableList words;
    std::string error_code;  // Empty on success.
    std::string error_message;
  };

  void HandleMethodCall(const flutter::MethodCall<flutter::EncodableValue>& call, Result result);
  std::optional<LRESULT> HandleWindowMessage(UINT message, WPARAM wparam);

  // The runner's top-level window, which owns the hotkey, flashing, and z-order.
  HWND RootWindow() const;

  void Recognize(std::wstring path, Result result);

  flutter::PluginRegistrarWindows* registrar_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> methods_;
  std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>> hotkey_channel_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> hotkey_sink_;
  int window_proc_id_ = -1;

  std::mutex jobs_mutex_;
  std::map<WPARAM, OcrJob> jobs_;
  WPARAM next_job_ = 0;
};

}  // namespace window_capture

#endif  // FLUTTER_PLUGIN_WINDOW_CAPTURE_PLUGIN_H_
