// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "topaz/auth_providers/spotify/spotify_auth_provider_impl.h"

#include <fuchsia/net/oldhttp/cpp/fidl.h>
#include <fuchsia/ui/app/cpp/fidl.h>
#include <lib/fit/function.h>

#include "lib/component/cpp/connect.h"
#include "lib/component/cpp/startup_context.h"
#include "lib/fidl/cpp/interface_request.h"
#include "lib/fxl/functional/make_copyable.h"
#include "lib/fxl/logging.h"
#include "lib/fxl/strings/join_strings.h"
#include "lib/svc/cpp/services.h"
#include "peridot/lib/rapidjson/rapidjson.h"
#include "rapidjson/document.h"
#include "topaz/auth_providers/oauth/oauth_request_builder.h"
#include "topaz/auth_providers/oauth/oauth_response.h"
#include "topaz/auth_providers/spotify/constants.h"

namespace spotify_auth_provider {

namespace http = ::fuchsia::net::oldhttp;

using auth_providers::oauth::OAuthRequestBuilder;
using auth_providers::oauth::ParseOAuthResponse;
using fuchsia::auth::AssertionJWTParams;
using fuchsia::auth::AttestationJWTParams;
using fuchsia::auth::AuthProviderStatus;
using fuchsia::auth::AuthTokenPtr;
using modular::JsonValueToPrettyString;

SpotifyAuthProviderImpl::SpotifyAuthProviderImpl(
    component::StartupContext* context,
    network_wrapper::NetworkWrapper* network_wrapper,
    fidl::InterfaceRequest<fuchsia::auth::AuthProvider> request)
    : network_wrapper_(network_wrapper),
      binding_(this, std::move(request)) {
  FXL_DCHECK(network_wrapper_);

  // The class shuts down when the client connection is disconnected.
  binding_.set_error_handler([this](zx_status_t status) {
    if (on_empty_) {
      on_empty_();
    }
  });
}

SpotifyAuthProviderImpl::~SpotifyAuthProviderImpl() {}

void SpotifyAuthProviderImpl::GetPersistentCredential(
    fidl::InterfaceHandle<fuchsia::auth::AuthenticationUIContext>
        auth_ui_context,
    const fidl::StringPtr user_profile_id,
    GetPersistentCredentialCallback callback) {
  FXL_DCHECK(auth_ui_context);
  get_persistent_credential_callback_ = std::move(callback);

  // TODO(jsankey): Teach this code how to hold a chromium based web view.
}

void SpotifyAuthProviderImpl::GetAppAccessToken(
    const std::string credential, const fidl::StringPtr app_client_id,
    const std::vector<std::string> app_scopes,
    GetAppAccessTokenCallback callback) {
  if (credential.empty()) {
    callback(AuthProviderStatus::BAD_REQUEST, nullptr);
    return;
  }

  if (app_client_id->empty()) {
    callback(AuthProviderStatus::BAD_REQUEST, nullptr);
    return;
  }

  auto request = OAuthRequestBuilder(kSpotifyOAuthTokenEndpoint, "POST")
                     .SetUrlEncodedBody("refresh_token=" + credential +
                                        "&client_id=" + app_client_id.get() +
                                        "&grant_type=refresh_token");

  auto request_factory = fxl::MakeCopyable(
      [request = std::move(request)] { return request.Build(); });

  Request(std::move(request_factory), [callback = std::move(callback)](
                                          http::URLResponse response) {
    auto oauth_response = ParseOAuthResponse(std::move(response));
    if (oauth_response.status != AuthProviderStatus::OK) {
      FXL_VLOG(1) << "Got error: " << oauth_response.error_description;
      FXL_VLOG(1) << "Got response: "
                  << JsonValueToPrettyString(oauth_response.json_response);
      callback(oauth_response.status, nullptr);
      return;
    }

    AuthTokenPtr access_token = fuchsia::auth::AuthToken::New();
    access_token->token_type = fuchsia::auth::TokenType::ACCESS_TOKEN;
    access_token->token =
        oauth_response.json_response["access_token"].GetString();
    access_token->expires_in =
        oauth_response.json_response["expires_in"].GetUint64();

    callback(AuthProviderStatus::OK, std::move(access_token));
  });
}

void SpotifyAuthProviderImpl::GetAppIdToken(const std::string credential,
                                            const fidl::StringPtr audience,
                                            GetAppIdTokenCallback callback) {
  // Id Tokens are not supported by Spotify.
  callback(AuthProviderStatus::BAD_REQUEST, nullptr);
}

void SpotifyAuthProviderImpl::GetAppFirebaseToken(
    const std::string id_token, const std::string firebase_api_key,
    GetAppFirebaseTokenCallback callback) {
  // Firebase Token doesn't exist for Spotify.
  callback(AuthProviderStatus::BAD_REQUEST, nullptr);
}

void SpotifyAuthProviderImpl::RevokeAppOrPersistentCredential(
    const std::string credential,
    RevokeAppOrPersistentCredentialCallback callback) {
  // There is no programmatic way to revoke tokens. Instead, Spotify users have
  // to manually revoke access from this page here:
  // <https://www.spotify.com/account/>
  callback(AuthProviderStatus::BAD_REQUEST);
}

void SpotifyAuthProviderImpl::GetPersistentCredentialFromAttestationJWT(
    fidl::InterfaceHandle<AttestationSigner> attestation_signer,
    AttestationJWTParams jwt_params,
    fidl::InterfaceHandle<AuthenticationUIContext> auth_ui_context,
    fidl::StringPtr user_profile_id,
    GetPersistentCredentialFromAttestationJWTCallback callback) {
  // Remote attestation flow not supported.
  callback(AuthProviderStatus::BAD_REQUEST, nullptr, nullptr, nullptr, nullptr);
}

void SpotifyAuthProviderImpl::GetAppAccessTokenFromAssertionJWT(
    fidl::InterfaceHandle<AttestationSigner> attestation_signer,
    AssertionJWTParams jwt_params, std::string credential,
    const std::vector<std::string> app_scopes,
    GetAppAccessTokenFromAssertionJWTCallback callback) {
  // Remote attestation flow not supported.
  callback(AuthProviderStatus::BAD_REQUEST, nullptr, nullptr, nullptr);
}

void SpotifyAuthProviderImpl::GetUserProfile(
    const fidl::StringPtr credential, const fidl::StringPtr access_token) {
  FXL_DCHECK(credential.get().size() > 0);
  FXL_DCHECK(access_token.get().size() > 0);

  auto request = OAuthRequestBuilder(kSpotifyPeopleGetEndpoint, "GET")
                     .SetAuthorizationHeader(access_token.get());

  auto request_factory = fxl::MakeCopyable(
      [request = std::move(request)] { return request.Build(); });

  Request(std::move(request_factory), [this,
                                       credential](http::URLResponse response) {
    fuchsia::auth::UserProfileInfoPtr user_profile_info =
        fuchsia::auth::UserProfileInfo::New();

    auto oauth_response = ParseOAuthResponse(std::move(response));
    if (oauth_response.status != AuthProviderStatus::OK) {
      FXL_VLOG(1) << "Got error: " << oauth_response.error_description;
      FXL_VLOG(1) << "Got response: "
                  << JsonValueToPrettyString(oauth_response.json_response);

      get_persistent_credential_callback_(oauth_response.status, credential,
                                          std::move(user_profile_info));
      return;
    }

    if (oauth_response.json_response.HasMember("id")) {
      user_profile_info->id = oauth_response.json_response["id"].GetString();
    }

    if (oauth_response.json_response.HasMember("displayName")) {
      user_profile_info->display_name =
          oauth_response.json_response["displayName"].GetString();
    }

    if (oauth_response.json_response.HasMember("url")) {
      user_profile_info->url = oauth_response.json_response["url"].GetString();
    }

    if (oauth_response.json_response.HasMember("image")) {
      user_profile_info->image_url =
          oauth_response.json_response["image"]["url"].GetString();
    }

    get_persistent_credential_callback_(oauth_response.status, credential,
                                        std::move(user_profile_info));
  });
}

zx::eventpair SpotifyAuthProviderImpl::SetupChromium() {
  // TODO(jsankey): Implement.
  return {};
}

void SpotifyAuthProviderImpl::Request(
    fit::function<http::URLRequest()> request_factory,
    fit::function<void(http::URLResponse response)> callback) {
  requests_.emplace(network_wrapper_->Request(std::move(request_factory),
                                              std::move(callback)));
}

}  // namespace spotify_auth_provider
