// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef TOPAZ_RUNTIME_WEB_VIEW_WEB_VIEW_IMPL_H_
#define TOPAZ_RUNTIME_WEB_VIEW_WEB_VIEW_IMPL_H_

#include <fuchsia/ui/input/cpp/fidl.h>
#include <fuchsia/webview/cpp/fidl.h>

#include "lib/component/cpp/service_provider_impl.h"
#include "lib/fidl/cpp/binding_set.h"
#include "lib/fxl/macros.h"
#include "lib/fxl/memory/weak_ptr.h"
#include "lib/ui/base_view/cpp/v1_base_view.h"
#include "lib/ui/scenic/cpp/host_image_cycler.h"

#ifdef EXPERIMENTAL_WEB_ENTITY_EXTRACTION
#include "topaz/runtime/web_view/schema_org_context.h"
#endif

#include "WebView.h"

class TouchTracker {
 public:
  TouchTracker(int x = 0, int y = 0);

  void HandleEvent(const fuchsia::ui::input::PointerEvent& pointer,
                   const fuchsia::ui::gfx::Metrics& metrics, WebView& web_view);

 private:
  int start_x_;
  int start_y_;
  int last_x_;
  int last_y_;
  bool is_drag_;
};

class WebViewImpl : public scenic::V1BaseView,
                    public fuchsia::webview::WebView,
                    fuchsia::ui::input::InputMethodEditorClient {
 public:
  WebViewImpl(scenic::ViewContext view_context,
              fuchsia::ui::input::ImeServicePtr ime_service,
              const std::string& url);
  ~WebViewImpl() = default;

#ifdef EXPERIMENTAL_WEB_ENTITY_EXTRACTION
  void set_context_writer(fuchsia::modular::ContextWriterPtr context_writer) {
    schema_org_.set_context_writer(std::move(context_writer));
  }

  void set_component_context(
      fuchsia::modular::ComponentContextPtr component_context) {
    schema_org_.set_component_context(std::move(component_context));
  }
#endif

  // |fuchsia::ui::input::InputMethodEditorClient|
  void DidUpdateState(fuchsia::ui::input::TextInputState state,
                      fuchsia::ui::input::InputEventPtr event) override;
  void OnAction(fuchsia::ui::input::InputMethodAction action) override;

  // |WebView|:
  void SetUrl(fidl::StringPtr url) override;

 private:
  // |WebView|:
  void ClearCookies() override;

  void SetWebRequestDelegate(
      ::fidl::InterfaceHandle<fuchsia::webview::WebRequestDelegate> delegate)
      final;

  bool HandleKeyboardEvent(const fuchsia::ui::input::InputEvent& event);
  void HandleMouseEvent(const fuchsia::ui::input::PointerEvent& pointer);
  void HandleTouchDown(const fuchsia::ui::input::PointerEvent& pointer);
  void HandleTouchEvent(const fuchsia::ui::input::PointerEvent& pointer);
  void HandleFocusEvent(const fuchsia::ui::input::FocusEvent& focus);

  void HandleWebRequestsFocusEvent(bool focused);
  void UpdateInputConnection();

  // |scenic::V1BaseView|
  bool OnInputEvent(fuchsia::ui::input::InputEvent event) override;
  void OnSceneInvalidated(
      fuchsia::images::PresentationInfo presentation_info) override;

  void CallIdle();

  void DidFinishLoad();

  ::WebView web_view_;
  fuchsia::ui::input::ImeServicePtr ime_service_;
  fuchsia::ui::input::InputMethodEditorPtr ime_ = nullptr;
  fidl::Binding<fuchsia::ui::input::InputMethodEditorClient>
      ime_client_binding_;
  fxl::WeakPtrFactory<WebViewImpl> weak_factory_;
  bool url_set_ = false;
  bool has_scenic_focus_ = false;
  bool web_requests_input_ = false;
  std::string url_;
  std::map<uint32_t, TouchTracker> touch_trackers_;
  float page_scale_factor_ = 0;

#ifdef EXPERIMENTAL_WEB_ENTITY_EXTRACTION
  SchemaOrgContext schema_org_;
#endif

  scenic::HostImageCycler image_cycler_;

  // Delegate that receives WillSendRequest calls. Can be null.
  fuchsia::webview::WebRequestDelegatePtr webRequestDelegate_;

  // We use this |ServiceProvider| to expose the |WebView| interface to
  // others.
  component::ServiceProviderImpl outgoing_services_;

  fidl::BindingSet<WebView> web_view_interface_bindings_;

  FXL_DISALLOW_COPY_AND_ASSIGN(WebViewImpl);
};

#endif  // TOPAZ_RUNTIME_WEB_VIEW_WEB_VIEW_IMPL_H_
