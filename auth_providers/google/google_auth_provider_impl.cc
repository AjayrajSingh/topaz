// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "topaz/auth_providers/google/google_auth_provider_impl.h"

#include <fuchsia/net/oldhttp/cpp/fidl.h>
#include <fuchsia/ui/app/cpp/fidl.h>
#include <lib/fdio/util.h>
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

// Sometimes auth codes contain non alpha characters such as a slash. When we
// receive these in a url parameter they are Hex encoded, but they need to be
// translated back to UTF-8 before using the auth code.
//
// TODO(jsankey): Remove this once we migrate to cookie delivery, or use a
// common encoding/decoding library if that arrives earlier.
void NormalizeAuthCode(std::string* code) {
  // This function uses the following literals:
  //   1 - The length of '%'
  //   2 - The length of a hex byte, e.g. '2F'
  //   3 - The length of a %-prefixed hex byte, e.g. '%2F'
  //  16 - The base of hexadecimal
  //  32 - The smallest printable character, i.e. the space character
  // 127 - The largest single byte UTF-8 codepoint
  std::string::size_type pos = 0;
  while ((pos = code->find("%", pos)) != std::string::npos &&
         pos <= code->length() - 3) {
    int codepoint = strtol(code->substr(pos + 1, 2).c_str(), nullptr, 16);
    if (codepoint >= 33 && codepoint <= 127) {
      code->replace(pos, 3, std::string(1, codepoint));
    }
    pos += 3;
  }
}

// Checks the supplied Google authentication URL. If the URL indicated the user
// has aborted the flow or an error occured these are reported as error
// statuses, otherwise a status of OK is returned. If the URL contains an auth
// code query parameter, this will be returned in |auth_code|.
fuchsia::auth::AuthProviderStatus ParseAuthCodeFromUrl(const std::string& url,
                                                       std::string& auth_code) {
  static const std::string success_prefix =
      std::string{kRedirectUri} + "?code=";
  static const std::string cancel_prefix =
      std::string{kRedirectUri} + "?error=access_denied";

  if (url.find(cancel_prefix) == 0) {
    return fuchsia::auth::AuthProviderStatus::USER_CANCELLED;
  }
  if (url.find(success_prefix) != 0) {
    // The authentication process is still ongoing.
    return fuchsia::auth::AuthProviderStatus::OK;
  }

  // Take everything up to the next query parameter or hash fragment.
  auto end_char = url.find_first_of("#&", success_prefix.size());
  auto length = end_char == std::string::npos
                    ? std::string::npos
                    : end_char - success_prefix.size();
  auto code = url.substr(success_prefix.size(), length);
  NormalizeAuthCode(&code);

  if (code.empty()) {
    return fuchsia::auth::AuthProviderStatus::OAUTH_SERVER_ERROR;
  } else {
    auth_code = code;
    return fuchsia::auth::AuthProviderStatus::OK;
  }
}

}  // namespace

using auth_providers::oauth::OAuthRequestBuilder;
using auth_providers::oauth::ParseOAuthResponse;
using fuchsia::auth::AuthenticationUIContext;
using fuchsia::auth::AuthProviderStatus;
using fuchsia::auth::AuthTokenPtr;
using fuchsia::auth::FirebaseTokenPtr;
using modular::JsonValueToPrettyString;

GoogleAuthProviderImpl::GoogleAuthProviderImpl(
    async_dispatcher_t* const main_dispatcher,
    component::StartupContext* context,
    network_wrapper::NetworkWrapper* network_wrapper, Settings settings,
    fidl::InterfaceRequest<fuchsia::auth::AuthProvider> request)
    : main_dispatcher_(main_dispatcher),
      context_(context),
      network_wrapper_(network_wrapper),
      settings_(std::move(settings)),
      binding_(this, std::move(request)) {
  FXL_DCHECK(main_dispatcher_);
  FXL_DCHECK(network_wrapper_);

  // The class shuts down when the client connection is disconnected.
  binding_.set_error_handler([this](zx_status_t status) {
    if (on_empty_) {
      on_empty_();
    }
  });
}

GoogleAuthProviderImpl::~GoogleAuthProviderImpl() {}

