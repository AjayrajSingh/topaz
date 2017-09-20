// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#pragma once

#include "apps/modular/services/lifecycle/lifecycle.fidl.h"
#include "apps/modular/services/module/module.fidl.h"
#include "apps/modular/services/story/link.fidl.h"
#include "topaz/runtime/web_view/web_view_impl.h"
#include "lib/ui/views/fidl/view_provider.fidl.h"
#include "lib/app/fidl/service_provider.fidl.h"
#include "lib/app/cpp/application_context.h"

class WebViewProvider : mozart::ViewProvider,
                        modular::Module,
                        modular::Lifecycle,
                        modular::LinkWatcher
{
 public:
  WebViewProvider(const std::string url);

 private:
  // |ViewProvider|
  void CreateView(
      fidl::InterfaceRequest<mozart::ViewOwner> view_owner_request,
      fidl::InterfaceRequest<app::ServiceProvider> view_services) override;

  // modular::Module
  void Initialize(
      fidl::InterfaceHandle<modular::ModuleContext> context,
      fidl::InterfaceHandle<app::ServiceProvider> incoming_services,
      fidl::InterfaceRequest<app::ServiceProvider> outgoing_services) final;

  // modular::Terminate
  void Terminate() final;

  // modular::LinkWatcher
  void Notify(const fidl::String& json) final;

  std::string url_;
  std::unique_ptr<app::ApplicationContext> context_;
  std::unique_ptr<WebViewImpl> view_;
  // Link state, used to gather URL updates for the story
  modular::LinkPtr main_link_;
  fidl::Binding<ViewProvider> view_provider_binding_;
  fidl::Binding<modular::Module> module_binding_;
  fidl::Binding<modular::Lifecycle> lifecycle_binding_;
  fidl::Binding<modular::LinkWatcher> main_link_watcher_binding_;

  maxwell::ContextWriterPtr context_writer_;
};


