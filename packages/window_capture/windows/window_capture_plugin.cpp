#include "window_capture_plugin.h"

// unknwn.h before C++/WinRT lets winrt::com_ptr hold classic COM interfaces.
#include <unknwn.h>

#include <d3d11.h>
#include <dwmapi.h>
#include <dxgi.h>
#include <inspectable.h>
#include <wincodec.h>
#include <windows.graphics.capture.interop.h>
#include <windows.graphics.directx.direct3d11.interop.h>

#include <flutter/event_stream_handler_functions.h>
#include <flutter/standard_method_codec.h>

#include <winrt/base.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Globalization.h>
#include <winrt/Windows.Graphics.Capture.h>
#include <winrt/Windows.Graphics.DirectX.h>
#include <winrt/Windows.Graphics.DirectX.Direct3D11.h>
#include <winrt/Windows.Graphics.Imaging.h>
#include <winrt/Windows.Media.Ocr.h>
#include <winrt/Windows.Storage.h>
#include <winrt/Windows.Storage.Streams.h>

#include <algorithm>
#include <thread>
#include <vector>

namespace window_capture {
namespace {

using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;

namespace capture = winrt::Windows::Graphics::Capture;
namespace d3d = winrt::Windows::Graphics::DirectX::Direct3D11;
namespace imaging = winrt::Windows::Graphics::Imaging;
namespace ocr = winrt::Windows::Media::Ocr;
namespace storage = winrt::Windows::Storage;

constexpr UINT kOcrDone = WM_APP + 0x43;

// Longest side of the image OCR reads. Taller frames lose whole member rows.
constexpr uint32_t kReadLongest = 1300;
constexpr int kHotkeyId = 1;

// A side-button hotkey. The low-level hook takes no context, so its state
// lives here; the hook runs on the platform thread that installed it.
struct MouseHotkey {
  HHOOK hook = nullptr;
  HWND root = nullptr;
  HWND target = nullptr;  // Where the button captures; null for nowhere.
  WORD button = 0;        // XBUTTON1 or XBUTTON2.
  bool held = false;      // The down was swallowed, so the up is too.
};
MouseHotkey g_mouse;

// Swallows the button while the target is in front and posts the press as a
// WM_HOTKEY. Windows drops hooks that run long, so it does nothing more.
LRESULT CALLBACK MouseHook(int code, WPARAM message, LPARAM lparam) {
  if (code == HC_ACTION && (message == WM_XBUTTONDOWN || message == WM_XBUTTONUP)) {
    const auto* info = reinterpret_cast<const MSLLHOOKSTRUCT*>(lparam);
    if (HIWORD(info->mouseData) == g_mouse.button) {
      if (message == WM_XBUTTONDOWN && g_mouse.target &&
          GetForegroundWindow() == g_mouse.target) {
        g_mouse.held = true;
        PostMessageW(g_mouse.root, WM_HOTKEY, kHotkeyId, 0);
        return 1;
      }
      if (message == WM_XBUTTONUP && g_mouse.held) {
        g_mouse.held = false;
        return 1;
      }
    }
  }
  return CallNextHookEx(nullptr, code, message, lparam);
}

void UnbindHotkey(HWND root) {
  UnregisterHotKey(root, kHotkeyId);
  if (g_mouse.hook) UnhookWindowsHookEx(g_mouse.hook);
  g_mouse.hook = nullptr;
  g_mouse.held = false;
}

bool BindMouseHotkey(HWND root, WORD button) {
  HMODULE module = nullptr;
  GetModuleHandleExW(
      GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
      reinterpret_cast<LPCWSTR>(&MouseHook), &module);
  g_mouse.root = root;
  g_mouse.button = button;
  g_mouse.hook = SetWindowsHookExW(WH_MOUSE_LL, MouseHook, module, 0);
  return g_mouse.hook != nullptr;
}

const EncodableValue* Arg(const flutter::MethodCall<EncodableValue>& call, const char* key) {
  const auto* args = std::get_if<EncodableMap>(call.arguments());
  if (!args) return nullptr;
  const auto it = args->find(EncodableValue(key));
  return it == args->end() ? nullptr : &it->second;
}

std::wstring Wide(const std::string& utf8) { return std::wstring(winrt::to_hstring(utf8)); }

std::string Utf8(std::wstring_view wide) { return winrt::to_string(wide); }

// StorageFile takes only absolute paths with backslashes and no `.` or `..`.
std::wstring FullPath(const std::wstring& path) {
  const DWORD size = GetFullPathNameW(path.c_str(), 0, nullptr, nullptr);
  std::wstring full(size, L'\0');
  full.resize(GetFullPathNameW(path.c_str(), size, full.data(), nullptr));
  return full;
}

std::string ProcessName(HWND hwnd) {
  DWORD pid = 0;
  GetWindowThreadProcessId(hwnd, &pid);
  const HANDLE process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
  if (!process) return "";
  wchar_t path[MAX_PATH];
  DWORD size = MAX_PATH;
  std::wstring name;
  if (QueryFullProcessImageNameW(process, 0, path, &size)) {
    name.assign(path, size);
    name = name.substr(name.find_last_of(L'\\') + 1);
  }
  CloseHandle(process);
  return Utf8(name);
}

struct WindowList {
  HWND self;
  EncodableList windows;
};

BOOL CALLBACK AddWindow(HWND hwnd, LPARAM param) {
  auto* list = reinterpret_cast<WindowList*>(param);
  if (hwnd == list->self || !IsWindowVisible(hwnd)) return TRUE;
  if (GetWindowLongW(hwnd, GWL_EXSTYLE) & WS_EX_TOOLWINDOW) return TRUE;
  BOOL cloaked = FALSE;
  DwmGetWindowAttribute(hwnd, DWMWA_CLOAKED, &cloaked, sizeof(cloaked));
  if (cloaked) return TRUE;
  const int length = GetWindowTextLengthW(hwnd);
  if (length == 0) return TRUE;
  std::wstring title(static_cast<size_t>(length) + 1, L'\0');
  title.resize(static_cast<size_t>(GetWindowTextW(hwnd, title.data(), length + 1)));
  list->windows.push_back(EncodableValue(EncodableMap{
      {EncodableValue("handle"),
       EncodableValue(static_cast<int64_t>(reinterpret_cast<intptr_t>(hwnd)))},
      {EncodableValue("title"), EncodableValue(Utf8(title))},
      {EncodableValue("process"), EncodableValue(ProcessName(hwnd))},
      {EncodableValue("minimized"), EncodableValue(IsIconic(hwnd) != 0)},
  }));
  return TRUE;
}

EncodableList ListWindows(HWND self) {
  WindowList list{self, {}};
  EnumWindows(AddWindow, reinterpret_cast<LPARAM>(&list));
  return std::move(list.windows);
}

// The client area inside a WGC frame, which covers the window's visible
// frame bounds. All rects are in physical pixels; the runner is per-monitor
// DPI aware.
RECT ClientCrop(HWND hwnd, UINT frame_width, UINT frame_height) {
  RECT bounds{};
  DwmGetWindowAttribute(hwnd, DWMWA_EXTENDED_FRAME_BOUNDS, &bounds, sizeof(bounds));
  RECT client{};
  GetClientRect(hwnd, &client);
  POINT origin{0, 0};
  ClientToScreen(hwnd, &origin);
  const LONG width = static_cast<LONG>(frame_width);
  const LONG height = static_cast<LONG>(frame_height);
  const LONG left = std::clamp<LONG>(origin.x - bounds.left, 0, width);
  const LONG top = std::clamp<LONG>(origin.y - bounds.top, 0, height);
  return {left, top, std::min(left + client.right, width), std::min(top + client.bottom, height)};
}

void WritePng(const std::wstring& path, std::vector<BYTE>& pixels, UINT width, UINT height) {
  const auto factory = winrt::create_instance<IWICImagingFactory>(CLSID_WICImagingFactory);
  winrt::com_ptr<IWICStream> stream;
  winrt::check_hresult(factory->CreateStream(stream.put()));
  winrt::check_hresult(stream->InitializeFromFilename(path.c_str(), GENERIC_WRITE));
  winrt::com_ptr<IWICBitmapEncoder> encoder;
  winrt::check_hresult(factory->CreateEncoder(GUID_ContainerFormatPng, nullptr, encoder.put()));
  winrt::check_hresult(encoder->Initialize(stream.get(), WICBitmapEncoderNoCache));
  winrt::com_ptr<IWICBitmapFrameEncode> frame;
  winrt::check_hresult(encoder->CreateNewFrame(frame.put(), nullptr));
  winrt::check_hresult(frame->Initialize(nullptr));
  winrt::check_hresult(frame->SetSize(width, height));
  WICPixelFormatGUID format = GUID_WICPixelFormat32bppBGRA;
  winrt::check_hresult(frame->SetPixelFormat(&format));
  winrt::check_hresult(
      frame->WritePixels(height, width * 4, static_cast<UINT>(pixels.size()), pixels.data()));
  winrt::check_hresult(frame->Commit());
  winrt::check_hresult(encoder->Commit());
}

// Grabs one frame of [hwnd] with Windows Graphics Capture, crops it to the
// client area, and saves it as a PNG. Returns a channel error code, or an
// empty string on success.
std::string CaptureWindow(HWND hwnd, const std::wstring& path) {
  if (!IsWindow(hwnd)) return "closed";
  if (IsIconic(hwnd)) return "minimized";

  winrt::com_ptr<ID3D11Device> device;
  winrt::com_ptr<ID3D11DeviceContext> context;
  winrt::check_hresult(D3D11CreateDevice(nullptr, D3D_DRIVER_TYPE_HARDWARE, nullptr,
                                         D3D11_CREATE_DEVICE_BGRA_SUPPORT, nullptr, 0,
                                         D3D11_SDK_VERSION, device.put(), nullptr, context.put()));
  winrt::com_ptr<::IInspectable> inspectable;
  winrt::check_hresult(
      CreateDirect3D11DeviceFromDXGIDevice(device.as<IDXGIDevice>().get(), inspectable.put()));
  const auto capture_device = inspectable.as<d3d::IDirect3DDevice>();

  capture::GraphicsCaptureItem item{nullptr};
  const auto interop =
      winrt::get_activation_factory<capture::GraphicsCaptureItem, IGraphicsCaptureItemInterop>();
  winrt::check_hresult(interop->CreateForWindow(
      hwnd, winrt::guid_of<capture::GraphicsCaptureItem>(), winrt::put_abi(item)));

  const auto pool = capture::Direct3D11CaptureFramePool::CreateFreeThreaded(
      capture_device, winrt::Windows::Graphics::DirectX::DirectXPixelFormat::B8G8R8A8UIntNormalized,
      1, item.Size());
  const auto session = pool.CreateCaptureSession(item);
  session.IsCursorCaptureEnabled(false);
  try {
    session.IsBorderRequired(false);
  } catch (const winrt::hresult_error&) {
    // Windows 10 always draws the capture border.
  }

  winrt::handle arrived{CreateEventW(nullptr, TRUE, FALSE, nullptr)};
  const auto token =
      pool.FrameArrived([&arrived](const auto&, const auto&) { SetEvent(arrived.get()); });
  session.StartCapture();
  capture::Direct3D11CaptureFrame frame{nullptr};
  if (WaitForSingleObject(arrived.get(), 1000) == WAIT_OBJECT_0) frame = pool.TryGetNextFrame();
  pool.FrameArrived(token);
  session.Close();
  pool.Close();
  if (!frame) return "no_frame";

  winrt::com_ptr<ID3D11Texture2D> texture;
  const auto access = frame.Surface()
                          .as<::Windows::Graphics::DirectX::Direct3D11::IDirect3DDxgiInterfaceAccess>();
  winrt::check_hresult(access->GetInterface(winrt::guid_of<ID3D11Texture2D>(), texture.put_void()));
  D3D11_TEXTURE2D_DESC desc{};
  texture->GetDesc(&desc);

  const RECT crop = ClientCrop(hwnd, desc.Width, desc.Height);
  const UINT width = static_cast<UINT>(crop.right - crop.left);
  const UINT height = static_cast<UINT>(crop.bottom - crop.top);
  if (width == 0 || height == 0) return "no_frame";

  desc.Usage = D3D11_USAGE_STAGING;
  desc.BindFlags = 0;
  desc.CPUAccessFlags = D3D11_CPU_ACCESS_READ;
  desc.MiscFlags = 0;
  winrt::com_ptr<ID3D11Texture2D> staging;
  winrt::check_hresult(device->CreateTexture2D(&desc, nullptr, staging.put()));
  context->CopyResource(staging.get(), texture.get());
  D3D11_MAPPED_SUBRESOURCE mapped{};
  winrt::check_hresult(context->Map(staging.get(), 0, D3D11_MAP_READ, 0, &mapped));

  // Opaque rows: WGC leaves alpha undefined for some windows.
  const size_t row_bytes = static_cast<size_t>(width) * 4;
  const size_t left = static_cast<size_t>(crop.left);
  const size_t top = static_cast<size_t>(crop.top);
  std::vector<BYTE> pixels(row_bytes * height);
  for (size_t y = 0; y < height; ++y) {
    const auto* row = static_cast<const BYTE*>(mapped.pData) + (top + y) * mapped.RowPitch + left * 4;
    auto* out = pixels.data() + y * row_bytes;
    std::copy(row, row + row_bytes, out);
    for (size_t x = 3; x < row_bytes; x += 4) out[x] = 255;
  }
  context->Unmap(staging.get(), 0);

  WritePng(path, pixels, width, height);
  return "";
}

// en-US first, then any installed Latin-script language.
ocr::OcrEngine CreateEngine() {
  if (auto engine = ocr::OcrEngine::TryCreateFromLanguage(
          winrt::Windows::Globalization::Language(L"en-US"))) {
    return engine;
  }
  for (const auto& language : ocr::OcrEngine::AvailableRecognizerLanguages()) {
    if (language.Script() == L"Latn") return ocr::OcrEngine::TryCreateFromLanguage(language);
  }
  return nullptr;
}

// Reads the whole frame, shrinking tall ones to kReadLongest, or just [region]
// enlarged by its scale. Boxes come back in the image's own pixels.
EncodableList ReadWords(const ocr::OcrEngine& engine, const std::wstring& path,
                        const std::optional<ReadRegion>& region) {
  const auto file = storage::StorageFile::GetFileFromPathAsync(path).get();
  const auto stream = file.OpenAsync(storage::FileAccessMode::Read).get();
  const auto decoder = imaging::BitmapDecoder::CreateAsync(stream).get();

  const uint32_t longest = std::max(decoder.PixelWidth(), decoder.PixelHeight());
  // OCR reads past MaxImageDimension come back as junk, so a region's
  // enlargement stops where its longest side reaches it.
  const double scale =
      region ? std::min(region->scale,
                        ocr::OcrEngine::MaxImageDimension() /
                            std::max(region->right - region->left, region->bottom - region->top))
             : std::min(1.0, static_cast<double>(kReadLongest) / longest);
  const auto width = static_cast<uint32_t>(decoder.PixelWidth() * scale);
  const auto height = static_cast<uint32_t>(decoder.PixelHeight() * scale);
  imaging::BitmapTransform transform;
  transform.ScaledWidth(width);
  transform.ScaledHeight(height);

  // Fant blurs when enlarging.
  transform.InterpolationMode(scale > 1 ? imaging::BitmapInterpolationMode::Cubic
                                        : imaging::BitmapInterpolationMode::Fant);

  // Bounds apply after scaling.
  imaging::BitmapBounds bounds{0, 0, width, height};
  if (region) {
    const auto at = [scale](double v, uint32_t limit) {
      return static_cast<uint32_t>(std::clamp(v * scale, 0.0, static_cast<double>(limit)));
    };
    bounds.X = at(region->left, width);
    bounds.Y = at(region->top, height);
    bounds.Width = at(region->right, width) - bounds.X;
    bounds.Height = at(region->bottom, height) - bounds.Y;
    if (bounds.Width == 0 || bounds.Height == 0) return {};
    transform.Bounds(bounds);
  }

  const auto bitmap = decoder
                          .GetSoftwareBitmapAsync(imaging::BitmapPixelFormat::Bgra8,
                                                  imaging::BitmapAlphaMode::Premultiplied,
                                                  transform,
                                                  imaging::ExifOrientationMode::IgnoreExifOrientation,
                                                  imaging::ColorManagementMode::DoNotColorManage)
                          .get();
  const auto result = engine.RecognizeAsync(bitmap).get();

  EncodableList words;
  for (const auto& line : result.Lines()) {
    for (const auto& word : line.Words()) {
      const auto box = word.BoundingRect();
      words.push_back(EncodableValue(EncodableMap{
          {EncodableValue("text"), EncodableValue(Utf8(word.Text()))},
          {EncodableValue("l"), EncodableValue((bounds.X + box.X) / scale)},
          {EncodableValue("t"), EncodableValue((bounds.Y + box.Y) / scale)},
          {EncodableValue("r"), EncodableValue((bounds.X + box.X + box.Width) / scale)},
          {EncodableValue("b"), EncodableValue((bounds.Y + box.Y + box.Height) / scale)},
      }));
    }
  }
  return words;
}

}  // namespace

void WindowCapturePlugin::RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar) {
  registrar->AddPlugin(std::make_unique<WindowCapturePlugin>(registrar));
}

