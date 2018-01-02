// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#pragma once

#include "lib/app/cpp/application_context.h"
#include "lib/app/fidl/service_provider.fidl.h"
#include "lib/component/fidl/component_context.fidl.h"
#include "lib/lifecycle/fidl/lifecycle.fidl.h"
#include "lib/module/fidl/module.fidl.h"
#include "lib/story/fidl/link.fidl.h"
#include "lib/ui/views/fidl/view_provider.fidl.h"
#include "topaz/runtime/web_view/web_view_impl.h"

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
      f1dl::InterfaceRequest<mozart::ViewOwner> view_owner_request,
      f1dl::InterfaceRequest<app::ServiceProvider> view_services) override;

  // modular::Module
  void Initialize(
      f1dl::InterfaceHandle<modular::ModuleContext> context,
      f1dl::InterfaceRequest<app::ServiceProvider> outgoing_services) final;

  // modular::Terminate
  void Terminate() final;

  // modular::LinkWatcher
  void Notify(const f1dl::String& json) final;

  std::string url_;
  std::unique_ptr<app::ApplicationContext> context_;
  std::unique_ptr<WebViewImpl> view_;
  // Link state, used to gather URL updates for the story
  modular::LinkPtr main_link_;
  f1dl::Binding<ViewProvider> view_provider_binding_;
  f1dl::Binding<modular::Module> module_binding_;
  f1dl::Binding<modular::Lifecycle> lifecycle_binding_;
  f1dl::Binding<modular::LinkWatcher> main_link_watcher_binding_;

#ifdef EXPERIMENTAL_WEB_ENTITY_EXTRACTION
  maxwell::ContextWriterPtr context_writer_;
  modular::ComponentContextPtr component_context_;
#endif
};


