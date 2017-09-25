// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include <trace-provider/provider.h>

#include "lib/component/fidl/component_context.fidl.h"
#include "lib/lifecycle/fidl/lifecycle.fidl.h"
#include "lib/module/fidl/module.fidl.h"
#include "lib/story/fidl/story_marker.fidl.h"
#include "lib/ui/skia/skia_font_loader.h"
#include "lib/ui/view_framework/view_provider_service.h"
#include "topaz/app/moterm/history.h"
#include "topaz/app/moterm/ledger_helpers.h"
#include "topaz/app/moterm/moterm_params.h"
#include "topaz/app/moterm/moterm_view.h"
#include "lib/fxl/functional/make_copyable.h"
#include "lib/fxl/log_settings_command_line.h"
#include "lib/fxl/logging.h"
#include "lib/fsl/tasks/message_loop.h"

namespace moterm {

class App : modular::Module, modular::Lifecycle {
 public:
  App(MotermParams params)
      : params_(std::move(params)),
        application_context_(app::ApplicationContext::CreateFromStartupInfo()),
        view_provider_service_(application_context_.get(),
                               [this](mozart::ViewContext view_context) {
                                 return MakeView(std::move(view_context));
                               }),
        module_binding_(this),
        lifecycle_binding_(this) {
    application_context_->outgoing_services()->AddService<modular::Module>(
        [this](fidl::InterfaceRequest<modular::Module> request) {
          FXL_DCHECK(!module_binding_.is_bound());
          module_binding_.Bind(std::move(request));
        });
    application_context_->outgoing_services()->AddService<modular::Lifecycle>(
      [this](fidl::InterfaceRequest<modular::Lifecycle> request) {
        FXL_DCHECK(!lifecycle_binding_.is_bound());
        lifecycle_binding_.Bind(std::move(request));
      });

    // TODO(ppi): drop this once FW-97 is fixed or moterm no longer supports
    // view provider service.
    story_marker_ = application_context_
                        ->ConnectToEnvironmentService<modular::StoryMarker>();
    story_marker_.set_connection_error_handler([this] {
      history_.Initialize(nullptr);
      story_marker_.reset();
    });
  }

  ~App() {}

  // |modular::Module|
  void Initialize(
      fidl::InterfaceHandle<modular::ModuleContext> module_context_handle,
      fidl::InterfaceHandle<app::ServiceProvider> incoming_services,
      fidl::InterfaceRequest<app::ServiceProvider> outgoing_services) override {
    fidl::InterfacePtr<modular::ModuleContext> module_context;
    module_context.Bind(std::move(module_context_handle));

    modular::ComponentContextPtr component_context;
    modular::ModuleContext* module_context_ptr = module_context.get();
    module_context_ptr->GetComponentContext(component_context.NewRequest());
    modular::ComponentContext* component_context_ptr = component_context.get();

    ledger::LedgerPtr ledger;
    component_context_ptr->GetLedger(
        ledger.NewRequest(),
        fxl::MakeCopyable([module_context = std::move(module_context)](
            ledger::Status status) { LogLedgerError(status, "GetLedger"); }));

    ledger::PagePtr history_page;
    ledger::Ledger* ledger_ptr = ledger.get();
    ledger_ptr->GetRootPage(
        history_page.NewRequest(),
        fxl::MakeCopyable([ledger = std::move(ledger)](ledger::Status status) {
          LogLedgerError(status, "GetRootPage");
        }));

    story_marker_.reset();
    history_.Initialize(std::move(history_page));
  }

  // |modular::Lifecycle|
  void Terminate() override {
    fsl::MessageLoop::GetCurrent()->QuitNow();
  }

 private:
  std::unique_ptr<moterm::MotermView> MakeView(
      mozart::ViewContext view_context) {
    return std::make_unique<moterm::MotermView>(
        std::move(view_context.view_manager),
        std::move(view_context.view_owner_request),
        view_context.application_context, &history_, params_);
  }

  MotermParams params_;
  std::unique_ptr<app::ApplicationContext> application_context_;
  modular::StoryMarkerPtr story_marker_;
  mozart::ViewProviderService view_provider_service_;
  fidl::Binding<modular::Module> module_binding_;
  fidl::Binding<modular::Lifecycle> lifecycle_binding_;
  // Ledger-backed store for terminal history.
  History history_;

  FXL_DISALLOW_COPY_AND_ASSIGN(App);
};

}  // namespace moterm

int main(int argc, const char** argv) {
  srand(zx_time_get(ZX_CLOCK_UTC));

  auto command_line = fxl::CommandLineFromArgcArgv(argc, argv);
  moterm::MotermParams params;
  if (!fxl::SetLogSettingsFromCommandLine(command_line) ||
      !params.Parse(command_line)) {
    FXL_LOG(ERROR) << "Missing or invalid parameters. See README.";
    return 1;
  }

  fsl::MessageLoop loop;
  trace::TraceProvider trace_provider(loop.async());

  moterm::App app(std::move(params));
  loop.Run();
  return 0;
}