WindowCapturePlugin::WindowCapturePlugin(flutter::PluginRegistrarWindows* registrar)
    : registrar_(registrar) {
  const auto* codec = &flutter::StandardMethodCodec::GetInstance();
  methods_ = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      registrar->messenger(), "concapt/window_capture", codec);
  methods_->SetMethodCallHandler(
      [this](const auto& call, auto result) { HandleMethodCall(call, std::move(result)); });

  hotkey_channel_ = std::make_unique<flutter::EventChannel<EncodableValue>>(
      registrar->messenger(), "concapt/window_capture/hotkey", codec);
  hotkey_channel_->SetStreamHandler(
      std::make_unique<flutter::StreamHandlerFunctions<EncodableValue>>(
          [this](const EncodableValue*, std::unique_ptr<flutter::EventSink<EncodableValue>>&& events)
              -> std::unique_ptr<flutter::StreamHandlerError<EncodableValue>> {
            hotkey_sink_ = std::move(events);
            return nullptr;
          },
          [this](const EncodableValue*)
              -> std::unique_ptr<flutter::StreamHandlerError<EncodableValue>> {
            hotkey_sink_.reset();
            return nullptr;
          }));

  window_proc_id_ = registrar->RegisterTopLevelWindowProcDelegate(
      [this](HWND, UINT message, WPARAM wparam, LPARAM) {
        return HandleWindowMessage(message, wparam);
      });
}

