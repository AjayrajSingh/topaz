// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include <memory>

#include "lib/app/cpp/application_context.h"
#include "lib/app/cpp/connect.h"
#include "lib/app_driver/cpp/app_driver.h"
#include "lib/fidl/cpp/bindings/binding_set.h"
#include "lib/fidl/cpp/bindings/interface_request.h"
#include "lib/fsl/tasks/message_loop.h"
#include "lib/fxl/logging.h"
#include "lib/fxl/macros.h"
#include "lib/module/fidl/module.fidl.h"
#include "lib/module/fidl/module_context.fidl.h"
#include "lib/suggestion/fidl/proposal.fidl.h"
#include "lib/suggestion/fidl/proposal_publisher.fidl.h"
#include "peridot/lib/fidl/single_service_app.h"
#include "peridot/lib/fidl/view_host.h"
#include "peridot/lib/rapidjson/rapidjson.h"

namespace {

constexpr char kSuggestion[] = "http://schema.domokit.org/suggestion";
constexpr char kProposalId[] = "suggest_shell_controller#proposal";

// A Module that serves as the view controller in the suggest shell
// story, i.e. that creates the module that shows the UI.
class ControllerApp : public modular::SingleServiceApp<modular::Module>,
                      modular::LinkWatcher {
 public:
  ControllerApp(app::ApplicationContext* const application_context)
      : SingleServiceApp(application_context), link_watcher_binding_(this) {}

  ~ControllerApp() override = default;

 private:
  // |SingleServiceApp|
  void CreateView(
      f1dl::InterfaceRequest<mozart::ViewOwner> view_owner_request,
      f1dl::InterfaceRequest<app::ServiceProvider> /*services*/) override {
    view_ = std::make_unique<modular::ViewHost>(
        application_context()
            ->ConnectToEnvironmentService<mozart::ViewManager>(),
        std::move(view_owner_request));

    for (auto& view_owner : child_views_) {
      view_->ConnectView(std::move(view_owner));
    }

    child_views_.clear();
  }

  void ConnectView(f1dl::InterfaceHandle<mozart::ViewOwner> view_owner) {
    if (view_) {
      view_->ConnectView(std::move(view_owner));
    } else {
      child_views_.emplace_back(std::move(view_owner));
    }
  }

  // |Module|
  void Initialize(
      f1dl::InterfaceHandle<modular::ModuleContext> module_context,
      f1dl::InterfaceRequest<app::ServiceProvider> /*outgoing_services*/)
      override {
    module_context_.Bind(std::move(module_context));

    constexpr char kViewLink[] = "view";
    module_context_->GetLink(kViewLink, view_link_.NewRequest());
    view_link_->Watch(link_watcher_binding_.NewBinding());

    f1dl::InterfaceHandle<mozart::ViewOwner> view;
    module_context_->StartModuleDeprecated(
        "suggest_shell_view", "suggest_shell_view", kViewLink, nullptr,
        view_module_.NewRequest(), view.NewRequest());

    ConnectView(std::move(view));

    application_context()->ConnectToEnvironmentService(
        proposal_publisher_.NewRequest());
  }

  // |LinkWatcher|
  void Notify(const f1dl::String& json) override {
    rapidjson::Document doc;
    doc.Parse(json);
    FXL_CHECK(!doc.HasParseError());
    FXL_LOG(INFO) << "ControllerApp::Notify() "
                  << modular::JsonValueToPrettyString(doc);

    if (doc.IsNull()) {
      return;
    }

    if (!doc.IsObject()) {
      return;
    }

    if (!doc.HasMember(kSuggestion)) {
      return;
    }

    const std::string suggestion = doc[kSuggestion].GetString();

    auto create_story = maxwell::CreateStory::New();
    create_story->module_id = suggestion;

    auto action = maxwell::Action::New();
    action->set_create_story(std::move(create_story));

    // No field in SuggestionDisplay is optional, so we have to fill
    // them all.
    auto suggestion_display = maxwell::SuggestionDisplay::New();
    suggestion_display->headline = "Start a story with a new module";
    suggestion_display->subheadline = suggestion;
    suggestion_display->color = 0xffff0000;

    auto proposal = maxwell::Proposal::New();
    proposal->id = kProposalId;
    proposal->display = std::move(suggestion_display);
    proposal->on_selected.push_back(std::move(action));

    proposal_publisher_->Propose(std::move(proposal));
  }

  std::unique_ptr<modular::ViewHost> view_;
  std::vector<f1dl::InterfaceHandle<mozart::ViewOwner>> child_views_;

  modular::ModuleContextPtr module_context_;

  modular::ModuleControllerPtr view_module_;
  modular::LinkPtr view_link_;

  f1dl::Binding<modular::LinkWatcher> link_watcher_binding_;
  maxwell::ProposalPublisherPtr proposal_publisher_;

  FXL_DISALLOW_COPY_AND_ASSIGN(ControllerApp);
};

}  // namespace

int main(int /*argc*/, const char** /*argv*/) {
  fsl::MessageLoop loop;

  auto app_context = app::ApplicationContext::CreateFromStartupInfo();
  modular::AppDriver<ControllerApp> driver(
      app_context->outgoing_services(),
      std::make_unique<ControllerApp>(app_context.get()),
      [&loop] { loop.QuitNow(); });

  loop.Run();
  return 0;
}
