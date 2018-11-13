// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "topaz/runtime/web_view/web_view_provider.h"

#include <lib/fsl/vmo/strings.h>

#include "lib/icu_data/cpp/icu_data.h"
#include "peridot/lib/rapidjson/rapidjson.h"

WebViewProvider::WebViewProvider(async::Loop* loop, const std::string url)
    : loop_(loop),
      url_(url),
      context_(component::StartupContext::CreateFromStartupInfo()),
      view_provider_binding_(this),
      lifecycle_binding_(this),
      main_link_watcher_binding_(this) {
  FXL_DCHECK(loop);
  if (!icu_data::Initialize(context_.get(), nullptr)) {
    FXL_LOG(WARNING) << "Could not load ICU data";
  }

  context_->outgoing().AddPublicService<fuchsia::ui::viewsv1::ViewProvider>(
      [this](fidl::InterfaceRequest<ViewProvider> request) {
        FXL_LOG(INFO) << "Add ViewProvider binding";
        view_provider_binding_.Bind(std::move(request));
      });
  context_->outgoing().AddPublicService<fuchsia::modular::Lifecycle>(
      [this](fidl::InterfaceRequest<fuchsia::modular::Lifecycle> request) {
        FXL_LOG(INFO) << "got request for lifecycle service";
        lifecycle_binding_.Bind(std::move(request));
      });

  context_->ConnectToEnvironmentService(module_context_.NewRequest());
  module_context_->GetLink(nullptr, main_link_.NewRequest());
  main_link_->Watch(main_link_watcher_binding_.NewBinding());

#ifdef EXPERIMENTAL_WEB_ENTITY_EXTRACTION
  fuchsia::modular::IntelligenceServicesPtr intelligence_services;
  context_->ConnectToEnvironmentService(intelligence_services.NewRequest());
  intelligence_services->GetContextWriter(context_writer_.NewRequest());
  context_ptr->GetComponentContext(component_context_.NewRequest());

  if (view_) {
    view_->set_context_writer(std::move(context_writer_));
    view_->set_component_context(std::move(component_context_));
  }
#endif
}

void WebViewProvider::CreateView(
    fidl::InterfaceRequest<fuchsia::ui::viewsv1token::ViewOwner>
        view_owner_request,
    fidl::InterfaceRequest<fuchsia::sys::ServiceProvider> view_services) {
  FXL_LOG(INFO) << "CreateView";
  FXL_DCHECK(!view_);
  view_ = std::make_unique<WebViewImpl>(
      context_
          ->ConnectToEnvironmentService<fuchsia::ui::viewsv1::ViewManager>(),
      std::move(view_owner_request),
      context_->ConnectToEnvironmentService<fuchsia::ui::input::ImeService>(),
      std::move(view_services), url_);
#ifdef EXPERIMENTAL_WEB_ENTITY_EXTRACTION
  if (context_writer_) {
    view_->set_context_writer(std::move(context_writer_));
  }
  if (component_context_) {
    view_->set_component_context(std::move(component_context_));
  }
#endif

  view_->SetReleaseHandler([this](zx_status_t status) {
    FXL_LOG(INFO) << "release handler";
    view_ = nullptr;
  });
}

void WebViewProvider::Terminate() { loop_->Quit(); }

void WebViewProvider::Notify(fuchsia::mem::Buffer json) {
  std::string json_string;
  FXL_CHECK(fsl::StringFromVmo(json, &json_string));

  // Echo back the input URL to our "output_url" link. This is useful for
  // testing.
  {
    fuchsia::mem::Buffer output_json;
    FXL_CHECK(fsl::VmoFromString(json_string, &output_json));

    fuchsia::modular::LinkPtr output_url_link;
    module_context_->GetLink("output_url", output_url_link.NewRequest());
    output_url_link->Set(nullptr, std::move(output_json));
    output_url_link->Sync([] {});
  }

  modular::JsonDoc parsed_json;
  parsed_json.Parse(json_string);

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
      FXL_LOG(WARNING) << "/view/uri must be a string in " << json_string;
    } else {
      url_ = url_it->value.GetString();
      if (view_) {
        view_->SetUrl(url_);
      }
    }
  }
}
