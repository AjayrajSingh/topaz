// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// This application serves as the Spotify Auth provider for generating OAuth
// credentials to talk to Spotify Api backends. This application implements
// |auth_provider.fidl| interface and is typically invoked by the Token Manager
// service in Garnet layer.

#ifndef TOPAZ_AUTH_PROVIDERS_SPOTIFY_AUTH_PROVIDER_IMPL_H_
#define TOPAZ_AUTH_PROVIDERS_SPOTIFY_AUTH_PROVIDER_IMPL_H_

#include <fuchsia/cpp/views_v1.h>
#include <fuchsia/cpp/web_view.h>
#include <fuchsia/cpp/auth.h>

#include "garnet/lib/callback/cancellable.h"
#include "garnet/lib/network_wrapper/network_wrapper.h"
#include "lib/app/cpp/application_context.h"
#include "lib/fidl/cpp/binding.h"
#include "lib/fxl/functional/closure.h"
#include "lib/fxl/macros.h"

namespace spotify_auth_provider {

class SpotifyAuthProviderImpl : public auth::AuthProvider,
                                web_view::WebRequestDelegate {
 public:
  SpotifyAuthProviderImpl(component::ApplicationContext* app_context,
                          network_wrapper::NetworkWrapper* network_wrapper,
                          fidl::InterfaceRequest<auth::AuthProvider> request);

  ~SpotifyAuthProviderImpl() override;

  void set_on_empty(const fxl::Closure& on_empty) { on_empty_ = on_empty; }

 private:
  // |AuthProvider|
  void GetPersistentCredential(
      fidl::InterfaceHandle<auth::AuthenticationUIContext> auth_ui_context,
      GetPersistentCredentialCallback callback) override;

  // |AuthProvider|
  void GetAppAccessToken(const fidl::StringPtr credential,
                         const fidl::StringPtr app_client_id,
                         const fidl::VectorPtr<fidl::StringPtr> app_scopes,
                         const GetAppAccessTokenCallback callback) override;

  // |AuthProvider|
  void GetAppIdToken(const fidl::StringPtr credential,
                     const fidl::StringPtr audience,
                     const GetAppIdTokenCallback callback) override;

  // |AuthProvider|
  void GetAppFirebaseToken(
      const fidl::StringPtr id_token, const fidl::StringPtr firebase_api_key,
      const GetAppFirebaseTokenCallback callback) override;

  // |AuthProvider|
  void RevokeAppOrPersistentCredential(
      const fidl::StringPtr credential,
      const RevokeAppOrPersistentCredentialCallback callback) override;

  // |web_view::WebRequestDelegate|
  void WillSendRequest(const fidl::StringPtr incoming_url) override;

  void GetUserProfile(const fidl::StringPtr credential,
                      const fidl::StringPtr access_token);

  views_v1_token::ViewOwnerPtr SetupWebView();

  void Request(std::function<network::URLRequest()> request_factory,
               std::function<void(network::URLResponse response)> callback);

  void OnResponse(
      std::function<void(network::URLResponse response)> callback,
      network::URLResponse response);

  component::ApplicationContext* app_context_;
  component::ApplicationControllerPtr web_view_controller_;
  auth::AuthenticationUIContextPtr auth_ui_context_;
  network_wrapper::NetworkWrapper* const network_wrapper_;
  web_view::WebViewPtr web_view_;
  GetPersistentCredentialCallback get_persistent_credential_callback_;

  fidl::BindingSet<web_view::WebRequestDelegate> web_request_delegate_bindings_;
  fidl::Binding<auth::AuthProvider> binding_;
  callback::CancellableContainer requests_;

  fxl::Closure on_empty_;

  FXL_DISALLOW_COPY_AND_ASSIGN(SpotifyAuthProviderImpl);
};

}  // namespace spotify_auth_provider

#endif // TOPAZ_AUTH_PROVIDERS_SPOTIFY_AUTH_PROVIDER_IMPL_H_
