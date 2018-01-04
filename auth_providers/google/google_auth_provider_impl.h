// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// This application serves as the Google Auth provider for generating OAuth
// credentials to talk to Google Api backends. This application implements
// |auth_provider.fidl| interface and is typically invoked by the Token Manager
// service in Garnet layer.

#include "garnet/lib/callback/cancellable.h"
#include "garnet/lib/network_wrapper/network_wrapper.h"
#include "garnet/public/lib/auth/fidl/auth_provider.fidl.h"
#include "lib/app/cpp/application_context.h"
#include "lib/fidl/cpp/bindings/binding.h"
#include "lib/fxl/functional/closure.h"
#include "lib/fxl/macros.h"
#include "lib/fxl/tasks/task_runner.h"

namespace google_auth_provider {

class GoogleAuthProviderImpl : auth::AuthProvider {
 public:
  GoogleAuthProviderImpl(fxl::RefPtr<fxl::TaskRunner> task_runner,
                         network_wrapper::NetworkWrapper* network_wrapper,
                         f1dl::InterfaceRequest<auth::AuthProvider> request);

  ~GoogleAuthProviderImpl() override;

  void set_on_empty(const fxl::Closure& on_empty) { on_empty_ = on_empty; }

 private:
  // |AuthProvider|
  void GetPersistentCredential(
      f1dl::InterfaceHandle<auth::AuthenticationUIContext> auth_ui_context,
      const GetPersistentCredentialCallback& callback) override;

  // |AuthProvider|
  void GetAppAccessToken(const f1dl::String& credential,
                         const f1dl::String& app_client_id,
                         const f1dl::Array<f1dl::String> app_scopes,
                         const GetAppAccessTokenCallback& callback) override;

  // |AuthProvider|
  void GetAppIdToken(const f1dl::String& credential,
                     const f1dl::String& audience,
                     const GetAppIdTokenCallback& callback) override;

  // |AuthProvider|
  void GetAppFirebaseToken(
      const f1dl::String& id_token, const f1dl::String& firebase_api_key,
      const GetAppFirebaseTokenCallback& callback) override;

  // |AuthProvider|
  void RevokeAppOrPersistentCredential(
      const f1dl::String& credential,
      const RevokeAppOrPersistentCredentialCallback& callback) override;

  void Request(std::function<network::URLRequestPtr()> request_factory,
               std::function<void(network::URLResponsePtr response)> callback);

  void OnResponse(
      std::function<void(network::URLResponsePtr response)> callback,
      network::URLResponsePtr response);

  fxl::RefPtr<fxl::TaskRunner> task_runner_;
  network_wrapper::NetworkWrapper* const network_wrapper_;
  f1dl::Binding<auth::AuthProvider> binding_;
  callback::CancellableContainer requests_;

  fxl::Closure on_empty_;

  FXL_DISALLOW_COPY_AND_ASSIGN(GoogleAuthProviderImpl);
};

}  // namespace google_auth_provider
