// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "topaz/auth_providers/spotify/factory_impl.h"

namespace spotify_auth_provider {

FactoryImpl::FactoryImpl(component::StartupContext* context,
                         network_wrapper::NetworkWrapper* network_wrapper)
    : context_(context), network_wrapper_(network_wrapper) {
  FXL_DCHECK(context_);
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
  providers_.emplace(context_, network_wrapper_, std::move(auth_provider));
  callback(auth::AuthProviderStatus::OK);
}

}  // namespace spotify_auth_provider
