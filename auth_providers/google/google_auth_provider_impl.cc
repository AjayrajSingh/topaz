// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "topaz/auth_providers/google/google_auth_provider_impl.h"

#include <fuchsia/net/oldhttp/cpp/fidl.h>
#include <fuchsia/ui/views_v1_token/cpp/fidl.h>

#include "lib/app/cpp/connect.h"
#include "lib/app/cpp/startup_context.h"
#include "lib/fidl/cpp/interface_request.h"
#include "lib/fxl/functional/make_copyable.h"
#include "lib/fxl/logging.h"
#include "lib/fxl/strings/join_strings.h"
#include "lib/svc/cpp/services.h"
#include "peridot/lib/rapidjson/rapidjson.h"
#include "third_party/rapidjson/rapidjson/document.h"
#include "topaz/auth_providers/google/constants.h"
#include "topaz/auth_providers/oauth/oauth_request_builder.h"
#include "topaz/auth_providers/oauth/oauth_response.h"

namespace google_auth_provider {

namespace http = ::fuchsia::net::oldhttp;

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

}  // namespace

using auth::AuthProviderStatus;
using auth::AuthTokenPtr;
using auth_providers::oauth::OAuthRequestBuilder;
using auth_providers::oauth::ParseOAuthResponse;
using fuchsia::modular::JsonValueToPrettyString;

GoogleAuthProviderImpl::GoogleAuthProviderImpl(
    async_t* const main_dispatcher, fuchsia::sys::StartupContext* context,
    network_wrapper::NetworkWrapper* network_wrapper,
    fidl::InterfaceRequest<auth::AuthProvider> request)
    : main_dispatcher_(main_dispatcher),
      context_(context),
      network_wrapper_(network_wrapper),
      binding_(this, std::move(request)) {
  FXL_DCHECK(main_dispatcher_);
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
    fidl::InterfaceHandle<auth::AuthenticationUIContext> auth_ui_context,
    GetPersistentCredentialCallback callback) {
  FXL_DCHECK(auth_ui_context);
  get_persistent_credential_callback_ = std::move(callback);

  auto view_owner = SetupWebView();

  // Set a delegate which will parse incoming URLs for authorization code.
  web_view::WebRequestDelegatePtr web_request_delegate;
  web_request_delegate_bindings_.AddBinding(this,
                                            web_request_delegate.NewRequest());
  web_view_->SetWebRequestDelegate(std::move(web_request_delegate));

  web_view_->ClearCookies();

  const std::vector<std::string> scopes(kScopes.begin(), kScopes.end());
  std::string scopes_str = fxl::JoinStrings(scopes, "+");

  std::string url = kGoogleOAuthAuthEndpoint;
  url += "?scope=" + scopes_str;
  url += "&response_type=code&redirect_uri=";
  url += kRedirectUri;
  url += "&client_id=";
  url += kFuchsiaClientId;

  web_view_->SetUrl(url);

  auth_ui_context_ = auth_ui_context.Bind();
  auth_ui_context_.set_error_handler([this] {
    FXL_VLOG(1) << "Overlay cancelled by the caller";
    // close any open web view
    if (auth_ui_context_) {
      auth_ui_context_.set_error_handler([] {});
      auth_ui_context_->StopOverlay();
    }
    auth_ui_context_ = nullptr;
    get_persistent_credential_callback_(AuthProviderStatus::INTERNAL_ERROR,
                                        nullptr, nullptr);
    return;
  });

  auth_ui_context_->StartOverlay(std::move(view_owner));
}

