#include "window_capture_plugin.h"

// unknwn.h before C++/WinRT lets winrt::com_ptr hold classic COM interfaces.
#include <unknwn.h>

#include <flutter/standard_method_codec.h>

#include <winrt/base.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Globalization.h>
#include <winrt/Windows.Graphics.Imaging.h>
#include <winrt/Windows.Media.Ocr.h>
#include <winrt/Windows.Storage.h>
#include <winrt/Windows.Storage.Streams.h>

#include <algorithm>
#include <thread>

namespace window_capture {
namespace {

using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;

namespace imaging = winrt::Windows::Graphics::Imaging;
namespace ocr = winrt::Windows::Media::Ocr;
namespace storage = winrt::Windows::Storage;
namespace streams = winrt::Windows::Storage::Streams;

constexpr UINT kOcrDone = WM_APP + 0x43;

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

// Black where a pixel has the bonus pills' blue, white elsewhere.
imaging::SoftwareBitmap KeyBlue(const imaging::SoftwareBitmap& bitmap) {
  const auto width = static_cast<uint32_t>(bitmap.PixelWidth());
  const auto height = static_cast<uint32_t>(bitmap.PixelHeight());
  const uint32_t size = width * height * 4;
  streams::Buffer buffer(size);
  buffer.Length(size);
  bitmap.CopyToBuffer(buffer);
  uint8_t* pixels = buffer.data();
  for (uint32_t i = 0; i < size; i += 4) {
    const int blue = pixels[i];
    const int red = pixels[i + 2];
    const uint8_t value = blue > 150 && blue - red > 80 ? 0 : 255;
    pixels[i] = pixels[i + 1] = pixels[i + 2] = value;
    pixels[i + 3] = 255;
  }
  return imaging::SoftwareBitmap::CreateCopyFromBuffer(buffer, imaging::BitmapPixelFormat::Bgra8,
                                                       width, height,
                                                       imaging::BitmapAlphaMode::Premultiplied);
}

// Images over the engine's size limit are scaled down to fit. The blue read
// enlarges every image to the limit, since the bonus text is small. Boxes
// come back in the image's own pixels either way.
EncodableList ReadWords(const ocr::OcrEngine& engine, const std::wstring& path, bool blue_only) {
  const auto file = storage::StorageFile::GetFileFromPathAsync(path).get();
  const auto stream = file.OpenAsync(storage::FileAccessMode::Read).get();
  const auto decoder = imaging::BitmapDecoder::CreateAsync(stream).get();

  const uint32_t limit = ocr::OcrEngine::MaxImageDimension();
  const uint32_t longest = std::max(decoder.PixelWidth(), decoder.PixelHeight());
  const double scale =
      blue_only || longest > limit ? static_cast<double>(limit) / longest : 1.0;
  imaging::BitmapTransform transform;
  transform.ScaledWidth(static_cast<uint32_t>(decoder.PixelWidth() * scale));
  transform.ScaledHeight(static_cast<uint32_t>(decoder.PixelHeight() * scale));
  transform.InterpolationMode(imaging::BitmapInterpolationMode::Fant);

  const auto bitmap = decoder
                          .GetSoftwareBitmapAsync(imaging::BitmapPixelFormat::Bgra8,
                                                  imaging::BitmapAlphaMode::Premultiplied,
                                                  transform,
                                                  imaging::ExifOrientationMode::IgnoreExifOrientation,
                                                  imaging::ColorManagementMode::DoNotColorManage)
                          .get();
  const auto result = engine.RecognizeAsync(blue_only ? KeyBlue(bitmap) : bitmap).get();

  EncodableList words;
  for (const auto& line : result.Lines()) {
    for (const auto& word : line.Words()) {
      const auto box = word.BoundingRect();
      words.push_back(EncodableValue(EncodableMap{
          {EncodableValue("text"), EncodableValue(Utf8(word.Text()))},
          {EncodableValue("l"), EncodableValue(box.X / scale)},
          {EncodableValue("t"), EncodableValue(box.Y / scale)},
          {EncodableValue("r"), EncodableValue((box.X + box.Width) / scale)},
          {EncodableValue("b"), EncodableValue((box.Y + box.Height) / scale)},
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
  methods_ = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      registrar->messenger(), "concapt/window_capture",
      &flutter::StandardMethodCodec::GetInstance());
  methods_->SetMethodCallHandler(
      [this](const auto& call, auto result) { HandleMethodCall(call, std::move(result)); });

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
  if (method == "recognize") {
    const auto* path = std::get_if<std::string>(Arg(call, "path"));
    if (!path) return result->Error("bad_args", "path is required");
    const auto* blue_only = std::get_if<bool>(Arg(call, "blueOnly"));
    Recognize(Wide(*path), blue_only && *blue_only, std::move(result));
  } else if (method == "ocrAvailable") {
    result->Success(EncodableValue(static_cast<bool>(CreateEngine())));
  } else {
    result->NotImplemented();
  }
}

std::optional<LRESULT> WindowCapturePlugin::HandleWindowMessage(UINT message, WPARAM wparam) {
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

void WindowCapturePlugin::Recognize(std::wstring path, bool blue_only, Result result) {
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
  std::thread([this, id, blue_only, root = RootWindow(), path = std::move(path)] {
    winrt::init_apartment(winrt::apartment_type::multi_threaded);
    EncodableList words;
    std::string error_code;
    std::string error_message;
    try {
      if (const auto engine = CreateEngine()) {
        words = ReadWords(engine, path, blue_only);
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
