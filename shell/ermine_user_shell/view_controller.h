// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef TOPAZ_SHELL_ERMINE_USER_SHELL_VIEW_CONTROLLER_H_
#define TOPAZ_SHELL_ERMINE_USER_SHELL_VIEW_CONTROLLER_H_

#include <lib/async/cpp/task.h>

#include <functional>
#include <memory>
#include <vector>

#include <fuchsia/cpp/input.h>
#include <fuchsia/cpp/views_v1.h>

#include "lib/app/cpp/application_context.h"
#include "lib/fidl/cpp/binding.h"
#include "lib/fidl/cpp/interface_request.h"
#include "lib/ui/scenic/client/resources.h"
#include "lib/ui/scenic/client/session.h"

namespace ermine_user_shell {
class Tile;

class ViewController : public views_v1::ViewListener,
                       public views_v1::ViewContainerListener,
                       public input::InputListener {
 public:
  using DisconnectCallback = std::function<void(ViewController*)>;

  ViewController(component::ApplicationLauncher* launcher,
                 views_v1::ViewManagerPtr view_manager,
                 fidl::InterfaceRequest<views_v1_token::ViewOwner> view_owner_request,
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

  // |views_v1::ViewListener|:
  void OnPropertiesChanged(
      views_v1::ViewProperties properties,
      OnPropertiesChangedCallback callback) override;

  // |views_v1::ViewContainerListener|:
  void OnChildAttached(uint32_t child_key,
                       views_v1::ViewInfo child_view_info,
                       OnChildAttachedCallback callback) override;
  void OnChildUnavailable(uint32_t child_key,
                          OnChildUnavailableCallback callback) override;

  // |input::InputListener|:
  void OnEvent(input::InputEvent event,
               OnEventCallback callback) override;

  void OnSessionEvents(fidl::VectorPtr<ui::Event> events);
  void UpdatePhysicalSize();

  void MarkNeedsLayout();
  void RequestBeginFrame();
  void BeginFrame(zx_time_t presentation_time);
  void Present(zx_time_t presentation_time);

  void PerformLayout();
  void SetPropertiesIfNeeded(Tile* tile, views_v1::ViewProperties properties);

  component::ApplicationLauncher* launcher_;
  views_v1::ViewManagerPtr view_manager_;
  fidl::Binding<ViewListener> view_listener_binding_;
  fidl::Binding<ViewContainerListener> view_container_listener_binding_;
  fidl::Binding<InputListener> input_listener_binding_;

  views_v1::ViewPtr view_;
  views_v1::ViewContainerPtr view_container_;
  component::ServiceProviderPtr view_service_provider_;
  input::InputConnectionPtr input_connection_;

  geometry::SizeF logical_size_;
  geometry::Size physical_size_;
  gfx::Metrics metrics_;

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
