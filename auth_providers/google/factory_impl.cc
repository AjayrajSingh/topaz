// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "topaz/auth_providers/google/factory_impl.h"

namespace google_auth_provider {

FactoryImpl::FactoryImpl(fxl::RefPtr<fxl::TaskRunner> main_runner,
                         component::ApplicationContext* app_context,
                         network_wrapper::NetworkWrapper* network_wrapper)
    : main_runner_(std::move(main_runner)),
      app_context_(app_context),
      network_wrapper_(network_wrapper) {
  FXL_DCHECK(app_context_);
  FXL_DCHECK(network_wrapper_);
}

FactoryImpl::~FactoryImpl() {}

void FactoryImpl::Bind(
    fidl::InterfaceRequest<auth::AuthProviderFactory> request) {
  factory_bindings_.AddBinding(this, std::move(request));
}

void FactoryImpl::GetAuthProvider(
    fidl::InterfaceRequest<auth::AuthProvider> auth_provider,
    GetAuthProviderCallback callback) {
  providers_.emplace(main_runner_, app_context_, network_wrapper_,
                     std::move(auth_provider));
  callback(auth::AuthProviderStatus::OK);
}

}  // namespace google_auth_provider
