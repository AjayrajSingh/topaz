// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef TOPAZ_AUTH_PROVIDERS_GOOGLE_FACTORY_IMPL_H_
#define TOPAZ_AUTH_PROVIDERS_GOOGLE_FACTORY_IMPL_H_

#include <fuchsia/auth/cpp/fidl.h>
#include <lib/async/dispatcher.h>

#include "lib/callback/auto_cleanable.h"
#include "lib/fxl/functional/closure.h"
#include "lib/fxl/macros.h"
#include "lib/network_wrapper/network_wrapper.h"
#include "topaz/auth_providers/google/google_auth_provider_impl.h"

namespace google_auth_provider {

class FactoryImpl : public fuchsia::auth::AuthProviderFactory {
 public:
  FactoryImpl(async_dispatcher_t* main_dispatcher, component::StartupContext* context,
              network_wrapper::NetworkWrapper* network_wrapper);

  ~FactoryImpl() override;

  void Bind(fidl::InterfaceRequest<fuchsia::auth::AuthProviderFactory> request);

 private:
  // Factory:
  void GetAuthProvider(
      fidl::InterfaceRequest<fuchsia::auth::AuthProvider> auth_provider,
      GetAuthProviderCallback callback) override;

  async_dispatcher_t* const main_dispatcher_;
  component::StartupContext* const context_;
  network_wrapper::NetworkWrapper* const network_wrapper_;

  callback::AutoCleanableSet<GoogleAuthProviderImpl> providers_;

  fidl::BindingSet<fuchsia::auth::AuthProviderFactory> factory_bindings_;

  FXL_DISALLOW_COPY_AND_ASSIGN(FactoryImpl);
};

}  // namespace google_auth_provider

#endif  // TOPAZ_AUTH_PROVIDERS_GOOGLE_FACTORY_IMPL_H_
