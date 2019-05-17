// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "topaz/tests/web_runner_tests/web_context.h"

#include <gtest/gtest.h>
#include <lib/fdio/directory.h>
#include <src/lib/fxl/logging.h>
#include <zircon/status.h>

WebContext::WebContext(sys::ComponentContext* component_context) {
  auto web_context_provider =
      component_context->svc()->Connect<fuchsia::web::ContextProvider>();
  web_context_provider.set_error_handler([](zx_status_t status) {
    FAIL() << "web_context_provider: " << zx_status_get_string(status);
  });

  auto incoming_service_clone = component_context->svc()->CloneChannel();
  FXL_CHECK(incoming_service_clone.is_valid());
  fuchsia::web::CreateContextParams params;
  params.set_service_directory(std::move(incoming_service_clone));

  web_context_provider->Create(std::move(params), web_context_.NewRequest());
  web_context_.set_error_handler([](zx_status_t status) {
    FAIL() << "web_context_: " << zx_status_get_string(status);
  });

  web_context_->CreateFrame(web_frame_.NewRequest());
  web_frame_.set_error_handler([](zx_status_t status) {
    FAIL() << "web_frame_: " << zx_status_get_string(status);
  });
}

void WebContext::Navigate(const std::string& url) {
  // By creating a new NavigationController for each Navigate() call, we
  // implicitly ensure that any preceding calls to the Frame must have executed
  // before LoadUrl() is handled.
  fuchsia::web::NavigationControllerPtr navigation;
  web_frame_->GetNavigationController(navigation.NewRequest());
  navigation->LoadUrl(url, fuchsia::web::LoadUrlParams(),
                      [](fuchsia::web::NavigationController_LoadUrl_Result) {});
}
