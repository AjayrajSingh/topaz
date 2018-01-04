// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "topaz/auth_providers/google/factory_impl.h"

namespace google_auth_provider {

FactoryImpl::FactoryImpl(fxl::RefPtr<fxl::TaskRunner> main_runner,
                         network_wrapper::NetworkWrapper* network_wrapper)
    : main_runner_(std::move(main_runner)), network_wrapper_(network_wrapper) {
  FXL_DCHECK(network_wrapper_);
}

FactoryImpl::~FactoryImpl() {}

void FactoryImpl::Bind(
    f1dl::InterfaceRequest<auth::AuthProviderFactory> request) {
  factory_bindings_.AddBinding(this, std::move(request));
}

void FactoryImpl::GetAuthProvider(
    f1dl::InterfaceRequest<auth::AuthProvider> auth_provider,
    const GetAuthProviderCallback& callback) {
  providers_.emplace(main_runner_, network_wrapper_, std::move(auth_provider));
  callback(auth::AuthProviderStatus::OK);
}

}  // namespace google_auth_provider
