// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef TOPAZ_RUNTIME_FLUTTER_RUNNER_PLATFORM_VIEW_H_
#define TOPAZ_RUNTIME_FLUTTER_RUNNER_PLATFORM_VIEW_H_

#include <map>
#include <set>

#include <fuchsia/accessibility/cpp/fidl.h>
#include <fuchsia/modular/cpp/fidl.h>
#include <fuchsia/ui/gfx/cpp/fidl.h>
#include <fuchsia/ui/input/cpp/fidl.h>
#include <fuchsia/ui/scenic/cpp/fidl.h>
#include <lib/fit/function.h>

#include "flutter/fml/macros.h"
#include "flutter/lib/ui/window/viewport_metrics.h"
#include "flutter/shell/common/platform_view.h"
#include "lib/fidl/cpp/binding.h"
#include "lib/ui/scenic/cpp/id.h"

#include "context_writer_bridge.h"
#include "surface.h"

namespace flutter_runner {

using OnMetricsUpdate = fit::function<void(const fuchsia::ui::gfx::Metrics&)>;
using OnSizeChangeHint =
    fit::function<void(float width_change_factor, float height_change_factor)>;

// The per engine component residing on the platform thread is responsible for
// all platform specific integrations.
//
// The PlatformView implements SessionListener and gets Session events but it
// does *not* actually own the Session itself; that is owned by the Compositor
// thread.
class PlatformView final : public flutter::PlatformView,
                           private fuchsia::ui::scenic::SessionListener,
                           public fuchsia::ui::input::InputMethodEditorClient {
 public:
  PlatformView(PlatformView::Delegate& delegate, std::string debug_label,
               flutter::TaskRunners task_runners,
               fidl::InterfaceHandle<fuchsia::sys::ServiceProvider>
                   parent_environment_service_provider,
               fidl::InterfaceRequest<fuchsia::ui::scenic::SessionListener>
                   session_listener_request,
               fit::closure on_session_listener_error_callback,
               OnMetricsUpdate session_metrics_did_change_callback,
               OnSizeChangeHint session_size_change_hint_callback,
               fidl::InterfaceHandle<fuchsia::modular::ContextWriter>
                   accessibility_context_writer,
               zx_handle_t vsync_event_handle);
  PlatformView(PlatformView::Delegate& delegate, std::string debug_label,
               flutter::TaskRunners task_runners,
               fidl::InterfaceHandle<fuchsia::sys::ServiceProvider>
                   parent_environment_service_provider,
               fidl::InterfaceHandle<fuchsia::modular::ContextWriter>
                   accessibility_context_writer,
               zx_handle_t vsync_event_handle);

  ~PlatformView();

  void UpdateViewportMetrics(const fuchsia::ui::gfx::Metrics& metrics);

 private:
  const std::string debug_label_;

  fidl::Binding<fuchsia::ui::scenic::SessionListener> session_listener_binding_;
  fit::closure session_listener_error_callback_;
  OnMetricsUpdate metrics_changed_callback_;
  OnSizeChangeHint size_change_hint_callback_;

  int current_text_input_client_ = 0;
  fidl::Binding<fuchsia::ui::input::InputMethodEditorClient> ime_client_;
  fuchsia::ui::input::InputMethodEditorPtr ime_;
  fuchsia::ui::input::ImeServicePtr text_sync_service_;

  fuchsia::sys::ServiceProviderPtr parent_environment_service_provider_;
  fuchsia::modular::ClipboardPtr clipboard_;
  ContextWriterBridge context_writer_bridge_;
  std::unique_ptr<Surface> surface_;
  flutter::LogicalMetrics metrics_;
  fuchsia::ui::gfx::Metrics scenic_metrics_;
  // last_text_state_ is the last state of the text input as reported by the IME
  // or initialized by Flutter. We set it to null if Flutter doesn't want any
  // input, since then there is no text input state at all.
  std::unique_ptr<fuchsia::ui::input::TextInputState> last_text_state_;

  std::set<int> down_pointers_;
  std::map<
      std::string /* channel */,
      fit::function<void(
          fml::RefPtr<flutter::PlatformMessage> /* message */)> /* handler */>
      platform_message_handlers_;
  zx_handle_t vsync_event_handle_ = 0;

  void RegisterPlatformMessageHandlers();

  void FlushViewportMetrics();

  // Called when the view's properties have changed.
  void OnPropertiesChanged(
      const fuchsia::ui::gfx::ViewProperties& view_properties);

  // |fuchsia::ui::input::InputMethodEditorClient|
  void DidUpdateState(
      fuchsia::ui::input::TextInputState state,
      std::unique_ptr<fuchsia::ui::input::InputEvent> event) override;

  // |fuchsia::ui::input::InputMethodEditorClient|
  void OnAction(fuchsia::ui::input::InputMethodAction action) override;

  // |fuchsia::ui::scenic::SessionListener|
  void OnScenicError(std::string error) override;
  void OnScenicEvent(std::vector<fuchsia::ui::scenic::Event> events) override;

  void OnChildViewConnected(scenic::ResourceId view_holder_id);
  void OnChildViewDisconnected(scenic::ResourceId view_holder_id);
  void OnChildViewStateChanged(scenic::ResourceId view_holder_id, bool state);

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

  // |flutter::PlatformView|
  std::unique_ptr<flutter::VsyncWaiter> CreateVSyncWaiter() override;

  // |flutter::PlatformView|
  std::unique_ptr<flutter::Surface> CreateRenderingSurface() override;

  // |flutter::PlatformView|
  void HandlePlatformMessage(
      fml::RefPtr<flutter::PlatformMessage> message) override;

  // |flutter::PlatformView|
  void UpdateSemantics(
      flutter::SemanticsNodeUpdates update,
      flutter::CustomAccessibilityActionUpdates actions) override;

  // Channel handler for kAccessibilityChannel. This is currently not
  // being used, but it is necessary to handle accessibility messages
  // that are sent by Flutter when semantics is enabled.
  void HandleAccessibilityChannelPlatformMessage(
      fml::RefPtr<flutter::PlatformMessage> message);

  // Channel handler for kFlutterPlatformChannel
  void HandleFlutterPlatformChannelPlatformMessage(
      fml::RefPtr<flutter::PlatformMessage> message);

  // Channel handler for kTextInputChannel
  void HandleFlutterTextInputChannelPlatformMessage(
      fml::RefPtr<flutter::PlatformMessage> message);

  FML_DISALLOW_COPY_AND_ASSIGN(PlatformView);
};

}  // namespace flutter_runner

#endif  // TOPAZ_RUNTIME_FLUTTER_RUNNER_PLATFORM_VIEW_H_
