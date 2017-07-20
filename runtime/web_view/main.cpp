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
#include <magenta/device/console.h>
#include <magenta/device/display.h>
#include <magenta/pixelformat.h>
#include <magenta/syscalls.h>
#include <magenta/types.h>
#include <mxio/io.h>
#include <stdlib.h>

#include "WebView.h"

#include "apps/icu_data/lib/icu_data.h"
#include "apps/modular/lib/rapidjson/rapidjson.h"
#include "apps/modular/services/module/module.fidl.h"
#include "apps/modular/services/story/link.fidl.h"
#include "apps/mozart/lib/scene/client/host_image_cycler.h"
#include "apps/mozart/lib/view_framework/base_view.h"
#include "apps/mozart/lib/view_framework/view_provider_app.h"
#include "apps/web_runner/services/web_view.fidl.h"
#include "lib/ftl/command_line.h"
#include "lib/ftl/logging.h"
#include "lib/ftl/macros.h"
#include "lib/ftl/memory/weak_ptr.h"
#include "lib/mtl/tasks/message_loop.h"

using namespace WebCore;

using std::endl;
using std::cout;
using std::cerr;

namespace {
constexpr char kDefaultUrl[] = "http://www.google.com/";
}  // namespace

class MozWebView : public mozart::BaseView,
                   public modular::Module,
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
    // different opinion on ownership from Mozart, which assumes multiple views
    // can exists (although they currently don't).
    application_context->outgoing_services()->AddService<modular::Module>(
        [this](fidl::InterfaceRequest<modular::Module> request) {
          module_binding_.Bind(std::move(request));
        });
    mtl::MessageLoop::GetCurrent()->task_runner()->PostTask(
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
    // Reset url_set_ so that the next OnDraw() knows to call web_view_.setURL()
    url_set_ = false;
    InvalidateScene();
  }

  // |WebView|:
  void ClearCookies() override {
    // Call web_view_.ClearCookieJar()
  }

  void SetWebRequestDelegate(
      ::fidl::InterfaceHandle<web_view::WebRequestDelegate> delegate) final {
    webRequestDelegate_ =
        web_view::WebRequestDelegatePtr::Create(std::move(delegate));
  }

  // |BaseView|:
  bool OnInputEvent(mozart::InputEventPtr event) override {
    bool handled = false;
    web_view_.setFocused(true);
    web_view_.setVisible(true);
    if (event->is_pointer()) {
      const mozart::PointerEventPtr& pointer = event->get_pointer();
      switch (pointer->phase) {
        case mozart::PointerEvent::Phase::DOWN:
        case mozart::PointerEvent::Phase::MOVE:
          if (pointer->type == mozart::PointerEvent::Type::TOUCH ||
              (pointer->type == mozart::PointerEvent::Type::MOUSE &&
               pointer->buttons & mozart::kMousePrimaryButton)) {
            web_view_.handleMouseEvent(
                pointer->x * metrics().scale_x, pointer->y * metrics().scale_y,
                pointer->phase == mozart::PointerEvent::Phase::DOWN
                    ? ::WebView::kMouseDown
                    : ::WebView::kMouseMoved);
          }
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
    } else if (event->is_keyboard()) {
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
    }

    InvalidateScene();
    return handled;
  }

  // |BaseView|:
  void OnSceneInvalidated(
      mozart2::PresentationInfoPtr presentation_info) override {
    if (!has_physical_size())
      return;

    // Update the image.
    const mozart::client::HostImage* image = image_cycler_.AcquireImage(
        physical_size().width, physical_size().height,
        physical_size().width * 4u, mozart2::ImageInfo::PixelFormat::BGRA_8,
        mozart2::ImageInfo::ColorSpace::SRGB);
    FTL_DCHECK(image);

    // Paint the webview.
    web_view_.setup(reinterpret_cast<unsigned char*>(image->image_ptr()),
                    MX_PIXEL_FORMAT_ARGB_8888, physical_size().width,
                    physical_size().height, physical_size().width * 4u);
    if (!url_set_) {
      const char* urlToOpen = url_.c_str();
      FTL_LOG(INFO) << "Loading " << urlToOpen;
      web_view_.setURL(urlToOpen);
      url_set_ = true;

      FTL_DCHECK(metrics().scale_x ==
                 metrics().scale_y);  // we asked for square metrics
      web_view_.setPageAndTextZoomFactors(metrics().scale_x, 1.0);

      auto requestCallback = [this](std::string url) {
        if (webRequestDelegate_) {
          webRequestDelegate_->WillSendRequest(url);
        }
        return url;
      };
      web_view_.setWebRequestDelegate(requestCallback);
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
    mtl::MessageLoop::GetCurrent()->task_runner()->PostTask(
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

  void Stop(const StopCallback& done) final { done(); }

  // modular::LinkWatcher
  void Notify(const fidl::String& json) final {
    modular::JsonDoc parsed_json;
    parsed_json.Parse(json.To<std::string>());

    const auto contract_it = parsed_json.FindMember("view");
    if (contract_it != parsed_json.MemberEnd()) {
      const auto& contract = contract_it->value;
      auto url_it = contract.FindMember("uri");
      if (url_it == contract.MemberEnd() || !url_it->value.IsString()) {
        FTL_LOG(WARNING) << "/view/uri must be a string in " << json;
      } else {
        SetUrl(url_it->value.GetString());
      }
    }
  }

  ::WebView web_view_;
  ftl::WeakPtrFactory<MozWebView> weak_factory_;
  bool url_set_ = false;
  std::string url_;

  mozart::client::HostImageCycler image_cycler_;

  // Link state, used to gather URL updates for the story
  modular::LinkPtr main_link_;
  fidl::Binding<modular::Module> module_binding_;
  fidl::Binding<modular::LinkWatcher> main_link_watcher_binding_;

  // Delegate that receives WillSendRequest calls. Can be null.
  web_view::WebRequestDelegatePtr webRequestDelegate_;

  // We use this |ServiceProvider| to expose the |WebView| interface to others.
  app::ServiceProviderImpl outgoing_services_;

  fidl::BindingSet<WebView> web_view_interface_bindings_;

  FTL_DISALLOW_COPY_AND_ASSIGN(MozWebView);
};

int main(int argc, const char** argv) {
  auto command_line = ftl::CommandLineFromArgcArgv(argc, argv);
  std::vector<std::string> urls = command_line.positional_args();
  std::string url = kDefaultUrl;
  if (!urls.empty()) {
    url = urls.front();
  }

  mtl::MessageLoop loop;

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
