// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#pragma once

#include "topaz/runtime/web_runner/services/web_view.fidl.h"

#include "lib/app/cpp/service_provider_impl.h"
#include "lib/fidl/cpp/bindings/binding_set.h"
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

  void HandleEvent(const mozart::PointerEventPtr& pointer,
                   const scenic::Metrics& metrics,
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
  WebViewImpl(
      mozart::ViewManagerPtr view_manager,
      f1dl::InterfaceRequest<mozart::ViewOwner> view_owner_request,
      f1dl::InterfaceRequest<app::ServiceProvider> outgoing_services_request,
      const std::string& url);

  ~WebViewImpl();

#ifdef EXPERIMENTAL_WEB_ENTITY_EXTRACTION
  void set_context_writer(maxwell::ContextWriterPtr context_writer) {
    schema_org_.set_context_writer(std::move(context_writer));
  }

  void set_component_context(modular::ComponentContextPtr component_context) {
    schema_org_.set_component_context(std::move(component_context));
  }
#endif

  // |WebView|:
  void SetUrl(const ::f1dl::String& url) override;

 private:
  // |WebView|:
  void ClearCookies() override;

  void SetWebRequestDelegate(
      ::f1dl::InterfaceHandle<web_view::WebRequestDelegate> delegate) final;

  bool HandleKeyboardEvent(const mozart::InputEventPtr& event);

  bool HandleMouseEvent(const mozart::PointerEventPtr& pointer);

  void HandleTouchDown(const mozart::PointerEventPtr& pointer);

  bool HandleTouchEvent(const mozart::PointerEventPtr& pointer);

  // |BaseView|:
  bool OnInputEvent(mozart::InputEventPtr event) override;

  // |BaseView|:
  void OnSceneInvalidated(
      ui_mozart::PresentationInfoPtr presentation_info) override;

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
  app::ServiceProviderImpl outgoing_services_;

  f1dl::BindingSet<WebView> web_view_interface_bindings_;

  FXL_DISALLOW_COPY_AND_ASSIGN(WebViewImpl);
};

