#include "flutter_window.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <cstdint>
#include <cstring>
#include <optional>
#include <vector>

#include "flutter/generated_plugin_registrant.h"

namespace {

using ClipboardBlock = std::unique_ptr<void, decltype(&GlobalFree)>;

ClipboardBlock MakeClipboardBlock(const std::vector<uint8_t>& bytes) {
  ClipboardBlock block(GlobalAlloc(GMEM_MOVEABLE, bytes.size()), GlobalFree);
  if (block) {
    if (void* data = GlobalLock(block.get())) {
      std::memcpy(data, bytes.data(), bytes.size());
      GlobalUnlock(block.get());
    } else {
      block.reset();
    }
  }
  return block;
}

bool CopyImage(HWND window, const std::vector<uint8_t>& png,
               const std::vector<uint8_t>& dib) {
  auto png_block = MakeClipboardBlock(png);
  auto dib_block = MakeClipboardBlock(dib);
  if (!png_block || !dib_block || !OpenClipboard(window)) {
    return false;
  }
  if (EmptyClipboard()) {
    const UINT png_format = RegisterClipboardFormatW(L"PNG");
    if (png_format && SetClipboardData(png_format, png_block.get())) {
      png_block.release();
    }
    if (SetClipboardData(CF_DIBV5, dib_block.get())) {
      dib_block.release();
    }
  }
  CloseClipboard();
  return !png_block || !dib_block;
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter::MethodChannel<flutter::EncodableValue> clipboard(
      flutter_controller_->engine()->messenger(), "federa/portapapeles",
      &flutter::StandardMethodCodec::GetInstance());
  clipboard.SetMethodCallHandler([this](const auto& call, auto result) {
    if (call.method_name() != "copiarImagen") {
      result->NotImplemented();
      return;
    }
    const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
    if (args) {
      const auto png = args->find(flutter::EncodableValue("png"));
      const auto dib = args->find(flutter::EncodableValue("dib"));
      if (png != args->end() && dib != args->end()) {
        const auto* png_bytes = std::get_if<std::vector<uint8_t>>(&png->second);
        const auto* dib_bytes = std::get_if<std::vector<uint8_t>>(&dib->second);
        if (png_bytes && !png_bytes->empty() && dib_bytes && !dib_bytes->empty() &&
            CopyImage(GetHandle(), *png_bytes, *dib_bytes)) {
          result->Success();
          return;
        }
      }
    }
    result->Error("portapapeles", "No se pudo copiar la imagen.");
  });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
