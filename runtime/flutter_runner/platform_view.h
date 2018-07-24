// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef TOPAZ_RUNTIME_FLUTTER_RUNNER_PLATFORM_VIEW_H_
#define TOPAZ_RUNTIME_FLUTTER_RUNNER_PLATFORM_VIEW_H_

#include <map>
#include <set>

#include <fuchsia/modular/cpp/fidl.h>
#include <fuchsia/ui/input/cpp/fidl.h>
#include <fuchsia/ui/viewsv1/cpp/fidl.h>
#include <fuchsia/ui/viewsv1token/cpp/fidl.h>
#include <lib/fit/function.h>

#include "accessibility_bridge.h"
#include "flutter/lib/ui/window/viewport_metrics.h"
#include "flutter/shell/common/platform_view.h"
#include "lib/fidl/cpp/binding.h"
#include "lib/fxl/macros.h"
#include "surface.h"

namespace flutter {

// The per engine component residing on the platform thread is responsible for
// all platform specific integrations.
class PlatformView final : public shell::PlatformView,
                           public fuchsia::ui::viewsv1::ViewListener,
                           public fuchsia::ui::input::InputMethodEditorClient,
                           public fuchsia::ui::input::InputListener {
 public:
  PlatformView(
      PlatformView::Delegate& delegate, std::string debug_label,
      blink::TaskRunners task_runners,
      fidl::InterfaceHandle<fuchsia::sys::ServiceProvider>
          parent_environment_service_provider,
      fidl::InterfaceHandle<fuchsia::ui::viewsv1::ViewManager> view_manager,
      fidl::InterfaceRequest<fuchsia::ui::viewsv1token::ViewOwner> view_owner,
      zx::eventpair export_token,
      fidl::InterfaceHandle<fuchsia::modular::ContextWriter>
          accessibility_context_writer,
      zx_handle_t vsync_event_handle);

  ~PlatformView();

  void UpdateViewportMetrics(double pixel_ratio);

  fidl::InterfaceHandle<fuchsia::ui::viewsv1::ViewContainer>
  TakeViewContainer();

  void OfferServiceProvider(
      fidl::InterfaceHandle<fuchsia::sys::ServiceProvider> service_provider,
      fidl::VectorPtr<fidl::StringPtr> services);

 private:
  const std::string debug_label_;
  fuchsia::ui::viewsv1::ViewManagerPtr view_manager_;
  fuchsia::ui::viewsv1::ViewPtr view_;
  fidl::InterfaceHandle<fuchsia::ui::viewsv1::ViewContainer> view_container_;
  fuchsia::sys::ServiceProviderPtr service_provider_;
  fidl::Binding<fuchsia::ui::viewsv1::ViewListener> view_listener_;
  fuchsia::ui::input::InputConnectionPtr input_connection_;
  fidl::Binding<fuchsia::ui::input::InputListener> input_listener_;
  int current_text_input_client_ = 0;
  fidl::Binding<fuchsia::ui::input::InputMethodEditorClient> ime_client_;
  fuchsia::ui::input::InputMethodEditorPtr ime_;
  fuchsia::sys::ServiceProviderPtr parent_environment_service_provider_;
  fuchsia::modular::ClipboardPtr clipboard_;
  AccessibilityBridge accessibility_bridge_;
  std::unique_ptr<Surface> surface_;
  blink::LogicalMetrics metrics_;
  std::set<int> down_pointers_;
  std::map<
      std::string /* channel */,
      fit::function<void(
          fxl::RefPtr<blink::PlatformMessage> /* message */)> /* handler */>
      platform_message_handlers_;
  zx_handle_t vsync_event_handle_ = 0;

  void RegisterPlatformMessageHandlers();

  void UpdateViewportMetrics(const fuchsia::ui::viewsv1::ViewLayout& layout);

  void FlushViewportMetrics();

  // |fuchsia::ui::viewsv1::ViewListener|
  void OnPropertiesChanged(fuchsia::ui::viewsv1::ViewProperties properties,
                           OnPropertiesChangedCallback callback) override;

  // |fuchsia::ui::input::InputMethodEditorClient|
  void DidUpdateState(
      fuchsia::ui::input::TextInputState state,
      std::unique_ptr<fuchsia::ui::input::InputEvent> event) override;

  // |fuchsia::ui::input::InputMethodEditorClient|
  void OnAction(fuchsia::ui::input::InputMethodAction action) override;

  // |fuchsia::ui::input::InputListener|
  void OnEvent(fuchsia::ui::input::InputEvent event,
               OnEventCallback callback) override;

  bool OnHandlePointerEvent(const fuchsia::ui::input::PointerEvent& pointer);

  bool OnHandleKeyboardEvent(const fuchsia::ui::input::KeyboardEvent& keyboard);

  bool OnHandleFocusEvent(const fuchsia::ui::input::FocusEvent& focus);

  // |shell::PlatformView|
  std::unique_ptr<shell::VsyncWaiter> CreateVSyncWaiter() override;

  // |shell::PlatformView|
  std::unique_ptr<shell::Surface> CreateRenderingSurface() override;

  // |shell::PlatformView|
  void HandlePlatformMessage(
      fxl::RefPtr<blink::PlatformMessage> message) override;

  // |shell::PlatformView|
  void UpdateSemantics(
      blink::SemanticsNodeUpdates update,
      blink::CustomAccessibilityActionUpdates actions) override;

  // Channel handler for kFlutterPlatformChannel
  void HandleFlutterPlatformChannelPlatformMessage(
      fxl::RefPtr<blink::PlatformMessage> message);

  // Channel handler for kTextInputChannel
  void HandleFlutterTextInputChannelPlatformMessage(
      fxl::RefPtr<blink::PlatformMessage> message);

  FXL_DISALLOW_COPY_AND_ASSIGN(PlatformView);
};

}  // namespace flutter

#endif  // TOPAZ_RUNTIME_FLUTTER_RUNNER_PLATFORM_VIEW_H_
