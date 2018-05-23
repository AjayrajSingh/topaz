// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "topaz/runtime/web_view/web_view_impl.h"

#include <fdio/io.h>
#include <hid/hid.h>
#include <hid/usages.h>
#include <lib/async/cpp/task.h>
#include <lib/async/default.h>
#include <zircon/pixelformat.h>
#include <zircon/syscalls.h>
#include <zircon/types.h>

#include "topaz/runtime/web_view/schema_org_context.h"

using namespace WebCore;

TouchTracker::TouchTracker(int x, int y)
    : start_x_(x), start_y_(y), last_x_(0), last_y_(0), is_drag_(false) {}

void TouchTracker::HandleEvent(const input::PointerEvent& pointer,
                               const fuchsia::ui::gfx::Metrics& metrics,
                               WebView& web_view) {
  const auto x = pointer.x * metrics.scale_x;
  const auto y = pointer.y * metrics.scale_y;
  const int kDragThreshhold = 50 * metrics.scale_x;
  auto delta_x = last_x_ - x;
  auto delta_y = last_y_ - y;
  auto distance_x = abs(start_x_ - x);
  auto distance_y = abs(start_y_ - y);
  last_y_ = y;
  last_x_ = x;

  if (distance_x > kDragThreshhold || distance_y > kDragThreshhold) {
    is_drag_ = true;
  }

  if (is_drag_) {
    switch (pointer.phase) {
      case input::PointerEventPhase::MOVE:
        web_view.scrollPixels(delta_x, delta_y);
        break;

      case input::PointerEventPhase::UP:
        web_view.scrollPixels(delta_x, delta_y);
        break;

      default:
        break;
    }
  } else {
    switch (pointer.phase) {
      case input::PointerEventPhase::UP:
        web_view.handleMouseEvent(start_x_, start_y_, WebView::kMouseDown);
        web_view.handleMouseEvent(start_x_, start_y_, WebView::kMouseUp);
        break;

      default:
        break;
    }
  }
}

WebViewImpl::WebViewImpl(
    views_v1::ViewManagerPtr view_manager,
    fidl::InterfaceRequest<views_v1_token::ViewOwner> view_owner_request,
    fidl::InterfaceRequest<component::ServiceProvider>
        outgoing_services_request,
    const std::string& url)
    : BaseView(std::move(view_manager), std::move(view_owner_request),
               "WebView"),
      weak_factory_(this),
      url_(url),
#ifdef EXPERIMENTAL_WEB_ENTITY_EXTRACTION
      schema_org_(web_view_),
#endif
      image_cycler_(session()) {
  FXL_LOG(INFO) << "WebViewImpl constructor";
  web_view_.setup_once();
  SetNeedSquareMetrics(true);
  parent_node().AddChild(image_cycler_);

  if (outgoing_services_request) {
    // Expose |WebView| interface to caller
    outgoing_services_.AddService<web_view::WebView>(
        [this](fidl::InterfaceRequest<web_view::WebView> request) {
          FXL_LOG(INFO) << "web view service request";
          web_view_interface_bindings_.AddBinding(this, std::move(request));
        });
    outgoing_services_.AddBinding(std::move(outgoing_services_request));
  }

  async::PostTask(async_get_default(),
      ([weak = weak_factory_.GetWeakPtr()]() {
        if (weak)
          weak->CallIdle();
      }));
}

WebViewImpl::~WebViewImpl() {}

// |WebView|:
void WebViewImpl::SetUrl(fidl::StringPtr url) {
  url_ = url;
  // Reset url_set_ so that the next OnDraw() knows to call
  // web_view_.setURL()
  url_set_ = false;
  InvalidateScene();
}

// |WebView|:
void WebViewImpl::ClearCookies() {
  web_view_.deleteAllCookies();
}

void WebViewImpl::SetWebRequestDelegate(
    ::fidl::InterfaceHandle<web_view::WebRequestDelegate> delegate) {
  webRequestDelegate_ = delegate.Bind();
}

bool WebViewImpl::HandleKeyboardEvent(const input::InputEvent& event) {
  bool handled = true;
  const input::KeyboardEvent& keyboard = event.keyboard();
  bool pressed = keyboard.phase == input::KeyboardEventPhase::PRESSED;
  bool repeating = keyboard.phase == input::KeyboardEventPhase::REPEAT;
  if (pressed && keyboard.code_point == 'c' &&
      keyboard.modifiers & input::kModifierControl) {
    exit(0);
  } else if (pressed && keyboard.code_point == '[' &&
             keyboard.modifiers & input::kModifierControl) {
    web_view_.goBack();
  } else if (pressed && keyboard.code_point == ']' &&
             keyboard.modifiers & input::kModifierControl) {
    web_view_.goForward();
  } else if (pressed && keyboard.code_point == 'r' &&
             keyboard.modifiers & input::kModifierControl) {
    web_view_.reload();
  } else {
    bool handled =
        web_view_.handleKeyEvent(keyboard.hid_usage, keyboard.code_point,
                                 pressed || repeating, repeating);
    if (!handled) {
      if (pressed || repeating) {
        if (keyboard.hid_usage == HID_USAGE_KEY_DOWN) {
        } else if (keyboard.hid_usage == HID_USAGE_KEY_UP) {
          web_view_.scrollUpOneLine();
        } else if (keyboard.hid_usage == HID_USAGE_KEY_RIGHT) {
          web_view_.scrollRightOneLine();
        } else if (keyboard.hid_usage == HID_USAGE_KEY_LEFT) {
          web_view_.scrollLeftOneLine();
        }
      }
    }
  }
  return handled;
}

