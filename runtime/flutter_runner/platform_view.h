// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef TOPAZ_RUNTIME_FLUTTER_RUNNER_PLATFORM_VIEW_H_
#define TOPAZ_RUNTIME_FLUTTER_RUNNER_PLATFORM_VIEW_H_

#include <map>
#include <set>

#include <fuchsia/accessibility/cpp/fidl.h>
#include <fuchsia/modular/cpp/fidl.h>
#include <fuchsia/ui/input/cpp/fidl.h>
#ifndef SCENIC_VIEWS2
#include <fuchsia/ui/viewsv1/cpp/fidl.h>
#include <fuchsia/ui/viewsv1token/cpp/fidl.h>
#endif
#include <lib/fit/function.h>

#include "context_writer_bridge.h"
#include "flutter/fml/macros.h"
#include "flutter/lib/ui/window/viewport_metrics.h"
#include "flutter/shell/common/platform_view.h"
#include "lib/fidl/cpp/binding.h"
#include "semantics_bridge.h"
#include "surface.h"

namespace flutter {

// The per engine component residing on the platform thread is responsible for
// all platform specific integrations.
//
// The PlatformView implements SessionListener and gets Session events but it
// does *not* actually own the Session itself; that is owned by the Compositor
// thread.
class PlatformView final : public shell::PlatformView,
#ifndef SCENIC_VIEWS2
                           public fuchsia::ui::viewsv1::ViewListener,
#endif
                           private fuchsia::ui::scenic::SessionListener,
                           public fuchsia::ui::input::InputMethodEditorClient,
                           public fuchsia::ui::input::InputListener {
 public:
  PlatformView(
      PlatformView::Delegate& delegate, std::string debug_label,
      blink::TaskRunners task_runners,
      fidl::InterfaceHandle<fuchsia::sys::ServiceProvider>
          parent_environment_service_provider,
      fidl::InterfaceRequest<fuchsia::ui::scenic::SessionListener>
          session_listener_request,
      fit::closure on_session_listener_error_callback,
      OnMetricsUpdate session_metrics_did_change_callback,
      OnSizeChangeHint session_size_change_hint_callback,
#ifndef SCENIC_VIEWS2
      fidl::InterfaceHandle<fuchsia::ui::viewsv1::ViewManager> view_manager,
      fidl::InterfaceRequest<fuchsia::ui::viewsv1token::ViewOwner> view_owner,
      zx::eventpair export_token,
#endif
      fidl::InterfaceHandle<fuchsia::modular::ContextWriter>
          accessibility_context_writer,
      zx_handle_t vsync_event_handle);
  PlatformView(PlatformView::Delegate& delegate, std::string debug_label,
               blink::TaskRunners task_runners,
               fidl::InterfaceHandle<fuchsia::sys::ServiceProvider>
                   parent_environment_service_provider,
               fidl::InterfaceHandle<fuchsia::modular::ContextWriter>
                   accessibility_context_writer,
               zx_handle_t vsync_event_handle);

  ~PlatformView();

  void UpdateViewportMetrics(const fuchsia::ui::gfx::Metrics& metrics);

  fidl::InterfaceHandle<fuchsia::ui::viewsv1::ViewContainer>
  TakeViewContainer();

#ifndef SCENIC_VIEWS2
  void OfferServiceProvider(
      fidl::InterfaceHandle<fuchsia::sys::ServiceProvider> service_provider,
      fidl::VectorPtr<fidl::StringPtr> services);
#endif

 private:
  const std::string debug_label_;

  fidl::Binding<fuchsia::ui::scenic::SessionListener> session_listener_binding_;
  fit::closure session_listener_error_callback_;
  OnMetricsUpdate metrics_changed_callback_;
  OnSizeChangeHint size_change_hint_callback_;

  fuchsia::sys::ServiceProviderPtr service_provider_;

#ifndef SCENIC_VIEWS2
  fuchsia::ui::viewsv1::ViewManagerPtr view_manager_;
  fuchsia::ui::viewsv1::ViewPtr view_;
  fidl::InterfaceHandle<fuchsia::ui::viewsv1::ViewContainer> view_container_;
  fidl::Binding<fuchsia::ui::viewsv1::ViewListener> view_listener_;
  fuchsia::ui::input::InputConnectionPtr input_connection_;
  fidl::Binding<fuchsia::ui::input::InputListener> input_listener_;
#endif

  int current_text_input_client_ = 0;
  fidl::Binding<fuchsia::ui::input::InputMethodEditorClient> ime_client_;
  fuchsia::ui::input::InputMethodEditorPtr ime_;
  fuchsia::ui::input::ImeServicePtr text_sync_service_;
  fuchsia::ui::policy::PresenterPtr presenter_service_;

  fuchsia::sys::ServiceProviderPtr parent_environment_service_provider_;
  fuchsia::modular::ClipboardPtr clipboard_;
  ContextWriterBridge context_writer_bridge_;
  // The Semantics bridge is used to provide semantics data from this platform
  // view to the accessibility manager.
  SemanticsBridge semantics_bridge_;
  std::unique_ptr<Surface> surface_;
  blink::LogicalMetrics metrics_;
  fuchsia::ui::gfx::Metrics scenic_metrics_;
  // TODO(SCN-1013): Remove this wart after the input v2 migration.
  bool HACK_legacy_input_path_;
  // last_text_state_ is the last state of the text input as reported by the IME
  // or initialized by Flutter. We set it to null if Flutter doesn't want any
  // input, since then there is no text input state at all.
  std::unique_ptr<fuchsia::ui::input::TextInputState> last_text_state_;

  std::set<int> down_pointers_;
  std::map<
      std::string /* channel */,
      fit::function<void(
          fml::RefPtr<blink::PlatformMessage> /* message */)> /* handler */>
      platform_message_handlers_;
  zx_handle_t vsync_event_handle_ = 0;

  void RegisterPlatformMessageHandlers();

#ifndef SCENIC_VIEWS2
  // TODO(SCN-975): Re-enable.
  // // Method to connect the a11y bridge with the a11y manager with a view id.
  // void ConnectSemanticsProvider(::fuchsia::ui::viewsv1token::ViewToken
  // token);
  void UpdateViewportMetrics(const fuchsia::ui::viewsv1::ViewLayout& layout);
#endif

  void FlushViewportMetrics();

#ifndef SCENIC_VIEWS2
  // |fuchsia::ui::viewsv1::ViewListener|
  void OnPropertiesChanged(fuchsia::ui::viewsv1::ViewProperties properties,
                           OnPropertiesChangedCallback callback) override;
#else
  // Called when the view's properties have changed.
  void OnPropertiesChanged(
      const fuchsia::ui::gfx::ViewProperties& view_properties);
#endif

  // |fuchsia::ui::input::InputMethodEditorClient|
  void DidUpdateState(
      fuchsia::ui::input::TextInputState state,
      std::unique_ptr<fuchsia::ui::input::InputEvent> event) override;

  // |fuchsia::ui::input::InputMethodEditorClient|
  void OnAction(fuchsia::ui::input::InputMethodAction action) override;

  // |fuchsia::ui::input::InputListener|
  void OnEvent(fuchsia::ui::input::InputEvent event,
               OnEventCallback callback) override;

  // |fuchsia::ui::scenic::SessionListener|
  void OnScenicError(fidl::StringPtr error) override;
  void OnScenicEvent(
      fidl::VectorPtr<fuchsia::ui::scenic::Event> events) override;

  bool OnHandlePointerEvent(const fuchsia::ui::input::PointerEvent& pointer);

  bool OnHandleKeyboardEvent(const fuchsia::ui::input::KeyboardEvent& keyboard);

  bool OnHandleFocusEvent(const fuchsia::ui::input::FocusEvent& focus);

  // Gets a new input method editor from the input connection. Run when both
  // Scenic has focus and Flutter has requested input with setClient.
  void ActivateIme();

  // Detaches the input method editor connection, ending the edit session and
  // closing the onscreen keyboard. Call when input is no longer desired, either
  // because Scenic says we lost focus or when Flutter no longer has a text
  // field focused.
  void DeactivateIme();

  // |shell::PlatformView|
  std::unique_ptr<shell::VsyncWaiter> CreateVSyncWaiter() override;

  // |shell::PlatformView|
  std::unique_ptr<shell::Surface> CreateRenderingSurface() override;

  // |shell::PlatformView|
  void HandlePlatformMessage(
      fml::RefPtr<blink::PlatformMessage> message) override;

  // |shell::PlatformView|
  void UpdateSemantics(
      blink::SemanticsNodeUpdates update,
      blink::CustomAccessibilityActionUpdates actions) override;

  // Channel handler for kAccessibilityChannel. This is currently not
  // being used, but it is necessary to handle accessibility messages
  // that are sent by Flutter when semantics is enabled.
  void HandleAccessibilityChannelPlatformMessage(
      fml::RefPtr<blink::PlatformMessage> message);

  // Channel handler for kFlutterPlatformChannel
  void HandleFlutterPlatformChannelPlatformMessage(
      fml::RefPtr<blink::PlatformMessage> message);

  // Channel handler for kTextInputChannel
  void HandleFlutterTextInputChannelPlatformMessage(
      fml::RefPtr<blink::PlatformMessage> message);

  FML_DISALLOW_COPY_AND_ASSIGN(PlatformView);
};

}  // namespace flutter

#endif  // TOPAZ_RUNTIME_FLUTTER_RUNNER_PLATFORM_VIEW_H_
