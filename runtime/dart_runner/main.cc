// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include <utility>

#include "lib/app/cpp/application_context.h"
#include "lib/app/cpp/connect.h"
#include "lib/app/fidl/application_runner.fidl.h"
#include "apps/dart_content_handler/application_runner_impl.h"
#include "lib/fxl/macros.h"
#include "lib/fsl/tasks/message_loop.h"

namespace dart_content_handler {
namespace {

class App {
 public:
  App() : context_(app::ApplicationContext::CreateFromStartupInfo()) {
    context_->outgoing_services()->AddService<app::ApplicationRunner>(
        [this](fidl::InterfaceRequest<app::ApplicationRunner> app_runner) {
          new ApplicationRunnerImpl(std::move(app_runner));
        });
  }

 private:
  std::unique_ptr<app::ApplicationContext> context_;
  FXL_DISALLOW_COPY_AND_ASSIGN(App);
};

}  // namespace
}  // namespace dart_content_handler

int main(int argc, const char** argv) {
  fsl::MessageLoop loop;
  dart_content_handler::App app;
  loop.Run();
  return 0;
}
