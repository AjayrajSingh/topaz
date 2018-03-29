// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef TOPAZ_AUTH_PROVIDERS_GOOGLE_FACTORY_IMPL_H_
#define TOPAZ_AUTH_PROVIDERS_GOOGLE_FACTORY_IMPL_H_

#include <fuchsia/cpp/auth.h>

#include "garnet/lib/callback/auto_cleanable.h"
#include "garnet/lib/network_wrapper/network_wrapper.h"
#include "lib/fxl/functional/closure.h"
#include "lib/fxl/macros.h"
#include "lib/fxl/tasks/task_runner.h"
#include "topaz/auth_providers/google/google_auth_provider_impl.h"

namespace google_auth_provider {

class FactoryImpl : public auth::AuthProviderFactory {
 public:
  FactoryImpl(fxl::RefPtr<fxl::TaskRunner> main_runner,
              component::ApplicationContext* app_context,
              network_wrapper::NetworkWrapper* network_wrapper);

  ~FactoryImpl() override;

  void Bind(fidl::InterfaceRequest<auth::AuthProviderFactory> request);

 private:
  // Factory:
  void GetAuthProvider(fidl::InterfaceRequest<auth::AuthProvider> auth_provider,
                       GetAuthProviderCallback callback) override;

  fxl::RefPtr<fxl::TaskRunner> main_runner_;
  component::ApplicationContext* const app_context_;
  network_wrapper::NetworkWrapper* const network_wrapper_;

  callback::AutoCleanableSet<GoogleAuthProviderImpl> providers_;

  fidl::BindingSet<auth::AuthProviderFactory> factory_bindings_;

  FXL_DISALLOW_COPY_AND_ASSIGN(FactoryImpl);
};

}  // namespace google_auth_provider

#endif // TOPAZ_AUTH_PROVIDERS_GOOGLE_FACTORY_IMPL_H_
