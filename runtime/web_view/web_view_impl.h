// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#pragma once

#include <web_view/cpp/fidl.h>

#include "lib/app/cpp/service_provider_impl.h"
#include "lib/fidl/cpp/binding_set.h"
#include "lib/fxl/macros.h"
#include "lib/fxl/memory/weak_ptr.h"
#include "lib/ui/scenic/client/host_image_cycler.h"
#include "lib/ui/view_framework/base_view.h"

#ifdef EXPERIMENTAL_WEB_ENTITY_EXTRACTION
#include "topaz/runtime/web_view/schema_org_context.h"
#endif

#include "WebView.h"

class TouchTracker {
 public:
  TouchTracker(int x = 0, int y = 0);

  void HandleEvent(const fuchsia::ui::input::PointerEvent& pointer,
                   const fuchsia::ui::gfx::Metrics& metrics,
                   WebView& web_view);

 private:
  int start_x_;
  int start_y_;
  int last_x_;
  int last_y_;
  bool is_drag_;
};

class WebViewImpl : public mozart::BaseView,
                   public web_view::WebView {
 public:
  WebViewImpl(views_v1::ViewManagerPtr view_manager,
              fidl::InterfaceRequest<views_v1_token::ViewOwner> view_owner_request,
              fidl::InterfaceRequest<component::ServiceProvider>
                  outgoing_services_request,
              const std::string& url);

  ~WebViewImpl();

#ifdef EXPERIMENTAL_WEB_ENTITY_EXTRACTION
  void set_context_writer(modular::ContextWriterPtr context_writer) {
    schema_org_.set_context_writer(std::move(context_writer));
  }

  void set_component_context(modular::ComponentContextPtr component_context) {
    schema_org_.set_component_context(std::move(component_context));
  }
#endif

  // |WebView|:
  void SetUrl(fidl::StringPtr url) override;

 private:
  // |WebView|:
  void ClearCookies() override;

  void SetWebRequestDelegate(
      ::fidl::InterfaceHandle<web_view::WebRequestDelegate> delegate) final;

  bool HandleKeyboardEvent(const fuchsia::ui::input::InputEvent& event);
  bool HandleMouseEvent(const fuchsia::ui::input::PointerEvent& pointer);
  void HandleTouchDown(const fuchsia::ui::input::PointerEvent& pointer);
  bool HandleTouchEvent(const fuchsia::ui::input::PointerEvent& pointer);

  // |BaseView|:
  bool OnInputEvent(fuchsia::ui::input::InputEvent event) override;

  // |BaseView|:
  void OnSceneInvalidated(
      fuchsia::images::PresentationInfo presentation_info) override;

  void CallIdle();

  void DidFinishLoad();

  ::WebView web_view_;
  fxl::WeakPtrFactory<WebViewImpl> weak_factory_;
  bool url_set_ = false;
  std::string url_;
  std::map<uint32_t, TouchTracker> touch_trackers_;
  float page_scale_factor_ = 0;

#ifdef EXPERIMENTAL_WEB_ENTITY_EXTRACTION
  SchemaOrgContext schema_org_;
#endif

  scenic_lib::HostImageCycler image_cycler_;

  // Delegate that receives WillSendRequest calls. Can be null.
  web_view::WebRequestDelegatePtr webRequestDelegate_;

  // We use this |ServiceProvider| to expose the |WebView| interface to
  // others.
  component::ServiceProviderImpl outgoing_services_;

  fidl::BindingSet<WebView> web_view_interface_bindings_;

  FXL_DISALLOW_COPY_AND_ASSIGN(WebViewImpl);
};