void GoogleAuthProviderImpl::GetPersistentCredential(
    fidl::InterfaceHandle<AuthenticationUIContext> auth_ui_context,
    fidl::StringPtr user_profile_id, GetPersistentCredentialCallback callback) {
  FXL_DCHECK(auth_ui_context);
  get_persistent_credential_callback_ = std::move(callback);

  std::string url = GetAuthorizeUrl(user_profile_id);
  zx::eventpair view_holder_token;
  if (settings_.use_chromium) {
    view_holder_token = SetupChromium();
    if (!view_holder_token) {
      return;
    }
    chromium::web::NavigationControllerPtr controller;
    chromium_frame_->GetNavigationController(controller.NewRequest());
    controller->LoadUrl(url, {});
    FXL_LOG(INFO) << "Loading URL in Chromium: " << url;
  } else {
    view_holder_token = SetupWebView();
    web_view_->SetUrl(url);
    FXL_LOG(INFO) << "Loading URL in WebView: " << url;
  }

  auth_ui_context_ = auth_ui_context.Bind();
  auth_ui_context_.set_error_handler([this](zx_status_t status) {
    FXL_LOG(INFO) << "Overlay cancelled by the caller";
    ReleaseResources();
    get_persistent_credential_callback_(AuthProviderStatus::INTERNAL_ERROR,
                                        nullptr, nullptr);
    return;
  });

  auth_ui_context_->StartOverlay2(std::move(view_holder_token));
}

