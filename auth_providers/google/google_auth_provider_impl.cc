// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "topaz/auth_providers/google/google_auth_provider_impl.h"

#include "lib/fxl/functional/make_copyable.h"
#include "lib/fxl/logging.h"
#include "lib/network/fidl/network_service.fidl.h"
#include "peridot/lib/rapidjson/rapidjson.h"
#include "third_party/rapidjson/rapidjson/document.h"
#include "topaz/auth_providers/google/constants.h"
#include "topaz/auth_providers/oauth/oauth_request_builder.h"
#include "topaz/auth_providers/oauth/oauth_response.h"

namespace google_auth_provider {

namespace {

std::string GetClientId(const std::string& app_client_id) {
  // By default, use the client_id of the invoking application.
  std::string client_id = app_client_id;

  // Use hard-coded Fuchsia client_id for downscoped tokens, if |app_client_id|
  // is missing.
  if (app_client_id.empty()) {
    client_id = kFuchsiaClientId;
  }

  return client_id;
}

std::string GenerateRandomString() {
  uint32_t random_number;
  size_t random_size;
  zx_status_t status =
      zx_cprng_draw(&random_number, sizeof random_number, &random_size);
  FXL_CHECK(status == ZX_OK);
  FXL_CHECK(sizeof random_number == random_size);
  return std::to_string(random_number);
}

}  // namespace

using auth::AuthProviderStatus;
using auth::AuthTokenPtr;
using auth_providers::oauth::OAuthRequestBuilder;
using auth_providers::oauth::ParseOAuthResponse;
using modular::JsonValueToPrettyString;

GoogleAuthProviderImpl::GoogleAuthProviderImpl(
    fxl::RefPtr<fxl::TaskRunner> task_runner,
    network_wrapper::NetworkWrapper* network_wrapper,
    f1dl::InterfaceRequest<auth::AuthProvider> request)
    : task_runner_(std::move(task_runner)),
      network_wrapper_(network_wrapper),
      binding_(this, std::move(request)) {
  FXL_DCHECK(network_wrapper_);

  // The class shuts down when the client connection is disconnected.
  binding_.set_error_handler([this] {
    if (on_empty_) {
      on_empty_();
    }
  });
}

GoogleAuthProviderImpl::~GoogleAuthProviderImpl() {}

void GoogleAuthProviderImpl::GetPersistentCredential(
    f1dl::InterfaceHandle<auth::AuthenticationUIContext> auth_ui_context,
    const GetPersistentCredentialCallback& callback) {
  // TODO:Generate the refresh token by getting user consent. In the meantime,
  // temporarily return a random string.
  callback(AuthProviderStatus::OK, GenerateRandomString());
}

void GoogleAuthProviderImpl::GetAppAccessToken(
    const f1dl::String& credential, const f1dl::String& app_client_id,
    const f1dl::Array<f1dl::String> app_scopes,
    const GetAppAccessTokenCallback& callback) {
  if (credential.empty()) {
    callback(AuthProviderStatus::BAD_REQUEST, nullptr);
    return;
  }

  auto request =
      OAuthRequestBuilder(kGoogleOAuthTokenEndpoint, "POST")
          .SetUrlEncodedBody("refresh_token=" + credential.get() +
                             "&client_id=" + GetClientId(app_client_id.get()) +
                             "&grant_type=refresh_token");

  auto request_factory = fxl::MakeCopyable(
      [task_runner = task_runner_, request = std::move(request)] {
        return request.Build();
      });

  Request(
      std::move(request_factory), [callback](network::URLResponsePtr response) {
        auto oauth_response = ParseOAuthResponse(std::move(response));
        if (oauth_response.status != AuthProviderStatus::OK) {
          FXL_VLOG(1) << "Got error: " << oauth_response.error_description;
          FXL_VLOG(1) << "Got response: "
                      << JsonValueToPrettyString(oauth_response.json_response);
          callback(oauth_response.status, nullptr);
          return;
        }

        AuthTokenPtr access_token = auth::AuthToken::New();
        access_token->token_type = auth::TokenType::ACCESS_TOKEN;
        access_token->token =
            oauth_response.json_response["access_token"].GetString();
        access_token->expires_in =
            oauth_response.json_response["expires_in"].GetUint64();

        callback(AuthProviderStatus::OK, std::move(access_token));
      });
}

void GoogleAuthProviderImpl::GetAppIdToken(
    const f1dl::String& credential, const f1dl::String& audience,
    const GetAppIdTokenCallback& callback) {
  if (credential.empty()) {
    callback(AuthProviderStatus::BAD_REQUEST, nullptr);
    return;
  }

  auto request =
      OAuthRequestBuilder(kGoogleOAuthTokenEndpoint, "POST")
          .SetUrlEncodedBody("refresh_token=" + credential.get() +
                             "&client_id=" + GetClientId(audience.get()) +
                             "&grant_type=refresh_token");

  auto request_factory = fxl::MakeCopyable(
      [task_runner = task_runner_, request = std::move(request)] {
        return request.Build();
      });
  Request(
      std::move(request_factory), [callback](network::URLResponsePtr response) {
        auto oauth_response = ParseOAuthResponse(std::move(response));
        if (oauth_response.status != AuthProviderStatus::OK) {
          FXL_VLOG(1) << "Got error: " << oauth_response.error_description;
          FXL_VLOG(1) << "Got response: "
                      << JsonValueToPrettyString(oauth_response.json_response);
          callback(oauth_response.status, nullptr);
          return;
        }

        AuthTokenPtr id_token = auth::AuthToken::New();
        id_token->token = oauth_response.json_response["id_token"].GetString();
        id_token->token_type = auth::TokenType::ID_TOKEN;
        id_token->expires_in =
            oauth_response.json_response["expires_in"].GetUint64();

        callback(AuthProviderStatus::OK, std::move(id_token));
      });
}

void GoogleAuthProviderImpl::GetAppFirebaseToken(
    const f1dl::String& id_token, const f1dl::String& firebase_api_key,
    const GetAppFirebaseTokenCallback& callback) {
  if (id_token.empty() || firebase_api_key.empty()) {
    callback(AuthProviderStatus::BAD_REQUEST, nullptr);
    return;
  }

  std::string url =
      kFirebaseAuthEndpoint + std::string("?key=") + firebase_api_key.get();

  auto request = OAuthRequestBuilder(url, "POST")
                     .SetJsonBody(
                         R"({"postBody": "id_token=)" + id_token.get() +
                         "&providerId=google.com\"," +
                         "   \"returnIdpCredential\": true," +
                         "   \"returnSecureToken\": true," +
                         R"(   "requestUri": "http://localhost")" + "}");

  // Exchange credential to access token at Google OAuth token endpoint
  auto request_factory = fxl::MakeCopyable(
      [task_runner = task_runner_, request = std::move(request)] {
        return request.Build();
      });
  Request(
      std::move(request_factory), [callback](network::URLResponsePtr response) {
        auto oauth_response = ParseOAuthResponse(std::move(response));
        if (oauth_response.status != AuthProviderStatus::OK) {
          FXL_VLOG(1) << "Got error: " << oauth_response.error_description;
          FXL_VLOG(1) << "Got response: "
                      << JsonValueToPrettyString(oauth_response.json_response);
          callback(oauth_response.status, nullptr);
          return;
        }

        auth::FirebaseTokenPtr fb_token = auth::FirebaseToken::New();
        fb_token->id_token =
            oauth_response.json_response["id_token"].GetString();
        fb_token->email = oauth_response.json_response["email"].GetString();
        fb_token->local_id =
            oauth_response.json_response["local_id"].GetString();

        callback(AuthProviderStatus::OK, std::move(fb_token));
      });
}

void GoogleAuthProviderImpl::RevokeAppOrPersistentCredential(
    const f1dl::String& credential,
    const RevokeAppOrPersistentCredentialCallback& callback) {
  if (credential.empty()) {
    callback(AuthProviderStatus::BAD_REQUEST);
    return;
  }

  std::string url =
      kGoogleRevokeTokenEndpoint + std::string("?token=") + credential.get();
  auto request = OAuthRequestBuilder(url, "POST").SetUrlEncodedBody("");

  auto request_factory = fxl::MakeCopyable(
      [task_runner = task_runner_, request = std::move(request)] {
        return request.Build();
      });

  Request(
      std::move(request_factory),
      [callback](network::URLResponsePtr response) mutable {
        auto oauth_response = ParseOAuthResponse(std::move(response));
        if (oauth_response.status != AuthProviderStatus::OK) {
          FXL_VLOG(1) << "Got error: " << oauth_response.error_description;
          FXL_VLOG(1) << "Got response: "
                      << JsonValueToPrettyString(oauth_response.json_response);
          callback(oauth_response.status);
          return;
        }

        callback(AuthProviderStatus::OK);
      });
}

void GoogleAuthProviderImpl::Request(
    std::function<network::URLRequestPtr()> request_factory,
    std::function<void(network::URLResponsePtr response)> callback) {
  requests_.emplace(network_wrapper_->Request(
      std::move(request_factory),
      [this, callback = std::move(callback)](
          network::URLResponsePtr response) mutable {
        OnResponse(std::move(callback), std::move(response));
      }));
}

void GoogleAuthProviderImpl::OnResponse(
    std::function<void(network::URLResponsePtr response)> callback,
    network::URLResponsePtr response) {
  callback(std::move(response));
}

}  // namespace google_auth_provider