WindowCapturePlugin::~WindowCapturePlugin() {
  registrar_->UnregisterTopLevelWindowProcDelegate(window_proc_id_);
}

HWND WindowCapturePlugin::RootWindow() const {
  return GetAncestor(registrar_->GetView()->GetNativeWindow(), GA_ROOT);
}

void WindowCapturePlugin::HandleMethodCall(const flutter::MethodCall<EncodableValue>& call,
                                           Result result) {
  const auto& method = call.method_name();
  if (method == "listWindows") {
    result->Success(EncodableValue(ListWindows(RootWindow())));
  } else if (method == "captureWindow") {
    const auto* handle = Arg(call, "handle");
    const auto* path = std::get_if<std::string>(Arg(call, "path"));
    if (!handle || !path) return result->Error("bad_args", "handle and path are required");
    try {
      const auto hwnd = reinterpret_cast<HWND>(static_cast<intptr_t>(handle->LongValue()));
      const auto error = CaptureWindow(hwnd, FullPath(Wide(*path)));
      if (error.empty()) {
        result->Success();
      } else {
        result->Error(error);
      }
    } catch (const winrt::hresult_error& e) {
      result->Error("capture_failed", Utf8(e.message()));
    }
  } else if (method == "recognize") {
    const auto* path = std::get_if<std::string>(Arg(call, "path"));
    if (!path) return result->Error("bad_args", "path is required");
    std::optional<ReadRegion> region;
    if (const auto* bounds = std::get_if<EncodableList>(Arg(call, "region"))) {
      const auto* scale = std::get_if<double>(Arg(call, "scale"));
      if (bounds->size() != 4 || !scale) return result->Error("bad_args", "region needs 4 edges and a scale");
      double edges[4];
      for (size_t i = 0; i < 4; ++i) {
        const auto* edge = std::get_if<double>(&(*bounds)[i]);
        if (!edge) return result->Error("bad_args", "region edges must be doubles");
        edges[i] = *edge;
      }
      region = ReadRegion{edges[0], edges[1], edges[2], edges[3], *scale};
    }
    Recognize(Wide(*path), region, std::move(result));
  } else if (method == "ocrAvailable") {
    result->Success(EncodableValue(static_cast<bool>(CreateEngine())));
  } else if (method == "registerHotkey") {
    const auto* key = Arg(call, "key");
    const auto* modifiers = Arg(call, "modifiers");
    if (!key || !modifiers) return result->Error("bad_args", "key and modifiers are required");
    UnbindHotkey(RootWindow());
    const auto virtual_key = static_cast<UINT>(key->LongValue());
    bool bound;
    if (virtual_key == VK_XBUTTON1 || virtual_key == VK_XBUTTON2) {
      bound = BindMouseHotkey(RootWindow(), virtual_key == VK_XBUTTON1 ? XBUTTON1 : XBUTTON2);
    } else {
      bound = RegisterHotKey(RootWindow(), kHotkeyId,
                             static_cast<UINT>(modifiers->LongValue()) | MOD_NOREPEAT,
                             virtual_key) != 0;
    }
    result->Success(EncodableValue(bound));
  } else if (method == "setHotkeyWindow") {
    const auto* handle = Arg(call, "handle");
    g_mouse.target = handle && !handle->IsNull()
                         ? reinterpret_cast<HWND>(static_cast<intptr_t>(handle->LongValue()))
                         : nullptr;
    result->Success();
  } else if (method == "unregisterHotkey") {
    UnbindHotkey(RootWindow());
    result->Success();
  } else if (method == "flashWindow") {
    FLASHWINFO info{sizeof(info), RootWindow(), FLASHW_TRAY | FLASHW_TIMERNOFG, 0, 0};
    FlashWindowEx(&info);
    result->Success();
  } else if (method == "setAlwaysOnTop") {
    const auto* on_top = std::get_if<bool>(Arg(call, "onTop"));
    if (!on_top) return result->Error("bad_args", "onTop is required");
    SetWindowPos(RootWindow(), *on_top ? HWND_TOPMOST : HWND_NOTOPMOST, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
    result->Success();
  } else {
    result->NotImplemented();
  }
}

std::optional<LRESULT> WindowCapturePlugin::HandleWindowMessage(UINT message, WPARAM wparam) {
  if (message == WM_HOTKEY && wparam == static_cast<WPARAM>(kHotkeyId)) {
    if (hotkey_sink_) hotkey_sink_->Success();
    return 0;
  }
  if (message != kOcrDone) return std::nullopt;
  OcrJob job;
  {
    std::lock_guard lock(jobs_mutex_);
    job = std::move(jobs_.extract(wparam).mapped());
  }
  if (job.error_code.empty()) {
    job.result->Success(EncodableValue(std::move(job.words)));
  } else {
    job.result->Error(job.error_code, job.error_message);
  }
  return 0;
}

void WindowCapturePlugin::Recognize(std::wstring path, std::optional<ReadRegion> region,
                                    Result result) {
  path = FullPath(path);
  WPARAM id;
  {
    std::lock_guard lock(jobs_mutex_);
    id = next_job_++;
    jobs_[id].result = std::move(result);
  }
  // WinRT async calls can't block the platform thread, which is single-threaded
  // COM. The worker posts back to the window so the reply leaves from the
  // platform thread.
  std::thread([this, id, region, root = RootWindow(), path = std::move(path)] {
    winrt::init_apartment(winrt::apartment_type::multi_threaded);
    EncodableList words;
    std::string error_code;
    std::string error_message;
    try {
      if (const auto engine = CreateEngine()) {
        words = ReadWords(engine, path, region);
      } else {
        error_code = "no_language";
      }
    } catch (const winrt::hresult_error& e) {
      error_code = "read_failed";
      error_message = Utf8(e.message());
    }
    {
      std::lock_guard lock(jobs_mutex_);
      auto& job = jobs_[id];
      job.words = std::move(words);
      job.error_code = std::move(error_code);
      job.error_message = std::move(error_message);
    }
    winrt::uninit_apartment();
    PostMessageW(root, kOcrDone, id, 0);
  }).detach();
}

}  // namespace window_capture
