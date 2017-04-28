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

#include "apps/modular/lib/rapidjson/rapidjson.h"
#include "apps/modular/services/module/module.fidl.h"
#include "apps/modular/services/story/link.fidl.h"
#include "apps/mozart/lib/view_framework/base_view.h"
#include "apps/mozart/lib/view_framework/input_handler.h"
#include "apps/mozart/lib/view_framework/view_provider_app.h"
#include "apps/mozart/services/buffers/cpp/buffer_producer.h"
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
constexpr uint32_t kContentImageResourceId = 1;
constexpr uint32_t kRootNodeId = mozart::kSceneRootNodeId;
constexpr char kDefaultUrl[] = "http://google.com/index.html";
}  // namespace

static void* MakeImage(int width,
                       int height,
                       mozart::BufferProducer* producer,
                       mozart::ImagePtr* out_image) {
  using namespace mozart;
  FTL_DCHECK(producer);
  FTL_DCHECK(producer->map_flags() &
             (MX_VM_FLAG_PERM_READ | MX_VM_FLAG_PERM_WRITE));
  FTL_DCHECK(out_image);

  size_t row_bytes = 4 * width;
  size_t total_bytes = row_bytes * height;
  auto buffer_holder = producer->ProduceBuffer(total_bytes);
  if (!buffer_holder) {
    FTL_LOG(ERROR) << "Could not produce buffer: total_bytes=" << total_bytes;
    return nullptr;
  }

  BufferPtr buffer = buffer_holder->GetBuffer();
  if (!buffer) {
    FTL_LOG(ERROR) << "Could not get buffer for consumer";
    return nullptr;
  }

  void* bufferMem = buffer_holder->shared_vmo()->Map();
  if (!bufferMem) {
    FTL_LOG(ERROR) << "Could not map surface into memory";
    return nullptr;
  }

  auto image = Image::New();
  image->size = Size::New();
  image->size->width = width;
  image->size->height = height;
  image->stride = row_bytes;
  image->pixel_format = Image::PixelFormat::B8G8R8A8;
  image->alpha_format = Image::AlphaFormat::PREMULTIPLIED;
  image->color_space = Image::ColorSpace::SRGB;
  image->buffer = std::move(buffer);
  *out_image = std::move(image);
  return bufferMem;
}

class MozWebView : public mozart::BaseView,
                   public mozart::InputListener,
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
        input_handler_(GetViewServiceProvider(), this),
        weak_factory_(this),
        url_(url),
        module_binding_(this),
        main_link_watcher_binding_(this) {
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
  }

  ~MozWebView() override {}

 private:
  // |WebView|:
  void SetUrl(const ::fidl::String& url) override {
    url_ = url;
    // Reset url_set_ so that the next OnDraw() knows to call web_view_.setURL()
    url_set_ = false;
    Invalidate();
  }

  void SetWebRequestDelegate(
      ::fidl::InterfaceHandle<web_view::WebRequestDelegate> delegate) final {
    webRequestDelegate_ =
        web_view::WebRequestDelegatePtr::Create(std::move(delegate));
  }

  void OnEvent(mozart::InputEventPtr event,
               const OnEventCallback& callback) override {
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
                pointer->x, pointer->y,
                pointer->phase == mozart::PointerEvent::Phase::DOWN
                    ? ::WebView::kMouseDown
                    : ::WebView::kMouseMoved);
          }
          handled = true;
          break;
        case mozart::PointerEvent::Phase::UP:
          web_view_.handleMouseEvent(pointer->x, pointer->y,
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

    callback(handled);
    Invalidate();
  }

  // |BaseView|:
  void OnDraw() override {
    FTL_DCHECK(properties());

    auto update = mozart::SceneUpdate::New();

    const mozart::Size& size = *properties()->view_layout->size;
    if (size.width > 0 && size.height > 0) {
      mozart::RectF bounds;
      bounds.width = size.width;
      bounds.height = size.height;

      mozart::ImagePtr image;
      void* buffer =
          MakeImage(size.width, size.height, &buffer_producer_, &image);
      web_view_.setup(reinterpret_cast<unsigned char*>(buffer),
                      MX_PIXEL_FORMAT_ARGB_8888, size.width, size.height,
                      size.width * 4);
      if (!url_set_) {
        const char* urlToOpen = url_.c_str();
        FTL_LOG(INFO) << "Loading " << urlToOpen;
        web_view_.setURL(urlToOpen);
        url_set_ = true;
        web_view_.setPageAndTextZoomFactors(2.0, 1.0);

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

      auto content_resource = mozart::Resource::New();
      content_resource->set_image(mozart::ImageResource::New());
      content_resource->get_image()->image = std::move(image);
      update->resources.insert(kContentImageResourceId,
                               std::move(content_resource));

      auto root_node = mozart::Node::New();
      root_node->hit_test_behavior = mozart::HitTestBehavior::New();
      root_node->op = mozart::NodeOp::New();
      root_node->op->set_image(mozart::ImageNodeOp::New());
      root_node->op->get_image()->content_rect = bounds.Clone();
      root_node->op->get_image()->image_resource_id = kContentImageResourceId;
      update->nodes.insert(kRootNodeId, std::move(root_node));
    } else {
      auto root_node = mozart::Node::New();
      update->nodes.insert(kRootNodeId, std::move(root_node));
    }

    // Publish the updated scene contents.
    scene()->Update(std::move(update));
    scene()->Publish(CreateSceneMetadata());
    buffer_producer_.Tick();
  }

  void CallIdle() {
    web_view_.iterateEventLoop();
    Invalidate();
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
    auto url_it = parsed_json.FindMember("url");
    if (url_it == parsed_json.MemberEnd()) {
      FTL_LOG(WARNING) << "web_view expected \"url\" field in link json, got"
                       << json;
      return;
    }
    auto& url_value = url_it->value;
    if (!url_value.IsString()) {
      FTL_LOG(WARNING) << "web_view expected string in json \"url\" field, got "
                       << json;
      return;
    }
    SetUrl(fidl::String(url_value.GetString()));
  }

  mozart::InputHandler input_handler_;
  mozart::BufferProducer buffer_producer_;
  ::WebView web_view_;
  ftl::WeakPtrFactory<MozWebView> weak_factory_;
  bool url_set_ = false;
  std::string url_;

  // Link state, used to gather URL updates for the story
  modular::LinkPtr main_link_;
  fidl::Binding<modular::Module> module_binding_;
  fidl::Binding<modular::LinkWatcher> main_link_watcher_binding_;

  // Delegate that receives WillSendRequest calls. Can be null.
  web_view::WebRequestDelegatePtr webRequestDelegate_;

  // We use this |ServiceProvider| to expose the |WebView| interface to others.
  modular::ServiceProviderImpl outgoing_services_;

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
