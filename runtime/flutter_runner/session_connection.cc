// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "session_connection.h"

#include "flutter/fml/make_copyable.h"
#include "lib/fidl/cpp/optional.h"
#include "lib/ui/scenic/cpp/commands.h"
#include "vsync_recorder.h"
#include "vsync_waiter.h"

namespace flutter {

SessionConnection::SessionConnection(
    std::string debug_label,
#ifndef SCENIC_VIEWS2
    zx::eventpair import_token,
#else
    zx::eventpair view_token,
#endif
    fidl::InterfaceHandle<fuchsia::ui::scenic::Session> session,
    fit::closure session_error_callback, zx_handle_t vsync_event_handle)
    : debug_label_(std::move(debug_label)),
      session_wrapper_(session.Bind(), nullptr),
#ifdef SCENIC_VIEWS2
      root_view_(&session_wrapper_, std::move(view_token), debug_label),
#endif
      root_node_(&session_wrapper_),
      surface_producer_(
          std::make_unique<VulkanSurfaceProducer>(&session_wrapper_)),
      scene_update_context_(&session_wrapper_, surface_producer_.get()),
      vsync_event_handle_(vsync_event_handle) {

  session_wrapper_.set_error_handler(
      [callback = std::move(session_error_callback)](zx_status_t status) {
        callback();
      });

  session_wrapper_.SetDebugName(debug_label_);

#ifndef SCENIC_VIEWS2
  root_node_.Bind(std::move(import_token));
#else
  root_view_.AddChild(root_node_);
  // TODO: move this into BaseView or ChildView
  root_node_.SetTranslation(0.f, 0.f, 0.1f);
#endif

  root_node_.SetEventMask(fuchsia::ui::gfx::kMetricsEventMask |
                          fuchsia::ui::gfx::kSizeChangeHintEventMask);

  // Signal is initially high indicating availability of the session.
  ToggleSignal(vsync_event_handle_, true);

  PresentSession();
}

SessionConnection::~SessionConnection() = default;

void SessionConnection::Present(flow::CompositorContext::ScopedFrame& frame) {
  // Flush all session ops. Paint tasks have not yet executed but those are
  // fenced. The compositor can start processing ops while we finalize paint
  // tasks.
  PresentSession();

  // Execute paint tasks and signal fences.
  auto surfaces_to_submit = scene_update_context_.ExecutePaintTasks(frame);

  // Tell the surface producer that a present has occurred so it can perform
  // book-keeping on buffer caches.
  surface_producer_->OnSurfacesPresented(std::move(surfaces_to_submit));

  // Prepare for the next frame. These ops won't be processed till the next
  // present.
  EnqueueClearOps();
}

void SessionConnection::OnSessionSizeChangeHint(float width_change_factor,
                                                float height_change_factor) {
  surface_producer_->OnSessionSizeChangeHint(width_change_factor,
                                             height_change_factor);
}

void SessionConnection::EnqueueClearOps() {
  // We are going to be sending down a fresh node hierarchy every frame. So just
  // enqueue a detach op on the imported root node.
  session_wrapper_.Enqueue(scenic::NewDetachChildrenCmd(root_node_.id()));
}

void SessionConnection::PresentSession() {
  TRACE_DURATION("gfx", "SessionConnection::PresentSession");
  TRACE_FLOW_BEGIN("gfx", "Session::Present", next_present_trace_id_);
  next_present_trace_id_++;

  ToggleSignal(vsync_event_handle_, false);
  session_wrapper_.Present(
      0,  // presentation_time. (placeholder).
      [handle = vsync_event_handle_](
          fuchsia::images::PresentationInfo presentation_info) {
        VsyncRecorder::GetInstance().UpdateVsyncInfo(presentation_info);
        ToggleSignal(handle, true);
      }  // callback
  );
}

void SessionConnection::ToggleSignal(zx_handle_t handle, bool set) {
  const auto signal = flutter::VsyncWaiter::SessionPresentSignal;
  auto status = zx_object_signal(handle,            // handle
                                 set ? 0 : signal,  // clear mask
                                 set ? signal : 0   // set mask
  );
  if (status != ZX_OK) {
    FML_LOG(ERROR) << "Could not toggle vsync signal: " << set;
  }
}

}  // namespace flutter
