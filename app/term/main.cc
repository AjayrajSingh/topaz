// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include <trace-provider/provider.h>

#include "examples/ui/lib/skia_font_loader.h"
#include "lib/fsl/tasks/message_loop.h"
#include "lib/fxl/functional/make_copyable.h"
#include "lib/fxl/log_settings_command_line.h"
#include "lib/fxl/logging.h"
#include "lib/ui/view_framework/view_provider_service.h"
#include "topaz/app/term/term_params.h"
#include "topaz/app/term/term_view.h"

namespace term {

class App {
 public:
  App(TermParams params)
      : params_(std::move(params)),
        application_context_(app::ApplicationContext::CreateFromStartupInfo()),
        view_provider_service_(application_context_.get(),
                               [this](mozart::ViewContext view_context) {
                                 return MakeView(std::move(view_context));
                               }) {}

  ~App() = default;

 private:
  std::unique_ptr<term::TermView> MakeView(mozart::ViewContext view_context) {
    return std::make_unique<term::TermView>(
        std::move(view_context.view_manager),
        std::move(view_context.view_owner_request),
        view_context.application_context, params_);
  }

  TermParams params_;
  std::unique_ptr<app::ApplicationContext> application_context_;
  mozart::ViewProviderService view_provider_service_;

  FXL_DISALLOW_COPY_AND_ASSIGN(App);
};

}  // namespace term

int main(int argc, const char** argv) {
  srand(zx_clock_get(ZX_CLOCK_UTC));

  auto command_line = fxl::CommandLineFromArgcArgv(argc, argv);
  term::TermParams params;
  if (!fxl::SetLogSettingsFromCommandLine(command_line) ||
      !params.Parse(command_line)) {
    FXL_LOG(ERROR) << "Missing or invalid parameters. See README.";
    return 1;
  }

  fsl::MessageLoop loop;
  trace::TraceProvider trace_provider(loop.async());

  term::App app(std::move(params));
  loop.Run();
  return 0;
}
