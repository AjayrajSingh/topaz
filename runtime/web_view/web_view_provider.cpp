// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "topaz/runtime/web_view/web_view_provider.h"

#include "lib/fsl/tasks/message_loop.h"
#include "lib/icu_data/cpp/icu_data.h"
#include "peridot/lib/rapidjson/rapidjson.h"

WebViewProvider::WebViewProvider(const std::string url)
    : url_(url),
      context_(app::ApplicationContext::CreateFromStartupInfo()),
      view_provider_binding_(this),
      module_binding_(this),
      lifecycle_binding_(this),
      main_link_watcher_binding_(this) {
  if (!icu_data::Initialize(context_.get())) {
    FXL_LOG(WARNING) << "Could not load ICU data";
  }

  context_->outgoing_services()->AddService<mozart::ViewProvider>(
      [this](f1dl::InterfaceRequest<ViewProvider> request) {
        FXL_LOG(INFO) << "Add ViewProvider binding";
        view_provider_binding_.Bind(std::move(request));
      });
  context_->outgoing_services()->AddService<modular::Module>(
      [this](f1dl::InterfaceRequest<modular::Module> request) {
        FXL_LOG(INFO) << "got request for module service";
        module_binding_.Bind(std::move(request));
      });
  context_->outgoing_services()->AddService<modular::Lifecycle>(
      [this](f1dl::InterfaceRequest<modular::Lifecycle> request) {
        FXL_LOG(INFO) << "got request for lifecycle service";
        lifecycle_binding_.Bind(std::move(request));
      });
}

void WebViewProvider::CreateView(
    f1dl::InterfaceRequest<mozart::ViewOwner> view_owner_request,
    f1dl::InterfaceRequest<app::ServiceProvider> view_services) {
  FXL_LOG(INFO) << "CreateView";
  FXL_DCHECK(!view_);
  view_ = std::make_unique<WebViewImpl>(
      context_->ConnectToEnvironmentService<mozart::ViewManager>(),
      std::move(view_owner_request), std::move(view_services), url_);
  if (context_writer_) {
    view_->set_context_writer(std::move(context_writer_));
  }
  view_->SetReleaseHandler([this] {
    FXL_LOG(INFO) << "release handler";
    view_ = nullptr;
  });
}

void WebViewProvider::Initialize(
    f1dl::InterfaceHandle<modular::ModuleContext> context,
    f1dl::InterfaceRequest<app::ServiceProvider> outgoing_services) {
  auto context_ptr = context.Bind();
  context_ptr->GetLink(nullptr, main_link_.NewRequest());
  main_link_->Watch(main_link_watcher_binding_.NewBinding());

  maxwell::IntelligenceServicesPtr intelligence_services;
  context_ptr->GetIntelligenceServices(intelligence_services.NewRequest());
  intelligence_services->GetContextWriter(context_writer_.NewRequest());

  if (view_) {
    view_->set_context_writer(std::move(context_writer_));
  }

  FXL_LOG(INFO) << "Initialize()";
}

void WebViewProvider::Terminate() {
  fsl::MessageLoop::GetCurrent()->QuitNow();
}

void WebViewProvider::Notify(const f1dl::String& json) {
  modular::JsonDoc parsed_json;
  parsed_json.Parse(json.To<std::string>());

  if (!parsed_json.IsObject()) {
    FXL_LOG(WARNING) << "Not an object: "
                     << modular::JsonValueToPrettyString(parsed_json);
    return;
  }

  const auto contract_it = parsed_json.FindMember("view");
  if (contract_it != parsed_json.MemberEnd()) {
    const auto& contract = contract_it->value;
    auto url_it = contract.FindMember("uri");
    if (url_it == contract.MemberEnd() || !url_it->value.IsString()) {
      FXL_LOG(WARNING) << "/view/uri must be a string in " << json;
    } else {
      url_ = url_it->value.GetString();
      if (view_) {
        view_->SetUrl(url_);
      }
    }
  }
}
