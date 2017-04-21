// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "apps/maxwell/src/user/user_intelligence_provider_impl.h"

#include "application/lib/app/connect.h"
#include "apps/maxwell/services/resolver/resolver.fidl.h"
#include "apps/maxwell/services/user/scope.fidl.h"
#include "apps/maxwell/src/user/intelligence_services_impl.h"
#include "apps/maxwell/src/acquirers/story_info/initializer.fidl.h"
#include "apps/network/services/network_service.fidl.h"
#include "lib/ftl/files/file.h"

namespace maxwell {

namespace {

// Calls Duplicate() on an InterfacePtr<> and returns the newly bound
// InterfaceHandle<>.
template <class T>
fidl::InterfaceHandle<T> Duplicate(const fidl::InterfacePtr<T>& ptr) {
  fidl::InterfaceHandle<T> handle;
  ptr->Duplicate(handle.NewRequest());
  return handle;
}

modular::AgentControllerPtr startStoryInfoAgent(
    modular::ComponentContext* component_context,
    fidl::InterfaceHandle<modular::StoryProvider> story_provider,
    fidl::InterfaceHandle<modular::FocusProvider> focus_provider,
    fidl::InterfaceHandle<modular::VisibleStoriesProvider>
        visible_stories_provider) {
  app::ServiceProviderPtr agent_services;
  modular::AgentControllerPtr controller;
  component_context->ConnectToAgent("file:///system/apps/acquirers/story_info_main",
      agent_services.NewRequest(), controller.NewRequest());

  auto initializer = app::ConnectToService<StoryInfoInitializer>(
      agent_services.get());
  initializer->Initialize(
      std::move(story_provider), std::move(focus_provider),
      std::move(visible_stories_provider));

  return controller;
}

}  // namespace

UserIntelligenceProviderImpl::UserIntelligenceProviderImpl(
    app::ApplicationContext* app_context,
    fidl::InterfaceHandle<modular::ComponentContext> component_context_handle,
    fidl::InterfaceHandle<modular::StoryProvider> story_provider_handle,
    fidl::InterfaceHandle<modular::FocusProvider> focus_provider_handle,
    fidl::InterfaceHandle<modular::VisibleStoriesProvider>
        visible_stories_provider_handle)
    : app_context_(app_context),
      agent_launcher_(app_context_->environment().get()) {
  component_context_.Bind(std::move(component_context_handle));
  auto story_provider =
      modular::StoryProviderPtr::Create(std::move(story_provider_handle));
  auto focus_provider =
      modular::FocusProviderPtr::Create(std::move(focus_provider_handle));
  visible_stories_provider_.Bind(std::move(visible_stories_provider_handle));

  // Start dependent processes. We get some component-scope services from
  // these processes.
  {
    app::ServiceProviderPtr context_services_ =
        startServiceProviderApp("file:///system/apps/context_engine");
    context_engine_ =
        app::ConnectToService<maxwell::ContextEngine>(context_services_.get());
  }
  suggestion_services_ =
      startServiceProviderApp("file:///system/apps/suggestion_engine");
  suggestion_engine_ = app::ConnectToService<maxwell::SuggestionEngine>(
      suggestion_services_.get());

  // Initialize the SuggestionEngine.
  suggestion_engine_->Initialize(Duplicate(story_provider),
                                 Duplicate(focus_provider));

  {
    app::ServiceProviderPtr action_log_services_ =
        startServiceProviderApp("file:///system/apps/action_log");
    action_log_factory_ = app::ConnectToService<maxwell::ActionLogFactory>(
        action_log_services_.get());
  }

  resolver_services_ =
      startServiceProviderApp("file:///system/apps/resolver_main");

  // TODO(rosswang): Search the ComponentIndex and iterate through results.
  startAgent("file:///system/apps/agents/module_suggester");
  startAgent("file:///system/apps/agents/module_suggester.dartx");
  startAgent("file:///system/apps/agents/concerts.dartx");

// TODO(jwnichols): Uncomment this when the dashboard is more functional
// startAgent("file:///system/apps/agents/mi_dashboard.dartx");

// Toggle using the "kronk_dev" gn arg (see README).
#ifdef KRONK_DEV
  startAgent("https://storage.googleapis.com/maxwell-agents/kronk-dev");
#else
  startAgent("https://storage.googleapis.com/maxwell-agents/kronk");
#endif

  // Start privileged local Framework-style Agents.
  {
    auto controller = startStoryInfoAgent(
        component_context_.get(), Duplicate(story_provider),
        Duplicate(focus_provider), Duplicate(visible_stories_provider_));
    agent_controllers_.push_back(std::move(controller));
  }
}

void UserIntelligenceProviderImpl::GetComponentIntelligenceServices(
    ComponentScopePtr scope,
    fidl::InterfaceRequest<IntelligenceServices> request) {
  intelligence_services_bindings_.AddBinding(
      std::make_unique<IntelligenceServicesImpl>(
          std::move(scope), context_engine_.get(), suggestion_engine_.get(),
          action_log_factory_.get()),
      std::move(request));
}

void UserIntelligenceProviderImpl::GetSuggestionProvider(
    fidl::InterfaceRequest<SuggestionProvider> request) {
  app::ConnectToService<SuggestionProvider>(suggestion_services_.get(),
                                            std::move(request));
}

void UserIntelligenceProviderImpl::GetResolver(
    fidl::InterfaceRequest<resolver::Resolver> request) {
  app::ConnectToService<resolver::Resolver>(resolver_services_.get(),
                                            std::move(request));
}

app::ServiceProviderPtr UserIntelligenceProviderImpl::startServiceProviderApp(
    const std::string& url) {
  app::ServiceProviderPtr services;
  auto launch_info = app::ApplicationLaunchInfo::New();
  launch_info->url = url;
  launch_info->services = services.NewRequest();
  app_context_->launcher()->CreateApplication(std::move(launch_info), NULL);
  return services;
}

void UserIntelligenceProviderImpl::startAgent(const std::string& url) {
  auto agent_host = std::make_unique<maxwell::ApplicationEnvironmentHostImpl>(
      app_context_->environment().get());

  agent_host->AddService<maxwell::ContextPublisher>(
      [this, url](fidl::InterfaceRequest<maxwell::ContextPublisher> request) {
        auto scope = ComponentScope::New();
        auto agent_scope = AgentScope::New();
        agent_scope->url = url;
        scope->set_agent_scope(std::move(agent_scope));
        context_engine_->GetPublisher(std::move(scope), std::move(request));
      });
  agent_host->AddService<maxwell::ContextProvider>(
      [this, url](fidl::InterfaceRequest<maxwell::ContextProvider> request) {
        auto scope = ComponentScope::New();
        auto agent_scope = AgentScope::New();
        agent_scope->url = url;
        scope->set_agent_scope(std::move(agent_scope));
        context_engine_->GetProvider(std::move(scope), std::move(request));
      });
  agent_host->AddService<maxwell::ProposalPublisher>(
      [this, url](fidl::InterfaceRequest<maxwell::ProposalPublisher> request) {
        suggestion_engine_->RegisterPublisher(url, std::move(request));
      });

  agent_host->AddService<modular::VisibleStoriesProvider>(
      [this](fidl::InterfaceRequest<modular::VisibleStoriesProvider> request) {
        visible_stories_provider_->Duplicate(std::move(request));
      });

  agent_host->AddService<network::NetworkService>(
      [this](fidl::InterfaceRequest<network::NetworkService> request) {
        app_context_->ConnectToEnvironmentService(std::move(request));
      });

  agent_host->AddService<resolver::Resolver>(std::bind(
      &UserIntelligenceProviderImpl::GetResolver, this, std::placeholders::_1));

  agent_launcher_.StartAgent(url, std::move(agent_host));
}

//////////////////////////////////////////////////////////////////////////////

UserIntelligenceProviderFactoryImpl::UserIntelligenceProviderFactoryImpl(
    app::ApplicationContext* app_context)
    : app_context_(app_context) {}

void UserIntelligenceProviderFactoryImpl::GetUserIntelligenceProvider(
    fidl::InterfaceHandle<modular::ComponentContext> component_context,
    fidl::InterfaceHandle<modular::StoryProvider> story_provider,
    fidl::InterfaceHandle<modular::FocusProvider> focus_provider,
    fidl::InterfaceHandle<modular::VisibleStoriesProvider>
        visible_stories_provider,
    fidl::InterfaceRequest<UserIntelligenceProvider>
        user_intelligence_provider_request) {
  // Fail if someone has already used this Factory to create an instance of
  // UserIntelligenceProvider.
  FTL_CHECK(!impl_);
  impl_.reset(new UserIntelligenceProviderImpl(
      app_context_, std::move(component_context), std::move(story_provider),
      std::move(focus_provider), std::move(visible_stories_provider)));
  binding_.reset(new fidl::Binding<UserIntelligenceProvider>(impl_.get()));
  binding_->Bind(std::move(user_intelligence_provider_request));
}

}  // namespace maxwell