void GoogleAuthProviderImpl::GetAppAccessToken(
    std::string credential, fidl::StringPtr app_client_id,
    const std::vector<std::string> app_scopes,
    GetAppAccessTokenCallback callback) {
  if (credential.empty()) {
    callback(AuthProviderStatus::BAD_REQUEST, nullptr);
    return;
  }

  auto request =
      OAuthRequestBuilder(kGoogleOAuthTokenEndpoint, "POST")
          .SetUrlEncodedBody("refresh_token=" + credential +
                             "&client_id=" + GetClientId(app_client_id.get()) +
                             "&grant_type=refresh_token");

  auto request_factory = fxl::MakeCopyable(
      [request = std::move(request)] { return request.Build(); });

  Request(std::move(request_factory), [callback = std::move(callback)](
                                          http::URLResponse response) {
    auto oauth_response = ParseOAuthResponse(std::move(response));
    if (oauth_response.status != AuthProviderStatus::OK) {
      FXL_LOG(WARNING) << "Got error: " << oauth_response.error_description;
      FXL_LOG(WARNING) << "Got response: "
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

void GoogleAuthProviderImpl::GetAppIdToken(std::string credential,
                                           fidl::StringPtr audience,
                                           GetAppIdTokenCallback callback) {
  if (credential.empty()) {
    callback(AuthProviderStatus::BAD_REQUEST, nullptr);
    return;
  }

  auto request =
      OAuthRequestBuilder(kGoogleOAuthTokenEndpoint, "POST")
          .SetUrlEncodedBody("refresh_token=" + credential +
                             "&client_id=" + GetClientId(audience.get()) +
                             "&grant_type=refresh_token");

  auto request_factory = fxl::MakeCopyable(
      [request = std::move(request)] { return request.Build(); });
  Request(std::move(request_factory), [callback = std::move(callback)](
                                          http::URLResponse response) {
    auto oauth_response = ParseOAuthResponse(std::move(response));
    if (oauth_response.status != AuthProviderStatus::OK) {
      FXL_LOG(WARNING) << "Got error: " << oauth_response.error_description;
      FXL_LOG(WARNING) << "Got response: "
                       << JsonValueToPrettyString(oauth_response.json_response);
      callback(oauth_response.status, nullptr);
      return;
    }

    AuthTokenPtr id_token = fuchsia::auth::AuthToken::New();
    id_token->token = oauth_response.json_response["id_token"].GetString();
    id_token->token_type = fuchsia::auth::TokenType::ID_TOKEN;
    id_token->expires_in =
        oauth_response.json_response["expires_in"].GetUint64();

    callback(AuthProviderStatus::OK, std::move(id_token));
  });
}

void GoogleAuthProviderImpl::GetAppFirebaseToken(
    std::string id_token, std::string firebase_api_key,
    GetAppFirebaseTokenCallback callback) {
  if (id_token.empty() || firebase_api_key.empty()) {
    callback(AuthProviderStatus::BAD_REQUEST, nullptr);
    return;
  }

  std::map<std::string, std::string> query_params;
  query_params["key"] = firebase_api_key;
  auto request =
      OAuthRequestBuilder(kFirebaseAuthEndpoint, "POST")
          .SetQueryParams(query_params)
          .SetJsonBody(R"({"postBody": "id_token=)" + id_token +
                       R"(&providerId=google.com",)" +
                       R"("returnIdpCredential": true,)" +
                       R"("returnSecureToken": true,)" +
                       R"("requestUri": "http://localhost"})");

  // Exchange credential to access token at Google OAuth token endpoint
  auto request_factory = fxl::MakeCopyable(
      [request = std::move(request)] { return request.Build(); });
  Request(std::move(request_factory), [callback = std::move(callback)](
                                          http::URLResponse response) {
    auto oauth_response = ParseOAuthResponse(std::move(response));
    if (oauth_response.status != AuthProviderStatus::OK) {
      FXL_LOG(WARNING) << "Got error: " << oauth_response.error_description;
      FXL_LOG(WARNING) << "Got response: "
                       << JsonValueToPrettyString(oauth_response.json_response);
      callback(oauth_response.status, nullptr);
      return;
    }

    FirebaseTokenPtr fb_token = fuchsia::auth::FirebaseToken::New();
    fb_token->id_token = oauth_response.json_response["id_token"].GetString();
    fb_token->email = oauth_response.json_response["email"].GetString();
    fb_token->local_id = oauth_response.json_response["local_id"].GetString();
    fb_token->expires_in =
        oauth_response.json_response["expires_in"].GetUint64();

    callback(AuthProviderStatus::OK, std::move(fb_token));
  });
}

void GoogleAuthProviderImpl::RevokeAppOrPersistentCredential(
    std::string credential,
    RevokeAppOrPersistentCredentialCallback callback) {
  if (credential.empty()) {
    callback(AuthProviderStatus::BAD_REQUEST);
    return;
  }

  std::string url =
      kGoogleRevokeTokenEndpoint + std::string("?token=") + credential;
  auto request = OAuthRequestBuilder(url, "POST").SetUrlEncodedBody("");

  auto request_factory = fxl::MakeCopyable(
      [request = std::move(request)] { return request.Build(); });

  Request(std::move(request_factory), [callback = std::move(callback)](
                                          http::URLResponse response) {
    auto oauth_response = ParseOAuthResponse(std::move(response));
    if (oauth_response.status != AuthProviderStatus::OK) {
      FXL_LOG(WARNING) << "Got error: " << oauth_response.error_description;
      FXL_LOG(WARNING) << "Got response: "
                       << JsonValueToPrettyString(oauth_response.json_response);
      callback(oauth_response.status);
      return;
    }

    callback(AuthProviderStatus::OK);
  });
}

void GoogleAuthProviderImpl::GetPersistentCredentialFromAttestationJWT(
    fidl::InterfaceHandle<AttestationSigner> attestation_signer,
    AttestationJWTParams jwt_params,
    fidl::InterfaceHandle<AuthenticationUIContext> auth_ui_context,
    fidl::StringPtr user_profile_id,
    GetPersistentCredentialFromAttestationJWTCallback callback) {
  // Remote attestation flow not supported for traditional OAuth.
  callback(AuthProviderStatus::BAD_REQUEST, nullptr, nullptr, nullptr, nullptr);
}

void GoogleAuthProviderImpl::GetAppAccessTokenFromAssertionJWT(
    fidl::InterfaceHandle<AttestationSigner> attestation_signer,
    AssertionJWTParams jwt_params, std::string credential,
    const std::vector<std::string> scopes,
    GetAppAccessTokenFromAssertionJWTCallback callback) {
  // Remote attestation flow not supported for traditional OAuth.
  callback(AuthProviderStatus::BAD_REQUEST, nullptr, nullptr, nullptr);
}

void GoogleAuthProviderImpl::WillSendRequest(std::string incoming_url) {
  FXL_CHECK(get_persistent_credential_callback_);

  std::string auth_code;
  AuthProviderStatus status =
      ParseAuthCodeFromUrl(incoming_url, auth_code);

  // If either an error occured or the user successfully received an auth code
  // we need to close the WebView.
  if (status != AuthProviderStatus::OK || !auth_code.empty()) {
    // Also, de-register previously registered error callbacks since calling
    // StopOverlay() might cause this connection to be closed.
    FXL_LOG(INFO) << "Received auth code: " << auth_code;
    auth_ui_context_.set_error_handler(nullptr);
    FXL_LOG(INFO) << "Calling stop overlay..";
    auth_ui_context_->StopOverlay();

    if (status != AuthProviderStatus::OK) {
      FXL_LOG(INFO) << "Encountered error while fetching auth code..";
      get_persistent_credential_callback_(status, nullptr, nullptr);
    } else if (!auth_code.empty()) {
      ExchangeAuthCode(auth_code);
    }
  }
}

void GoogleAuthProviderImpl::OnNavigationStateChanged(
    NavigationEvent change, OnNavigationStateChangedCallback callback) {
  FXL_CHECK(get_persistent_credential_callback_);

  // Not all events change the URL, those that don't can be ignored.
  if (change.url.is_null()) {
    callback();
    return;
  }

  std::string auth_code;
  AuthProviderStatus status = ParseAuthCodeFromUrl(change.url.get(), auth_code);

  // If either an error occured or the user successfully received an auth code
  // we need to close the browser instance.
  if (status != AuthProviderStatus::OK || !auth_code.empty()) {
    ReleaseResources();
    if (status != AuthProviderStatus::OK) {
      get_persistent_credential_callback_(status, nullptr, nullptr);
    } else if (!auth_code.empty()) {
      ExchangeAuthCode(auth_code);
    }
  }

  callback();
}

std::string GoogleAuthProviderImpl::GetAuthorizeUrl(
    fidl::StringPtr user_profile) {
  // TODO(ukode,jsankey): use app_scopes instead of |kScopes|.
  const std::vector<std::string> scopes(kScopes.begin(), kScopes.end());
  std::string scopes_str = fxl::JoinStrings(scopes, "+");

  std::string url = settings_.use_dedicated_endpoint ? kGoogleFuchsiaEndpoint
                                                     : kGoogleOAuthAuthEndpoint;
  url += "?scope=" + scopes_str;
  url += "&glif=";
  url += settings_.use_glif ? "true" : "false";
  url += "&response_type=code&redirect_uri=";
  url += kRedirectUri;
  url += "&client_id=";
  url += kFuchsiaClientId;
  // TODO(ukode,jsankey): Set user_profile_id in the state query arg for re-auth
  // This probably involves moving the current implementation of UrlEncoding in
  // OAuthRequestBuilder to a reusable library and using this to urlencode the
  // supplied user_profile into the login_hint query parameter.
  return url;
}

void GoogleAuthProviderImpl::ExchangeAuthCode(std::string auth_code) {
  auto request = OAuthRequestBuilder(kGoogleOAuthTokenEndpoint, "POST")
                     .SetUrlEncodedBody("code=" + auth_code +
                                        "&redirect_uri=" + kRedirectUri +
                                        "&client_id=" + kFuchsiaClientId +
                                        "&grant_type=authorization_code");

  auto request_factory = fxl::MakeCopyable(
      [request = std::move(request)] { return request.Build(); });

  Request(std::move(request_factory), [this](http::URLResponse response) {
    auto oauth_response = ParseOAuthResponse(std::move(response));
    if (oauth_response.status != AuthProviderStatus::OK) {
      FXL_LOG(WARNING) << "auth: Got error exchanging auth code: "
                       << oauth_response.error_description;
      FXL_LOG(WARNING) << "auth: Got response exchanging auth code: "
                       << JsonValueToPrettyString(oauth_response.json_response);
      get_persistent_credential_callback_(oauth_response.status, nullptr,
                                          nullptr);
      return;
    }

    if (!oauth_response.json_response.HasMember("refresh_token") ||
        (!oauth_response.json_response.HasMember("access_token"))) {
      FXL_LOG(WARNING) << "Got response without refresh and access tokens: "
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

  Request(std::move(request_factory), [this,
                                       credential](http::URLResponse response) {
    fuchsia::auth::UserProfileInfoPtr user_profile_info =
        fuchsia::auth::UserProfileInfo::New();

    auto oauth_response = ParseOAuthResponse(std::move(response));
    if (oauth_response.status != AuthProviderStatus::OK) {
      FXL_LOG(WARNING) << "Got error fetching profile: "
                       << oauth_response.error_description;
      FXL_LOG(WARNING) << "Got response fetching profile: "
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

zx::eventpair GoogleAuthProviderImpl::SetupWebView() {
  // Launch an instance of the WebView component.
  component::Services web_view_services;
  fuchsia::sys::LaunchInfo web_view_launch_info;
  web_view_launch_info.url = kWebViewUrl;
  web_view_launch_info.directory_request = web_view_services.NewRequest();
  context_->launcher()->CreateComponent(std::move(web_view_launch_info),
                                        web_view_controller_.NewRequest());
  web_view_controller_.set_error_handler([this](zx_status_t status) {
    FXL_CHECK(false) << "web_view not found at " << kWebViewUrl << ".";
  });

  zx::eventpair view_token, view_holder_token;
  if (zx::eventpair::create(0u, &view_token, &view_holder_token) != ZX_OK)
    FXL_NOTREACHED() << "Failed to create view tokens";

  // Connect to the launched WebView component, request that it creates a new
  // view, and connect to the WebView interface on this new view.
  fuchsia::ui::app::ViewProviderPtr view_provider;
  fuchsia::sys::ServiceProviderPtr incoming_view_services;
  web_view_services.ConnectToService(view_provider.NewRequest());
  view_provider->CreateView(std::move(view_token),
                            incoming_view_services.NewRequest(), nullptr);
  component::ConnectToService(incoming_view_services.get(),
                              web_view_.NewRequest());

  // Set ourselves as a delegate so that we receive URL change events that
  // we can parse for an authorization code.
  fuchsia::webview::WebRequestDelegatePtr web_request_delegate;
  web_request_delegate_bindings_.AddBinding(this,
                                            web_request_delegate.NewRequest());
  web_view_->SetWebRequestDelegate(std::move(web_request_delegate));
  web_view_->ClearCookies();

  return view_holder_token;
}

zx::eventpair GoogleAuthProviderImpl::SetupChromium() {
  // Connect to the Chromium service and create a new frame.
  auto context_provider =
      context_->ConnectToEnvironmentService<chromium::web::ContextProvider>();

  zx_handle_t incoming_service_clone =
      fdio_service_clone(context_->incoming_services()->directory().get());
  if (incoming_service_clone == ZX_HANDLE_INVALID) {
    FXL_LOG(ERROR) << "Failed to clone service directory.";
    return zx::eventpair();
  }

  chromium::web::CreateContextParams params;
  params.service_directory = zx::channel(incoming_service_clone);
  context_provider->Create(std::move(params), chromium_context_.NewRequest());
  chromium_context_->CreateFrame(chromium_frame_.NewRequest());

  // Bind ourselves as a NavigationEventObserver on this frame.
  chromium::web::NavigationEventObserverPtr navigation_event_observer;
  navigation_event_observer_bindings_.AddBinding(
      this, navigation_event_observer.NewRequest());
  chromium_frame_->SetNavigationEventObserver(
      std::move(navigation_event_observer));

  // And create a view for the frame.
  zx::eventpair view_token, view_holder_token;
  if (zx::eventpair::create(0u, &view_token, &view_holder_token) != ZX_OK)
    FXL_NOTREACHED() << "Failed to create view tokens";
  chromium_frame_->CreateView2(std::move(view_token), nullptr, nullptr);

  return view_holder_token;
}

void GoogleAuthProviderImpl::ReleaseResources() {
  // Close any open view
  if (auth_ui_context_) {
    FXL_LOG(INFO) << "Releasing auth UI context..";
    auth_ui_context_.set_error_handler(nullptr);
    FXL_LOG(INFO) << " Inside ReleaseResources: Stopping overlay";
    auth_ui_context_->StopOverlay();
    auth_ui_context_ = nullptr;
  }
  // Release all smart pointers for WebView and Chromium resources.
  web_view_controller_ = nullptr;
  web_view_ = nullptr;
  chromium_frame_ = nullptr;
  chromium_context_ = nullptr;
}

void GoogleAuthProviderImpl::Request(
    fit::function<http::URLRequest()> request_factory,
    fit::function<void(http::URLResponse response)> callback) {
  requests_.emplace(network_wrapper_->Request(std::move(request_factory),
                                              std::move(callback)));
}

}  // namespace google_auth_provider