bool WebViewImpl::HandleMouseEvent(const input::PointerEvent& pointer) {
  bool handled = false;
  if (pointer.buttons & input::kMousePrimaryButton) {
    switch (pointer.phase) {
      case input::PointerEventPhase::DOWN:
      case input::PointerEventPhase::MOVE:
        web_view_.handleMouseEvent(
            pointer.x * metrics().scale_x, pointer.y * metrics().scale_y,
            pointer.phase == input::PointerEventPhase::DOWN
                ? ::WebView::kMouseDown
                : ::WebView::kMouseMoved);
        handled = true;
        break;
      case input::PointerEventPhase::UP:
        web_view_.handleMouseEvent(pointer.x * metrics().scale_x,
                                   pointer.y * metrics().scale_y,
                                   ::WebView::kMouseUp);
        handled = true;
        break;
      default:
        break;
    }
  }
  return handled;
}

void WebViewImpl::HandleTouchDown(const input::PointerEvent& pointer) {
  const auto x = pointer.x * metrics().scale_x;
  const auto y = pointer.y * metrics().scale_y;
  touch_trackers_[pointer.pointer_id] = TouchTracker(x, y);
}

bool WebViewImpl::HandleTouchEvent(const input::PointerEvent& pointer) {
  bool handled = false;
  auto pointer_id = pointer.pointer_id;
  switch (pointer.phase) {
    case input::PointerEventPhase::DOWN:
      HandleTouchDown(pointer);
      handled = true;
      break;
    case input::PointerEventPhase::MOVE:
      touch_trackers_[pointer_id].HandleEvent(pointer, metrics(), web_view_);
      handled = true;
      break;
    case input::PointerEventPhase::UP:
      touch_trackers_[pointer_id].HandleEvent(pointer, metrics(), web_view_);
      touch_trackers_.erase(pointer_id);
      handled = true;
      break;
    default:
      break;
  }
  return handled;
}

// |BaseView|:
bool WebViewImpl::OnInputEvent(input::InputEvent event) {
  bool handled = false;
  web_view_.setFocused(true);
  web_view_.setVisible(true);
  if (event.is_pointer()) {
    const input::PointerEvent& pointer = event.pointer();
    if (pointer.type == input::PointerEventType::TOUCH) {
      handled = HandleTouchEvent(pointer);
    } else if (pointer.type == input::PointerEventType::MOUSE) {
      handled = HandleMouseEvent(pointer);
    }
  } else if (event.is_keyboard()) {
    handled = HandleKeyboardEvent(event);
  }

  InvalidateScene();
  return handled;
}

// |BaseView|:
void WebViewImpl::OnSceneInvalidated(
    fuchsia::images::PresentationInfo presentation_info) {
  if (!has_physical_size())
    return;

  // Update the image.
  const scenic_lib::HostImage* image = image_cycler_.AcquireImage(
      physical_size().width, physical_size().height, physical_size().width * 4u,
      fuchsia::images::PixelFormat::BGRA_8,
      fuchsia::images::ColorSpace::SRGB);
  FXL_DCHECK(image);

  // Paint the webview.
  web_view_.setup(reinterpret_cast<unsigned char*>(image->image_ptr()),
                  ZX_PIXEL_FORMAT_ARGB_8888, physical_size().width,
                  physical_size().height, physical_size().width * 4u);
  if (!url_set_) {
    const char* urlToOpen = url_.c_str();
    FXL_LOG(INFO) << "Loading " << urlToOpen;
    web_view_.setURL(urlToOpen);
    url_set_ = true;

    FXL_DCHECK(metrics().scale_x ==
               metrics().scale_y);  // we asked for square metrics

    auto requestCallback = [this](std::string url) {
      if (webRequestDelegate_) {
        webRequestDelegate_->WillSendRequest(url);
      }
      return url;
    };
    web_view_.setWebRequestDelegate(requestCallback);
  }

  if (page_scale_factor_ != metrics().scale_x) {
    page_scale_factor_ = metrics().scale_x;
    web_view_.setPageAndTextZoomFactors(page_scale_factor_, 1.0);
  }

  web_view_.iterateEventLoop();
  web_view_.layoutAndPaint();

  image_cycler_.ReleaseAndSwapImage();
  image_cycler_.SetScale(1.f / metrics().scale_x, 1.f / metrics().scale_y, 1.f);
  image_cycler_.SetTranslation(logical_size().width * .5f,
                               logical_size().height * .5f, 0.f);
}

void WebViewImpl::CallIdle() {
  web_view_.iterateEventLoop();
  InvalidateScene();
async::PostTask(async_get_default(),
      ([weak = weak_factory_.GetWeakPtr()]() {
        if (weak)
          weak->CallIdle();
      }));
}
