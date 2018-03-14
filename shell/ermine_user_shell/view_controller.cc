// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "topaz/shell/ermine_user_shell/view_controller.h"

#include <lib/async/default.h>

#include <algorithm>
#include <utility>

#include "lib/app/cpp/connect.h"
#include "topaz/shell/ermine_user_shell/find_unique_ptr.h"
#include "topaz/shell/ermine_user_shell/tile.h"

namespace ermine_user_shell {
namespace {

constexpr char kViewLabel[] = "ermine_user_shell";

ui::ScenicPtr GetScenic(mozart::ViewManager* view_manager) {
  ui::ScenicPtr mozart;
  view_manager->GetScenic(mozart.NewRequest());
  return mozart;
}

scenic::Metrics* GetLastMetrics(
    uint32_t node_id,
    const f1dl::Array<ui::EventPtr>& events) {
  scenic::Metrics* result = nullptr;
  for (const auto& event : events) {
    if (event->is_scenic() && event->get_scenic()->is_metrics() &&
        event->get_scenic()->get_metrics()->node_id == node_id)
      result = event->get_scenic()->get_metrics()->metrics.get();
  }
  return result;
}

mozart::ViewPropertiesPtr CreateViewProperties(float width, float height) {
  auto properties = mozart::ViewProperties::New();
  properties->view_layout = mozart::ViewLayout::New();
  properties->view_layout->size = mozart::SizeF::New();
  properties->view_layout->size->width = width;
  properties->view_layout->size->height = height;
  properties->view_layout->inset = mozart::InsetF::New();
  return properties;
}

}  // namespace

ViewController::ViewController(
    app::ApplicationLauncher* launcher,
    mozart::ViewManagerPtr view_manager,
    f1dl::InterfaceRequest<mozart::ViewOwner> view_owner_request,
    DisconnectCallback disconnect_handler)
    : launcher_(launcher),
      view_manager_(std::move(view_manager)),
      view_listener_binding_(this),
      view_container_listener_binding_(this),
      input_listener_binding_(this),
      session_(GetScenic(view_manager_.get()).get()),
      parent_node_(&session_),
      container_node_(&session_),
      begin_frame_task_(async_get_default(), 0u) {
  begin_frame_task_.set_handler([this](async_t* async, zx_status_t status) {
    if (status == ZX_OK && needs_begin_frame_)
      BeginFrame(last_presentation_time_);
    return ASYNC_TASK_FINISHED;
  });

  zx::eventpair parent_export_token;
  parent_node_.BindAsRequest(&parent_export_token);
  view_manager_->CreateView(view_.NewRequest(), std::move(view_owner_request),
                            view_listener_binding_.NewBinding(),
                            std::move(parent_export_token), kViewLabel);
  view_listener_binding_.set_error_handler(
      [this, disconnect_handler] { disconnect_handler(this); });
  view_->GetContainer(view_container_.NewRequest());
  view_container_->SetListener(view_container_listener_binding_.NewBinding());

  view_->GetServiceProvider(view_service_provider_.NewRequest());
  app::ConnectToService(view_service_provider_.get(),
                        input_connection_.NewRequest());
  input_connection_->SetEventListener(input_listener_binding_.NewBinding());

  session_.set_event_handler([this](f1dl::Array<ui::EventPtr> events) {
    OnSessionEvents(std::move(events));
  });
  parent_node_.SetEventMask(scenic::kMetricsEventMask);
  parent_node_.AddChild(container_node_);
}

ViewController::~ViewController() = default;

uint32_t ViewController::AddTile(std::string url) {
  tiles_.push_back(std::make_unique<Tile>(launcher_, url, &session_));
  auto& tile = tiles_.back();

  zx::eventpair token;
  tile->node().ExportAsRequest(&token);
  container_node_.AddChild(tile->node());

  f1dl::InterfaceHandle<mozart::ViewOwner> view_owner;
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
    mozart::ViewPropertiesPtr properties,
    const OnPropertiesChangedCallback& callback) {
  if (!logical_size_.Equals(*properties->view_layout->size)) {
    logical_size_ = *properties->view_layout->size;
    UpdatePhysicalSize();
    MarkNeedsLayout();
  }

  callback();
}

void ViewController::OnChildAttached(uint32_t child_key,
                                     mozart::ViewInfoPtr child_view_info,
                                     const OnChildAttachedCallback& callback) {
  callback();
}

void ViewController::OnChildUnavailable(
    uint32_t child_key,
    const OnChildUnavailableCallback& callback) {
  zx_status_t status = RemoveTile(child_key);
  ZX_DEBUG_ASSERT(status == ZX_OK);
  callback();
}

void ViewController::OnEvent(mozart::InputEventPtr event,
                             const OnEventCallback& callback) {
  callback(false);
}

void ViewController::OnSessionEvents(f1dl::Array<ui::EventPtr> events) {
  scenic::Metrics* new_metrics = GetLastMetrics(parent_node_.id(), events);

  if (!new_metrics || metrics_.Equals(*new_metrics))
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
  zx_status_t status = begin_frame_task_.Post();
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
      presentation_time, [this](ui::PresentationInfoPtr info) {
        ZX_DEBUG_ASSERT(present_pending_);
        present_pending_ = false;
        if (needs_begin_frame_)
          BeginFrame(info->presentation_time + info->presentation_interval);
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
    Tile* tile,
    mozart::ViewPropertiesPtr properties) {
  if (tile->view_properties().Equals(properties))
    return;
  tile->set_view_properties(properties.Clone());
  view_container_->SetChildProperties(tile->key(), std::move(properties));
}

}  // namespace ermine_user_shell