void GoogleAuthProviderImpl::GetAppAccessToken(
    fidl::StringPtr credential, fidl::StringPtr app_client_id,
    const fidl::VectorPtr<fidl::StringPtr> app_scopes,
    GetAppAccessTokenCallback callback) {
  if (credential->empty()) {
    callback(AuthProviderStatus::BAD_REQUEST, nullptr);
    return;
  }

  auto request =
      OAuthRequestBuilder(kGoogleOAuthTokenEndpoint, "POST")
          .SetUrlEncodedBody("refresh_token=" + credential.get() +
                             "&client_id=" + GetClientId(app_client_id.get()) +
                             "&grant_type=refresh_token");

  auto request_factory = fxl::MakeCopyable(
      [request = std::move(request)] { return request.Build(); });

  Request(
      std::move(request_factory), [callback](http::URLResponse response) {
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

void GoogleAuthProviderImpl::GetAppIdToken(fidl::StringPtr credential,
                                           fidl::StringPtr audience,
                                           GetAppIdTokenCallback callback) {
  if (credential->empty()) {
    callback(AuthProviderStatus::BAD_REQUEST, nullptr);
    return;
  }

  auto request =
      OAuthRequestBuilder(kGoogleOAuthTokenEndpoint, "POST")
          .SetUrlEncodedBody("refresh_token=" + credential.get() +
                             "&client_id=" + GetClientId(audience.get()) +
                             "&grant_type=refresh_token");

  auto request_factory = fxl::MakeCopyable(
      [request = std::move(request)] { return request.Build(); });
  Request(
      std::move(request_factory), [callback](http::URLResponse response) {
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
    fidl::StringPtr id_token, fidl::StringPtr firebase_api_key,
    GetAppFirebaseTokenCallback callback) {
  if (id_token->empty() || firebase_api_key->empty()) {
    callback(AuthProviderStatus::BAD_REQUEST, nullptr);
    return;
  }

  std::map<std::string, std::string> query_params;
  query_params["key"] = firebase_api_key.get();
  auto request =
      OAuthRequestBuilder(kFirebaseAuthEndpoint, "POST")
          .SetQueryParams(query_params)
          .SetJsonBody(R"({"postBody": "id_token=)" + id_token.get() +
                       R"(&providerId=google.com",)" +
                       R"("returnIdpCredential": true,)" +
                       R"("returnSecureToken": true,)" +
                       R"("requestUri": "http://localhost"})");

  // Exchange credential to access token at Google OAuth token endpoint
  auto request_factory = fxl::MakeCopyable(
      [request = std::move(request)] { return request.Build(); });
  Request(std::move(request_factory), [callback](
                                          http::URLResponse response) {
    auto oauth_response = ParseOAuthResponse(std::move(response));
    if (oauth_response.status != AuthProviderStatus::OK) {
      FXL_VLOG(1) << "Got error: " << oauth_response.error_description;
      FXL_VLOG(1) << "Got response: "
                  << JsonValueToPrettyString(oauth_response.json_response);
      callback(oauth_response.status, nullptr);
      return;
    }

    auth::FirebaseTokenPtr fb_token = auth::FirebaseToken::New();
    fb_token->id_token = oauth_response.json_response["id_token"].GetString();
    fb_token->email = oauth_response.json_response["email"].GetString();
    fb_token->local_id = oauth_response.json_response["local_id"].GetString();

    callback(AuthProviderStatus::OK, std::move(fb_token));
  });
}

void GoogleAuthProviderImpl::RevokeAppOrPersistentCredential(
    fidl::StringPtr credential,
    RevokeAppOrPersistentCredentialCallback callback) {
  if (credential->empty()) {
    callback(AuthProviderStatus::BAD_REQUEST);
    return;
  }

  std::string url =
      kGoogleRevokeTokenEndpoint + std::string("?token=") + credential.get();
  auto request = OAuthRequestBuilder(url, "POST").SetUrlEncodedBody("");

  auto request_factory = fxl::MakeCopyable(
      [request = std::move(request)] { return request.Build(); });

  Request(
      std::move(request_factory), [callback](http::URLResponse response) {
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

void GoogleAuthProviderImpl::WillSendRequest(fidl::StringPtr incoming_url) {
  FXL_DCHECK(get_persistent_credential_callback_);

  const std::string& uri = incoming_url.get();
  const std::string prefix = std::string{kRedirectUri} + "?code=";
  const std::string cancel_prefix =
      std::string{kRedirectUri} + "?error=access_denied";

  auto cancel_pos = uri.find(cancel_prefix);
  // user denied OAuth permissions
  if (cancel_pos == 0) {
    get_persistent_credential_callback_(AuthProviderStatus::USER_CANCELLED,
                                        nullptr, nullptr);
    return;
  }
  auto pos = uri.find(prefix);
  // user performing gaia authentication inside webview, let it pass
  if (pos != 0) {
    return;
  }

  // user accepted OAuth permissions - close the webview and exchange auth
  // code to long lived credential.
  // Also, de-register previously registered error callbacks since calling
  // StopOverlay() might cause this connection to be closed.
  auth_ui_context_.set_error_handler([] {});
  auth_ui_context_->StopOverlay();

  auto code = uri.substr(prefix.size(), std::string::npos);
  // There is a '#' character at the end.
  code.pop_back();

  auto request =
      OAuthRequestBuilder(kGoogleOAuthTokenEndpoint, "POST")
          .SetUrlEncodedBody("code=" + code + "&redirect_uri=" + kRedirectUri +
                             "&client_id=" + kFuchsiaClientId +
                             "&grant_type=authorization_code");

  auto request_factory = fxl::MakeCopyable(
      [request = std::move(request)] { return request.Build(); });

  // Generate long lived credentials
  Request(std::move(request_factory), [this](http::URLResponse response) {
    auto oauth_response = ParseOAuthResponse(std::move(response));
    if (oauth_response.status != AuthProviderStatus::OK) {
      FXL_VLOG(1) << "Got error: " << oauth_response.error_description;
      FXL_VLOG(1) << "Got response: "
                  << JsonValueToPrettyString(oauth_response.json_response);
      get_persistent_credential_callback_(oauth_response.status, nullptr,
                                          nullptr);
      return;
    }

    if (!oauth_response.json_response.HasMember("refresh_token") ||
        (!oauth_response.json_response.HasMember("access_token"))) {
      FXL_VLOG(1) << "Got response: "
                  << JsonValueToPrettyString(oauth_response.json_response);
      get_persistent_credential_callback_(
          AuthProviderStatus::OAUTH_SERVER_ERROR, nullptr, nullptr);
    }

    GetUserProfile(oauth_response.json_response["refresh_token"].GetString(),
                   oauth_response.json_response["access_token"].GetString());
  });
}

void GoogleAuthProviderImpl::GetUserProfile(fidl::StringPtr credential,
                                            fidl::StringPtr access_token) {
  FXL_DCHECK(credential.get().size() > 0);
  FXL_DCHECK(access_token.get().size() > 0);

  auto request = OAuthRequestBuilder(kGooglePeopleGetEndpoint, "GET")
                     .SetAuthorizationHeader(access_token.get());

  auto request_factory = fxl::MakeCopyable(
      [request = std::move(request)] { return request.Build(); });

  Request(std::move(request_factory), [this, credential](
                                          http::URLResponse response) {
    auth::UserProfileInfoPtr user_profile_info = auth::UserProfileInfo::New();

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

fuchsia::ui::views_v1_token::ViewOwnerPtr
GoogleAuthProviderImpl::SetupWebView() {
  fuchsia::sys::Services web_view_services;
  fuchsia::sys::LaunchInfo web_view_launch_info;
  web_view_launch_info.url = kWebViewUrl;
  web_view_launch_info.directory_request = web_view_services.NewRequest();
  context_->launcher()->CreateComponent(std::move(web_view_launch_info),
                                        web_view_controller_.NewRequest());
  web_view_controller_.set_error_handler([this] {
    FXL_CHECK(false) << "web_view not found at " << kWebViewUrl << ".";
  });

  fuchsia::ui::views_v1_token::ViewOwnerPtr view_owner;
  fuchsia::ui::views_v1::ViewProviderPtr view_provider;
  web_view_services.ConnectToService(view_provider.NewRequest());
  fuchsia::sys::ServiceProviderPtr web_view_moz_services;
  view_provider->CreateView(view_owner.NewRequest(),
                            web_view_moz_services.NewRequest());

  ConnectToService(web_view_moz_services.get(), web_view_.NewRequest());

  return view_owner;
}

void GoogleAuthProviderImpl::Request(
    std::function<http::URLRequest()> request_factory,
    std::function<void(http::URLResponse response)> callback) {
  requests_.emplace(network_wrapper_->Request(
      std::move(request_factory), [this, callback = std::move(callback)](
                                      http::URLResponse response) mutable {
        OnResponse(std::move(callback), std::move(response));
      }));
}

void GoogleAuthProviderImpl::OnResponse(
    std::function<void(http::URLResponse response)> callback,
    http::URLResponse response) {
  callback(std::move(response));
}

}  // namespace google_auth_provider
