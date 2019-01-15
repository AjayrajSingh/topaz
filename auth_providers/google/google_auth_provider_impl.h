// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// This application serves as the Google Auth provider for generating OAuth
// credentials to talk to Google Api backends. This application implements
// |auth_provider.fidl| interface and is typically invoked by the Token Manager
// service in Garnet layer.

#include <chromium/web/cpp/fidl.h>
#include <fuchsia/auth/cpp/fidl.h>
#include <lib/fit/function.h>
#include <lib/zx/eventpair.h>

#include "lib/callback/cancellable.h"
#include "lib/component/cpp/startup_context.h"
#include "lib/fidl/cpp/binding.h"
#include "lib/fxl/macros.h"
#include "lib/network_wrapper/network_wrapper.h"
#include "topaz/auth_providers/google/settings.h"

namespace google_auth_provider {

using chromium::web::NavigationEvent;
using fuchsia::auth::AssertionJWTParams;
using fuchsia::auth::AttestationJWTParams;
using fuchsia::auth::AttestationSigner;
using fuchsia::auth::AuthenticationUIContext;

class GoogleAuthProviderImpl : chromium::web::NavigationEventObserver,
                               fuchsia::auth::AuthProvider {
 public:
  GoogleAuthProviderImpl(
      async_dispatcher_t* main_dispatcher, component::StartupContext* context,
      network_wrapper::NetworkWrapper* network_wrapper, Settings settings,
      fidl::InterfaceRequest<fuchsia::auth::AuthProvider> request);

  ~GoogleAuthProviderImpl() override;

  void set_on_empty(fit::closure on_empty) { on_empty_ = std::move(on_empty); }

 private:
  // |AuthProvider|
  void GetPersistentCredential(
      fidl::InterfaceHandle<fuchsia::auth::AuthenticationUIContext>
          auth_ui_context,
      fidl::StringPtr user_profile_id,
      GetPersistentCredentialCallback callback) override;

  // |AuthProvider|
  void GetAppAccessToken(std::string credential,
                         fidl::StringPtr app_client_id,
                         const std::vector<std::string> app_scopes,
                         GetAppAccessTokenCallback callback) override;

  // |AuthProvider|
  void GetAppIdToken(std::string credential, fidl::StringPtr audience,
                     GetAppIdTokenCallback callback) override;

  // |AuthProvider|
  void GetAppFirebaseToken(std::string id_token,
                           std::string firebase_api_key,
                           GetAppFirebaseTokenCallback callback) override;

  // |AuthProvider|
  void RevokeAppOrPersistentCredential(
      std::string credential,
      RevokeAppOrPersistentCredentialCallback callback) override;

  // |AuthProvider|
  void GetPersistentCredentialFromAttestationJWT(
      fidl::InterfaceHandle<AttestationSigner> attestation_signer,
      AttestationJWTParams jwt_params,
      fidl::InterfaceHandle<AuthenticationUIContext> auth_ui_context,
      fidl::StringPtr user_profile_id,
      GetPersistentCredentialFromAttestationJWTCallback callback) override;

  // |AuthProvider|
  void GetAppAccessTokenFromAssertionJWT(
      fidl::InterfaceHandle<AttestationSigner> attestation_signer,
      AssertionJWTParams jwt_params, std::string credential,
      std::vector<std::string> scopes,
      GetAppAccessTokenFromAssertionJWTCallback callback) override;

  // |chromium::Web::NavigationEventObserver|
  void OnNavigationStateChanged(
      NavigationEvent change,
      OnNavigationStateChangedCallback callback) override;

  // Returns the URL to be used for the authentication call, respecting any
  // settings that influence the URL.
  std::string GetAuthorizeUrl(fidl::StringPtr user_profile_id);

  // Calls the OAuth auth endpoint to exchange the supplied |auth_code| for a
  // long term credential, and then calls |GetUserProfile| with that credential.
  // If any errors are encountered a failure status is returned on the pending
  // |get_credential_callback_|.
  void ExchangeAuthCode(std::string auth_code);

  // Calls the people endpoint to gather profile information using the supplied
  // |access_token| and responds to the pending |get_credential_callback_|.
  void GetUserProfile(fidl::StringPtr credential, fidl::StringPtr access_token);

  // Launches and connects to a Chromium frame, binding |this| as a
  // |NavigationEventObserver| to process any changes in the URL, and returning
  // a |zx::eventpair| token for the view's ViewHolder.
  zx::eventpair SetupChromium();

  // Safely releases any resources associated with an open Webkit or Chromium
  // instance, including the associated view.
  void ReleaseResources();

  void Request(
      fit::function<::fuchsia::net::oldhttp::URLRequest()> request_factory,
      fit::function<void(::fuchsia::net::oldhttp::URLResponse response)>
          callback);

  async_dispatcher_t* const main_dispatcher_;
  component::StartupContext* context_;
  network_wrapper::NetworkWrapper* const network_wrapper_;
  const Settings settings_;
  fuchsia::sys::ComponentControllerPtr web_view_controller_;
  fuchsia::auth::AuthenticationUIContextPtr auth_ui_context_;
  chromium::web::ContextPtr chromium_context_;
  chromium::web::FramePtr chromium_frame_;
  GetPersistentCredentialCallback get_persistent_credential_callback_;

  fidl::BindingSet<chromium::web::NavigationEventObserver>
      navigation_event_observer_bindings_;
  fidl::Binding<fuchsia::auth::AuthProvider> binding_;
  callback::CancellableContainer requests_;

  fit::closure on_empty_;

  FXL_DISALLOW_COPY_AND_ASSIGN(GoogleAuthProviderImpl);
};

}  // namespace google_auth_provider
