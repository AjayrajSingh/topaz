// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include <utility>

#include "apps/dart_content_handler/application_runner_impl.h"
#include "apps/dart_content_handler/dart_init.h"
#include "apps/modular/lib/app/application_context.h"
#include "apps/modular/lib/app/connect.h"
#include "apps/modular/services/application/application_runner.fidl.h"
#include "lib/ftl/macros.h"
#include "lib/mtl/tasks/message_loop.h"

namespace dart_content_handler {
namespace {

class App {
 public:
  App() : context_(modular::ApplicationContext::CreateFromStartupInfo()) {
    InitDartVM();
    context_->outgoing_services()->AddService<modular::ApplicationRunner>(
        [this](fidl::InterfaceRequest<modular::ApplicationRunner> app_runner) {
          new ApplicationRunnerImpl(std::move(app_runner));
        });
  }

 private:
  std::unique_ptr<modular::ApplicationContext> context_;
  FTL_DISALLOW_COPY_AND_ASSIGN(App);
};

}  // namespace
}  // dart_content_handler

int main(int argc, const char** argv) {
  mtl::MessageLoop loop;
  dart_content_handler::App app;
  loop.Run();
  return 0;
}
