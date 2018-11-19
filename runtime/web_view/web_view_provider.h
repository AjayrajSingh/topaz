// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef TOPAZ_RUNTIME_WEB_VIEW_WEB_VIEW_PROVIDER_H_
#define TOPAZ_RUNTIME_WEB_VIEW_WEB_VIEW_PROVIDER_H_

#include <fuchsia/modular/cpp/fidl.h>
#include <fuchsia/ui/app/cpp/fidl.h>
#include <fuchsia/ui/viewsv1/cpp/fidl.h>
#include <lib/async-loop/cpp/loop.h>

#include "lib/component/cpp/startup_context.h"
#include "topaz/runtime/web_view/web_view_impl.h"

class WebViewProvider : fuchsia::ui::app::ViewProvider,
                        fuchsia::ui::viewsv1::ViewProvider,
                        fuchsia::modular::Lifecycle,
                        fuchsia::modular::LinkWatcher {
 public:
  WebViewProvider(async::Loop* loop, const std::string url);

 private:
  // |ViewProvider|
  void CreateView(
      zx::eventpair view_token,
      fidl::InterfaceRequest<fuchsia::sys::ServiceProvider> incoming_services,
      fidl::InterfaceHandle<fuchsia::sys::ServiceProvider> outgoing_services)
      override;

  // |ViewProvider|
  void CreateView(fidl::InterfaceRequest<fuchsia::ui::viewsv1token::ViewOwner>
                      view_owner_request,
                  fidl::InterfaceRequest<fuchsia::sys::ServiceProvider>
                      view_services) override;

  // fuchsia::modular::Terminate
  void Terminate() final;

  // fuchsia::modular::LinkWatcher
  void Notify(fuchsia::mem::Buffer json) final;

  async::Loop* const loop_;
  std::string url_;
  std::unique_ptr<component::StartupContext> context_;
  std::unique_ptr<WebViewImpl> view_;
  // Link state, used to gather URL updates for the story
  fuchsia::modular::LinkPtr main_link_;
  fidl::Binding<fuchsia::ui::viewsv1::ViewProvider> old_view_provider_binding_;
  fidl::Binding<fuchsia::ui::app::ViewProvider> view_provider_binding_;
  fidl::Binding<fuchsia::modular::Lifecycle> lifecycle_binding_;
  fidl::Binding<fuchsia::modular::LinkWatcher> main_link_watcher_binding_;
  fuchsia::modular::ModuleContextPtr module_context_;

#ifdef EXPERIMENTAL_WEB_ENTITY_EXTRACTION
  fuchsia::modular::ContextWriterPtr context_writer_;
  fuchsia::modular::ComponentContextPtr component_context_;
#endif
};

#endif  // TOPAZ_RUNTIME_WEB_VIEW_WEB_VIEW_PROVIDER_H_
