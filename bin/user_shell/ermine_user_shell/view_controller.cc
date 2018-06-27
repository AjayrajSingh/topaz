// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "topaz/bin/user_shell/ermine_user_shell/view_controller.h"

#include <lib/async/default.h>

#include <algorithm>
#include <utility>

#include "lib/app/cpp/connect.h"
#include "lib/fidl/cpp/clone.h"
#include "lib/fidl/cpp/optional.h"
#include "topaz/bin/user_shell/ermine_user_shell/find_unique_ptr.h"
#include "topaz/bin/user_shell/ermine_user_shell/tile.h"

namespace ermine_user_shell {
namespace {

constexpr char kViewLabel[] = "ermine_user_shell";

fuchsia::ui::scenic::ScenicPtr GetScenic(
    fuchsia::ui::views_v1::ViewManager* view_manager) {
  fuchsia::ui::scenic::ScenicPtr scenic;
  view_manager->GetScenic(scenic.NewRequest());
  return scenic;
}

const fuchsia::ui::gfx::Metrics* GetLastMetrics(
    uint32_t node_id,
    const fidl::VectorPtr<fuchsia::ui::scenic::Event>& events) {
  const fuchsia::ui::gfx::Metrics* result = nullptr;
  for (const auto& event : *events) {
    if (event.is_gfx() && event.gfx().is_metrics() &&
        event.gfx().metrics().node_id == node_id)
      result = &event.gfx().metrics().metrics;
  }
  return result;
}

fuchsia::ui::views_v1::ViewProperties CreateViewProperties(float width,
                                                           float height) {
  fuchsia::ui::views_v1::ViewProperties properties;
  properties.view_layout = fuchsia::ui::views_v1::ViewLayout::New();
  properties.view_layout->size.width = width;
  properties.view_layout->size.height = height;
  return properties;
}

}  // namespace

ViewController::ViewController(
    fuchsia::sys::Launcher* launcher,
    fuchsia::ui::views_v1::ViewManagerPtr view_manager,
    fidl::InterfaceRequest<fuchsia::ui::views_v1_token::ViewOwner>
        view_owner_request,
    DisconnectCallback disconnect_handler)
    : launcher_(launcher),
      view_manager_(std::move(view_manager)),
      view_listener_binding_(this),
      view_container_listener_binding_(this),
      input_listener_binding_(this),
      session_(GetScenic(view_manager_.get()).get()),
      parent_node_(&session_),
      container_node_(&session_),
      begin_frame_task_([this] {
        if (needs_begin_frame_)
          BeginFrame(last_presentation_time_);
      }) {
  zx::eventpair parent_export_token;
  parent_node_.BindAsRequest(&parent_export_token);
  view_manager_->CreateView(view_.NewRequest(), std::move(view_owner_request),
                            view_listener_binding_.NewBinding(),
                            std::move(parent_export_token), kViewLabel);
  view_listener_binding_.set_error_handler(
      [this, disconnect_handler = std::move(disconnect_handler)] {
        disconnect_handler(this);
      });
  view_->GetContainer(view_container_.NewRequest());
  view_container_->SetListener(view_container_listener_binding_.NewBinding());

  view_->GetServiceProvider(view_service_provider_.NewRequest());
  fuchsia::sys::ConnectToService(view_service_provider_.get(),
                                 input_connection_.NewRequest());
  input_connection_->SetEventListener(input_listener_binding_.NewBinding());

  session_.set_event_handler(
      [this](fidl::VectorPtr<fuchsia::ui::scenic::Event> events) {
        OnSessionEvents(std::move(events));
      });
  parent_node_.SetEventMask(fuchsia::ui::gfx::kMetricsEventMask);
  parent_node_.AddChild(container_node_);
}

ViewController::~ViewController() = default;

uint32_t ViewController::AddTile(std::string url) {
  tiles_.push_back(std::make_unique<Tile>(launcher_, url, &session_));
  auto& tile = tiles_.back();

  zx::eventpair token;
  tile->node().ExportAsRequest(&token);
  container_node_.AddChild(tile->node());

  fidl::InterfaceHandle<fuchsia::ui::views_v1_token::ViewOwner> view_owner;
  tile->CreateView(view_owner.NewRequest());

  view_container_->AddChild(tile->key(), std::move(view_owner),
                            std::move(token));

  MarkNeedsLayout();
  return tile->key();
}

zx_status_t ViewController::RemoveTile(uint32_t key) {
  auto it = std::find_if(tiles_.begin(), tiles_.end(), [key](const auto& tile) {
    return tile->key() == key;
  });

  if (it == tiles_.end())
    return ZX_ERR_NOT_FOUND;

  (*it)->node().Detach();
  tiles_.erase(it);
  view_container_->RemoveChild(key, nullptr);
  MarkNeedsLayout();
  return ZX_OK;
}

void ViewController::OnPropertiesChanged(
    fuchsia::ui::views_v1::ViewProperties properties,
    OnPropertiesChangedCallback callback) {
  if (properties.view_layout && logical_size_ != properties.view_layout->size) {
    logical_size_ = properties.view_layout->size;
    UpdatePhysicalSize();
    MarkNeedsLayout();
  }

  callback();
}

void ViewController::OnChildAttached(
    uint32_t child_key, fuchsia::ui::views_v1::ViewInfo child_view_info,
    OnChildAttachedCallback callback) {
  callback();
}

void ViewController::OnChildUnavailable(uint32_t child_key,
                                        OnChildUnavailableCallback callback) {
  zx_status_t status = RemoveTile(child_key);
  ZX_DEBUG_ASSERT(status == ZX_OK);
  callback();
}

void ViewController::OnEvent(fuchsia::ui::input::InputEvent event,
                             OnEventCallback callback) {
  callback(false);
}

void ViewController::OnSessionEvents(
    fidl::VectorPtr<fuchsia::ui::scenic::Event> events) {
  const fuchsia::ui::gfx::Metrics* new_metrics =
      GetLastMetrics(parent_node_.id(), events);

  if (!new_metrics || metrics_ == *new_metrics)
    return;

  metrics_ = *new_metrics;
  UpdatePhysicalSize();
  MarkNeedsLayout();
}

void ViewController::UpdatePhysicalSize() {
  physical_size_.width = logical_size_.width * metrics_.scale_x;
  physical_size_.height = logical_size_.height * metrics_.scale_y;
}

void ViewController::MarkNeedsLayout() {
  if (needs_layout_)
    return;
  needs_layout_ = true;
  RequestBeginFrame();
}

void ViewController::RequestBeginFrame() {
  if (needs_begin_frame_)
    return;
  needs_begin_frame_ = true;
  if (present_pending_ || begin_frame_task_.is_pending())
    return;
  zx_status_t status = begin_frame_task_.Post(async_get_default());
  ZX_DEBUG_ASSERT(status == ZX_OK);
}

void ViewController::BeginFrame(zx_time_t presentation_time) {
  ZX_DEBUG_ASSERT(needs_begin_frame_);
  needs_begin_frame_ = false;
  begin_frame_task_.Cancel();
  if (needs_layout_)
    PerformLayout();
  ZX_DEBUG_ASSERT(!needs_layout_);
  if (!present_pending_)
    Present(presentation_time);
}

void ViewController::Present(zx_time_t presentation_time) {
  ZX_DEBUG_ASSERT(!present_pending_);
  present_pending_ = true;
  last_presentation_time_ = presentation_time;
  session_.Present(
      presentation_time, [this](fuchsia::images::PresentationInfo info) {
        ZX_DEBUG_ASSERT(present_pending_);
        present_pending_ = false;
        if (needs_begin_frame_)
          BeginFrame(info.presentation_time + info.presentation_interval);
      });
}

void ViewController::PerformLayout() {
  ZX_DEBUG_ASSERT(needs_layout_);
  needs_layout_ = false;

  if (!has_logical_size() || tiles_.empty())
    return;

  uint32_t columns = 1;
  uint32_t rows = 1;

  while (columns * rows < tiles_.size()) {
    float dx = logical_size_.width / columns;
    float dy = logical_size_.height / rows;

    if (dx > dy)
      ++columns;
    else
      ++rows;
  }

  float dx = logical_size_.width / columns;
  float dy = logical_size_.height / rows;

  size_t i = 0;
  for (auto& tile : tiles_) {
    SetPropertiesIfNeeded(tile.get(), CreateViewProperties(dx, dy));
    uint32_t col = i % columns;
    uint32_t row = i / columns;
    tile->node().SetTranslation(col * dx, row * dy, 0u);
    ++i;
  }
}

void ViewController::SetPropertiesIfNeeded(
    Tile* tile, fuchsia::ui::views_v1::ViewProperties properties) {
  if (tile->view_properties() == properties)
    return;
  tile->set_view_properties(fidl::Clone(properties));
  view_container_->SetChildProperties(
      tile->key(), fidl::MakeOptional(std::move(properties)));
}

}  // namespace ermine_user_shell
