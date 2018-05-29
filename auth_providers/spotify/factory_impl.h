// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef TOPAZ_AUTH_PROVIDERS_SPOTIFY_FACTORY_IMPL_H_
#define TOPAZ_AUTH_PROVIDERS_SPOTIFY_FACTORY_IMPL_H_

#include <auth/cpp/fidl.h>

#include "lib/callback/auto_cleanable.h"
#include "lib/fxl/functional/closure.h"
#include "lib/fxl/macros.h"
#include "lib/network_wrapper/network_wrapper.h"
#include "topaz/auth_providers/spotify/spotify_auth_provider_impl.h"

namespace spotify_auth_provider {

class FactoryImpl : public auth::AuthProviderFactory {
 public:
  FactoryImpl(fuchsia::sys::StartupContext* context,
              network_wrapper::NetworkWrapper* network_wrapper);

  ~FactoryImpl() override;

  void Bind(fidl::InterfaceRequest<auth::AuthProviderFactory> request);

 private:
  // Factory:
  void GetAuthProvider(fidl::InterfaceRequest<auth::AuthProvider> auth_provider,
                       GetAuthProviderCallback callback) override;

  fuchsia::sys::StartupContext* const context_;
  network_wrapper::NetworkWrapper* const network_wrapper_;

  callback::AutoCleanableSet<SpotifyAuthProviderImpl> providers_;

  fidl::BindingSet<auth::AuthProviderFactory> factory_bindings_;

  FXL_DISALLOW_COPY_AND_ASSIGN(FactoryImpl);
};

}  // namespace spotify_auth_provider

#endif  // TOPAZ_AUTH_PROVIDERS_SPOTIFY_FACTORY_IMPL_H_
