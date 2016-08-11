// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include <mojo/system/main.h>

#include <utility>

#include "apps/dart_content_handler/content_handler_impl.h"
#include "apps/dart_content_handler/dart_init.h"
#include "lib/ftl/macros.h"
#include "mojo/public/cpp/application/application_impl_base.h"
#include "mojo/public/cpp/application/run_application.h"
#include "mojo/public/cpp/application/service_provider_impl.h"
#include "mojo/services/content_handler/interfaces/content_handler.mojom.h"

namespace dart_content_handler {
namespace {

class App : public mojo::ApplicationImplBase {
 public:
  App() {}
  ~App() override {}

  void OnInitialize() override { InitDartVM(); }

  bool OnAcceptConnection(
      mojo::ServiceProviderImpl* service_provider_impl) override {
    service_provider_impl->AddService<mojo::ContentHandler>(
        [](const mojo::ConnectionContext& connection_context,
           mojo::InterfaceRequest<mojo::ContentHandler> request) {
          new ContentHandlerImpl(std::move(request));
        });
    return true;
  }

 private:
  FTL_DISALLOW_COPY_AND_ASSIGN(App);
};

}  // namespace
}  // dart_content_handler

MojoResult MojoMain(MojoHandle request) {
  dart_content_handler::App app;
  return mojo::RunApplication(request, &app);
}
