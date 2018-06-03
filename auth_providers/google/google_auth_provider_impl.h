// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// This application serves as the Google Auth provider for generating OAuth
// credentials to talk to Google Api backends. This application implements
// |auth_provider.fidl| interface and is typically invoked by the Token Manager
// service in Garnet layer.

#include <auth/cpp/fidl.h>
#include <fuchsia/ui/views_v1/cpp/fidl.h>
#include <web_view/cpp/fidl.h>

#include "lib/app/cpp/startup_context.h"
#include "lib/callback/cancellable.h"
#include "lib/fidl/cpp/binding.h"
#include "lib/fxl/functional/closure.h"
#include "lib/fxl/macros.h"
#include "lib/network_wrapper/network_wrapper.h"

namespace google_auth_provider {

class GoogleAuthProviderImpl : auth::AuthProvider,
                               web_view::WebRequestDelegate {
 public:
  GoogleAuthProviderImpl(async_t* main_dispatcher,
                         fuchsia::sys::StartupContext* context,
                         network_wrapper::NetworkWrapper* network_wrapper,
                         fidl::InterfaceRequest<auth::AuthProvider> request);

  ~GoogleAuthProviderImpl() override;

  void set_on_empty(const fxl::Closure& on_empty) { on_empty_ = on_empty; }

 private:
  // |AuthProvider|
  void GetPersistentCredential(
      fidl::InterfaceHandle<auth::AuthenticationUIContext> auth_ui_context,
      GetPersistentCredentialCallback callback) override;

  // |AuthProvider|
  void GetAppAccessToken(fidl::StringPtr credential,
                         fidl::StringPtr app_client_id,
                         const fidl::VectorPtr<fidl::StringPtr> app_scopes,
                         GetAppAccessTokenCallback callback) override;

  // |AuthProvider|
  void GetAppIdToken(fidl::StringPtr credential, fidl::StringPtr audience,
                     GetAppIdTokenCallback callback) override;

  // |AuthProvider|
  void GetAppFirebaseToken(fidl::StringPtr id_token,
                           fidl::StringPtr firebase_api_key,
                           GetAppFirebaseTokenCallback callback) override;

  // |AuthProvider|
  void RevokeAppOrPersistentCredential(
      fidl::StringPtr credential,
      RevokeAppOrPersistentCredentialCallback callback) override;

  // |web_view::WebRequestDelegate|
  void WillSendRequest(fidl::StringPtr incoming_url) override;

  void GetUserProfile(fidl::StringPtr credential, fidl::StringPtr access_token);

  fuchsia::ui::views_v1_token::ViewOwnerPtr SetupWebView();

  void Request(std::function<::fuchsia::net::oldhttp::URLRequest()> request_factory,
               std::function<void(::fuchsia::net::oldhttp::URLResponse response)> callback);

  void OnResponse(std::function<void(::fuchsia::net::oldhttp::URLResponse response)> callback,
                  ::fuchsia::net::oldhttp::URLResponse response);

  async_t* const main_dispatcher_;
  fuchsia::sys::StartupContext* context_;
  fuchsia::sys::ComponentControllerPtr web_view_controller_;
  auth::AuthenticationUIContextPtr auth_ui_context_;
  network_wrapper::NetworkWrapper* const network_wrapper_;
  web_view::WebViewPtr web_view_;
  GetPersistentCredentialCallback get_persistent_credential_callback_;

  fidl::BindingSet<web_view::WebRequestDelegate> web_request_delegate_bindings_;
  fidl::Binding<auth::AuthProvider> binding_;
  callback::CancellableContainer requests_;

  fxl::Closure on_empty_;

  FXL_DISALLOW_COPY_AND_ASSIGN(GoogleAuthProviderImpl);
};

}  // namespace google_auth_provider
