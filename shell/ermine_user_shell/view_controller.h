// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef TOPAZ_SHELL_ERMINE_USER_SHELL_VIEW_CONTROLLER_H_
#define TOPAZ_SHELL_ERMINE_USER_SHELL_VIEW_CONTROLLER_H_

#include <lib/async/cpp/auto_task.h>

#include <functional>
#include <memory>
#include <vector>

#include "lib/app/cpp/application_context.h"
#include "lib/fidl/cpp/bindings/binding.h"
#include "lib/fidl/cpp/bindings/interface_request.h"
#include "lib/ui/input/fidl/input_connection.fidl.h"
#include "lib/ui/scenic/client/resources.h"
#include "lib/ui/scenic/client/session.h"
#include "lib/ui/scenic/fidl/events.fidl.h"
#include "lib/ui/views/fidl/view_manager.fidl.h"
#include "lib/ui/views/fidl/views.fidl.h"

namespace ermine_user_shell {
class Tile;

class ViewController : public mozart::ViewListener,
                       public mozart::ViewContainerListener,
                       public mozart::InputListener {
 public:
  using DisconnectCallback = std::function<void(ViewController*)>;

  ViewController(component::ApplicationLauncher* launcher,
                 views_v1::ViewManagerPtr view_manager,
                 f1dl::InterfaceRequest<views_v1_token::ViewOwner> view_owner_request,
                 DisconnectCallback disconnect_handler);
  ~ViewController();

  uint32_t AddTile(std::string url);
  zx_status_t RemoveTile(uint32_t key);

 private:
  ViewController(const ViewController&) = delete;
  ViewController& operator=(const ViewController&) = delete;

  bool has_logical_size() const {
    return logical_size_.width > 0.f && logical_size_.height > 0.f;
  }

  // |mozart::ViewListener|:
  void OnPropertiesChanged(
      views_v1::ViewProperties properties,
      const OnPropertiesChangedCallback& callback) override;

  // |mozart::ViewContainerListener|:
  void OnChildAttached(uint32_t child_key,
                       mozart::ViewInfoPtr child_view_info,
                       const OnChildAttachedCallback& callback) override;
  void OnChildUnavailable(uint32_t child_key,
                          const OnChildUnavailableCallback& callback) override;

  // |mozart::InputListener|:
  void OnEvent(input::InputEvent event,
               const OnEventCallback& callback) override;

  void OnSessionEvents(f1dl::VectorPtr<ui::EventPtr> events);
  void UpdatePhysicalSize();

  void MarkNeedsLayout();
  void RequestBeginFrame();
  void BeginFrame(zx_time_t presentation_time);
  void Present(zx_time_t presentation_time);

  void PerformLayout();
  void SetPropertiesIfNeeded(Tile* tile, views_v1::ViewProperties properties);

  component::ApplicationLauncher* launcher_;
  views_v1::ViewManagerPtr view_manager_;
  f1dl::Binding<ViewListener> view_listener_binding_;
  f1dl::Binding<ViewContainerListener> view_container_listener_binding_;
  f1dl::Binding<InputListener> input_listener_binding_;

  mozart::ViewPtr view_;
  mozart::ViewContainerPtr view_container_;
  component::ServiceProviderPtr view_service_provider_;
  mozart::InputConnectionPtr input_connection_;

  mozart::SizeF logical_size_;
  mozart::Size physical_size_;
  ui::gfx::Metrics metrics_;

  scenic_lib::Session session_;
  scenic_lib::ImportNode parent_node_;
  scenic_lib::EntityNode container_node_;

  std::vector<std::unique_ptr<Tile>> tiles_;

  async::AutoTask begin_frame_task_;
  bool needs_layout_ = false;
  bool needs_begin_frame_ = false;
  bool present_pending_ = false;

  zx_time_t last_presentation_time_ = 0;
};

}  // namespace ermine_user_shell

#endif  // TOPAZ_SHELL_ERMINE_USER_SHELL_VIEW_CONTROLLER_H_
