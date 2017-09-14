/*
 * Copyright 2016 The Fuchsia Authors. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1.  Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer.
 * 2.  Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#include <algorithm>
#include <chrono>
#include <iostream>
#include <map>

#include <fcntl.h>
#include <math.h>

#include <assert.h>
#include <dirent.h>
#include <hid/hid.h>
#include <hid/usages.h>
#include <zircon/device/console.h>
#include <zircon/device/display.h>
#include <zircon/pixelformat.h>
#include <zircon/syscalls.h>
#include <zircon/types.h>
#include <fdio/io.h>
#include <stdlib.h>

#include "WebView.h"

#include "apps/modular/lib/rapidjson/rapidjson.h"
#include "apps/modular/services/lifecycle/lifecycle.fidl.h"
#include "apps/modular/services/module/module.fidl.h"
#include "apps/modular/services/story/link.fidl.h"
#include "lib/ui/scenic/client/host_image_cycler.h"
#include "lib/ui/view_framework/base_view.h"
#include "lib/ui/view_framework/view_provider_app.h"
#include "apps/web_runner/services/web_view.fidl.h"
#include "lib/fxl/command_line.h"
#include "lib/fxl/logging.h"
#include "lib/fxl/macros.h"
#include "lib/fxl/memory/weak_ptr.h"
#include "lib/icu_data/cpp/icu_data.h"
#include "lib/fsl/tasks/message_loop.h"

using namespace WebCore;

using std::cerr;
using std::cout;
using std::endl;

namespace {
constexpr char kDefaultUrl[] = "http://www.google.com/";
}  // namespace

class TouchTracker {
 public:
  TouchTracker(int x = 0, int y = 0)
      : start_x_(x), start_y_(y), last_x_(0), last_y_(0), is_drag_(false) {}

  void HandleEvent(const mozart::PointerEventPtr& pointer,
                   const scenic::Metrics& metrics,
                   WebView& web_view) {
    const auto x = pointer->x * metrics.scale_x;
    const auto y = pointer->y * metrics.scale_y;
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
      switch (pointer->phase) {
        case mozart::PointerEvent::Phase::MOVE:
          web_view.scrollPixels(delta_x, delta_y);
          break;

        case mozart::PointerEvent::Phase::UP:
          web_view.scrollPixels(delta_x, delta_y);
          break;

        default:
          break;
      }
    } else {
      switch (pointer->phase) {
        case mozart::PointerEvent::Phase::UP:
          web_view.handleMouseEvent(start_x_, start_y_, WebView::kMouseDown);
          web_view.handleMouseEvent(start_x_, start_y_, WebView::kMouseUp);
          break;

        default:
          break;
      }
    }
  }

 private:
  int start_x_;
  int start_y_;
  int last_x_;
  int last_y_;
  bool is_drag_;
};

class MozWebView : public mozart::BaseView,
                   public modular::Module,
                   public modular::Lifecycle,
                   public modular::LinkWatcher,
                   public web_view::WebView {
 public:
  MozWebView(
      mozart::ViewManagerPtr view_manager,
      fidl::InterfaceRequest<mozart::ViewOwner> view_owner_request,
      fidl::InterfaceRequest<app::ServiceProvider> outgoing_services_request,
      app::ApplicationContext* application_context,
      const std::string& url)
      : BaseView(std::move(view_manager),
                 std::move(view_owner_request),
                 "WebView"),
        weak_factory_(this),
        url_(url),
        image_cycler_(session()),
        module_binding_(this),
        lifecycle_binding_(this),
        main_link_watcher_binding_(this) {
    SetNeedSquareMetrics(true);
    parent_node().AddChild(image_cycler_);

    if (outgoing_services_request) {
      // Expose |WebView| interface to caller
      outgoing_services_.AddService<web_view::WebView>(
          [this](fidl::InterfaceRequest<web_view::WebView> request) {
            web_view_interface_bindings_.AddBinding(this, std::move(request));
          });
      outgoing_services_.AddBinding(std::move(outgoing_services_request));
    }

    // Register this application as a single module. Note that this is a
    // different opinion on ownership from Mozart, which assumes multiple
    // views can exists (although they currently don't).
    application_context->outgoing_services()->AddService<modular::Module>(
        [this](fidl::InterfaceRequest<modular::Module> request) {
          module_binding_.Bind(std::move(request));
        });
    application_context->outgoing_services()->AddService<modular::Lifecycle>(
        [this](fidl::InterfaceRequest<modular::Lifecycle> request) {
          lifecycle_binding_.Bind(std::move(request));
        });
    fsl::MessageLoop::GetCurrent()->task_runner()->PostTask(
        ([weak = weak_factory_.GetWeakPtr()]() {
          if (weak)
            weak->CallIdle();
        }));

    if (!icu_data::Initialize(application_context)) {
      printf("Could not load ICU data\n");
    }
  }

  ~MozWebView() override {}

 private:
  // |WebView|:
  void SetUrl(const ::fidl::String& url) override {
    url_ = url;
    // Reset url_set_ so that the next OnDraw() knows to call
    // web_view_.setURL()
    url_set_ = false;
    InvalidateScene();
  }

  // |WebView|:
  void ClearCookies() override { web_view_.deleteAllCookies(); }

  void SetWebRequestDelegate(
      ::fidl::InterfaceHandle<web_view::WebRequestDelegate> delegate) final {
    webRequestDelegate_ =
        web_view::WebRequestDelegatePtr::Create(std::move(delegate));
  }

  bool HandleKeyboardEvent(const mozart::InputEventPtr& event) {
    bool handled = true;
    const mozart::KeyboardEventPtr& keyboard = event->get_keyboard();
    bool pressed = keyboard->phase == mozart::KeyboardEvent::Phase::PRESSED;
    bool repeating = keyboard->phase == mozart::KeyboardEvent::Phase::REPEAT;
    if (pressed && keyboard->code_point == 'c' &&
        keyboard->modifiers & mozart::kModifierControl) {
      exit(0);
    } else if (pressed && keyboard->code_point == '[' &&
               keyboard->modifiers & mozart::kModifierControl) {
      web_view_.goBack();
    } else if (pressed && keyboard->code_point == ']' &&
               keyboard->modifiers & mozart::kModifierControl) {
      web_view_.goForward();
    } else if (pressed && keyboard->code_point == 'r' &&
               keyboard->modifiers & mozart::kModifierControl) {
      web_view_.reload();
    } else {
      bool handled =
          web_view_.handleKeyEvent(keyboard->hid_usage, keyboard->code_point,
                                   pressed || repeating, repeating);
      if (!handled) {
        if (pressed || repeating) {
          if (keyboard->hid_usage == HID_USAGE_KEY_DOWN) {
            web_view_.scrollDownOneLine();
          } else if (keyboard->hid_usage == HID_USAGE_KEY_UP) {
            web_view_.scrollUpOneLine();
          } else if (keyboard->hid_usage == HID_USAGE_KEY_RIGHT) {
            web_view_.scrollRightOneLine();
          } else if (keyboard->hid_usage == HID_USAGE_KEY_LEFT) {
            web_view_.scrollLeftOneLine();
          }
        }
      }
    }
    return handled;
  }

  bool HandleMouseEvent(const mozart::PointerEventPtr& pointer) {
    bool handled = false;
    if (pointer->buttons & mozart::kMousePrimaryButton) {
      switch (pointer->phase) {
        case mozart::PointerEvent::Phase::DOWN:
        case mozart::PointerEvent::Phase::MOVE:
          web_view_.handleMouseEvent(
              pointer->x * metrics().scale_x, pointer->y * metrics().scale_y,
              pointer->phase == mozart::PointerEvent::Phase::DOWN
                  ? ::WebView::kMouseDown
                  : ::WebView::kMouseMoved);
          handled = true;
          break;
        case mozart::PointerEvent::Phase::UP:
          web_view_.handleMouseEvent(pointer->x * metrics().scale_x,
                                     pointer->y * metrics().scale_y,
                                     ::WebView::kMouseUp);
          handled = true;
          break;
        default:
          break;
      }
    }
    return handled;
  }

  void HandleTouchDown(const mozart::PointerEventPtr& pointer) {
    const auto x = pointer->x * metrics().scale_x;
    const auto y = pointer->y * metrics().scale_y;
    touch_trackers_[pointer->pointer_id] = TouchTracker(x, y);
  }

  bool HandleTouchEvent(const mozart::PointerEventPtr& pointer) {
    bool handled = false;
    auto pointer_id = pointer->pointer_id;
    switch (pointer->phase) {
      case mozart::PointerEvent::Phase::DOWN:
        HandleTouchDown(pointer);
        handled = true;
        break;
      case mozart::PointerEvent::Phase::MOVE:
        touch_trackers_[pointer_id].HandleEvent(pointer, metrics(), web_view_);
        handled = true;
        break;
      case mozart::PointerEvent::Phase::UP:
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
  bool OnInputEvent(mozart::InputEventPtr event) override {
    bool handled = false;
    web_view_.setFocused(true);
    web_view_.setVisible(true);
    if (event->is_pointer()) {
      const mozart::PointerEventPtr& pointer = event->get_pointer();
      if (pointer->type == mozart::PointerEvent::Type::TOUCH) {
        handled = HandleTouchEvent(pointer);
      } else if (pointer->type == mozart::PointerEvent::Type::MOUSE) {
        handled = HandleMouseEvent(pointer);
      }
    } else if (event->is_keyboard()) {
      handled = HandleKeyboardEvent(event);
    }

    InvalidateScene();
    return handled;
  }

  // |BaseView|:
  void OnSceneInvalidated(
      scenic::PresentationInfoPtr presentation_info) override {
    if (!has_physical_size())
      return;

    // Update the image.
    const scenic_lib::HostImage* image = image_cycler_.AcquireImage(
        physical_size().width, physical_size().height,
        physical_size().width * 4u, scenic::ImageInfo::PixelFormat::BGRA_8,
        scenic::ImageInfo::ColorSpace::SRGB);
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
    image_cycler_.SetScale(1.f / metrics().scale_x, 1.f / metrics().scale_y,
                           1.f);
    image_cycler_.SetTranslation(logical_size().width * .5f,
                                 logical_size().height * .5f, 0.f);
  }

  void CallIdle() {
    web_view_.iterateEventLoop();
    InvalidateScene();
    fsl::MessageLoop::GetCurrent()->task_runner()->PostTask(
        ([weak = weak_factory_.GetWeakPtr()]() {
          if (weak)
            weak->CallIdle();
        }));
  }

  // modular::Module
  void Initialize(
      fidl::InterfaceHandle<modular::ModuleContext> context,
      fidl::InterfaceHandle<app::ServiceProvider> incoming_services,
      fidl::InterfaceRequest<app::ServiceProvider> outgoing_services) final {
    auto context_ptr = modular::ModuleContextPtr::Create(std::move(context));
    context_ptr->GetLink(nullptr, main_link_.NewRequest());
    main_link_->Watch(main_link_watcher_binding_.NewBinding());
  }

  // modular::Terminate
  void Terminate() final {
    fsl::MessageLoop::GetCurrent()->QuitNow();
  }

  // modular::LinkWatcher
  void Notify(const fidl::String& json) final {
    modular::JsonDoc parsed_json;
    parsed_json.Parse(json.To<std::string>());

    const auto contract_it = parsed_json.FindMember("view");
    if (contract_it != parsed_json.MemberEnd()) {
      const auto& contract = contract_it->value;
      auto url_it = contract.FindMember("uri");
      if (url_it == contract.MemberEnd() || !url_it->value.IsString()) {
        FXL_LOG(WARNING) << "/view/uri must be a string in " << json;
      } else {
        SetUrl(url_it->value.GetString());
      }
    }
  }

  ::WebView web_view_;
  fxl::WeakPtrFactory<MozWebView> weak_factory_;
  bool url_set_ = false;
  std::string url_;
  std::map<uint32_t, TouchTracker> touch_trackers_;
  float page_scale_factor_ = 0;

  scenic_lib::HostImageCycler image_cycler_;

  // Link state, used to gather URL updates for the story
  modular::LinkPtr main_link_;
  fidl::Binding<modular::Module> module_binding_;
  fidl::Binding<modular::Lifecycle> lifecycle_binding_;
  fidl::Binding<modular::LinkWatcher> main_link_watcher_binding_;

  // Delegate that receives WillSendRequest calls. Can be null.
  web_view::WebRequestDelegatePtr webRequestDelegate_;

  // We use this |ServiceProvider| to expose the |WebView| interface to
  // others.
  app::ServiceProviderImpl outgoing_services_;

  fidl::BindingSet<WebView> web_view_interface_bindings_;

  FXL_DISALLOW_COPY_AND_ASSIGN(MozWebView);
};

int main(int argc, const char** argv) {
  auto command_line = fxl::CommandLineFromArgcArgv(argc, argv);
  std::vector<std::string> urls = command_line.positional_args();
  std::string url = kDefaultUrl;
  if (!urls.empty()) {
    url = urls.front();
  }

  fsl::MessageLoop loop;

  mozart::ViewProviderApp app([&url](mozart::ViewContext view_context) {
    return std::make_unique<MozWebView>(
        std::move(view_context.view_manager),
        std::move(view_context.view_owner_request),
        std::move(view_context.outgoing_services),
        view_context.application_context, url);
  });

  loop.Run();
  return 0;
}
