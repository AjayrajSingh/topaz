// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "topaz/bin/user_shell/ermine_user_shell/tile.h"

#include <utility>

#include <views_v1/cpp/fidl.h>

#include "lib/svc/cpp/services.h"

namespace ermine_user_shell {
namespace {

uint32_t g_next_key = 1;

}  // namespace

Tile::Tile(component::ApplicationLauncher* launcher, std::string url,
           scenic_lib::Session* session)
    : launcher_(launcher),
      url_(std::move(url)),
      key_(g_next_key++),
      node_(session) {}

Tile::~Tile() = default;

void Tile::CreateView(
    fidl::InterfaceRequest<views_v1_token::ViewOwner> view_owner_request) {
  component::Services services;
  component::ApplicationLaunchInfo launch_info;
  launch_info.url = url_;
  launch_info.directory_request = services.NewRequest();

  launcher_->CreateApplication(std::move(launch_info),
                               controller_.NewRequest());

  auto view_provider = services.ConnectToService<views_v1::ViewProvider>();
  view_provider->CreateView(std::move(view_owner_request), nullptr);
}

}  // namespace ermine_user_shell
