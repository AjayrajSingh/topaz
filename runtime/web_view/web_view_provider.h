// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#pragma once

#include <fuchsia/modular/cpp/fidl.h>
#include <lib/async-loop/cpp/loop.h>
#include <views_v1/cpp/fidl.h>

#include "lib/app/cpp/application_context.h"
#include "topaz/runtime/web_view/web_view_impl.h"

class WebViewProvider : views_v1::ViewProvider,
                        fuchsia::modular::Lifecycle,
                        fuchsia::modular::LinkWatcher {
 public:
  WebViewProvider(async::Loop* loop, const std::string url);

 private:
  // |ViewProvider|
  void CreateView(fidl::InterfaceRequest<views_v1_token::ViewOwner> view_owner_request,
                  fidl::InterfaceRequest<component::ServiceProvider>
                      view_services) override;

  // fuchsia::modular::Terminate
  void Terminate() final;

  // fuchsia::modular::LinkWatcher
  void Notify(fidl::StringPtr json) final;

  async::Loop* const loop_;
  std::string url_;
  std::unique_ptr<component::ApplicationContext> context_;
  std::unique_ptr<WebViewImpl> view_;
  // Link state, used to gather URL updates for the story
  fuchsia::modular::LinkPtr main_link_;
  fidl::Binding<ViewProvider> view_provider_binding_;
  fidl::Binding<fuchsia::modular::Lifecycle> lifecycle_binding_;
  fidl::Binding<fuchsia::modular::LinkWatcher> main_link_watcher_binding_;
  fuchsia::modular::ModuleContextPtr module_context_;

#ifdef EXPERIMENTAL_WEB_ENTITY_EXTRACTION
  fuchsia::modular::ContextWriterPtr context_writer_;
  fuchsia::modular::ComponentContextPtr component_context_;
#endif
};
