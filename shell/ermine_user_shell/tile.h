// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef TOPAZ_SHELL_ERMINE_USER_SHELL_TILE_H_
#define TOPAZ_SHELL_ERMINE_USER_SHELL_TILE_H_

#include <string>
#include <utility>

#include "lib/app/fidl/application_controller.fidl.h"
#include "lib/app/fidl/application_launcher.fidl.h"
#include "lib/fidl/cpp/bindings/interface_request.h"
#include "lib/ui/scenic/client/resources.h"
#include "lib/ui/scenic/client/session.h"
#include "lib/ui/views/fidl/view_provider.fidl.h"

namespace ermine_user_shell {

class Tile {
 public:
  Tile(component::ApplicationLauncher* launcher, std::string url,
       scenic_lib::Session* session);
  ~Tile();

  Tile(const Tile&) = delete;
  Tile& operator=(const Tile&) = delete;

  uint32_t key() const { return key_; }
  scenic_lib::EntityNode& node() { return node_; }

  const mozart::ViewPropertiesPtr& view_properties() const {
    return view_properties_;
  }

  void set_view_properties(mozart::ViewPropertiesPtr view_properties) {
    view_properties_ = std::move(view_properties);
  }

  void CreateView(f1dl::InterfaceRequest<mozart::ViewOwner> view_owner_request);

 private:
  component::ApplicationLauncher* launcher_;
  std::string url_;
  component::ApplicationControllerPtr controller_;

  const uint32_t key_;
  scenic_lib::EntityNode node_;
  mozart::ViewPropertiesPtr view_properties_;
};

}  // namespace ermine_user_shell

#endif  // TOPAZ_SHELL_ERMINE_USER_SHELL_TILE_H_
