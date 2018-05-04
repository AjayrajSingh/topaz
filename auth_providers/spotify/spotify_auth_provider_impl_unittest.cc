// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "topaz/auth_providers/spotify/spotify_auth_provider_impl.h"

#include "garnet/lib/callback/capture.h"
#include "garnet/lib/callback/set_when_called.h"
#include "garnet/lib/gtest/test_with_loop.h"
#include "garnet/lib/network_wrapper/fake_network_wrapper.h"
#include "lib/fidl/cpp/binding.h"
#include "lib/fxl/macros.h"
#include "peridot/lib/rapidjson/rapidjson.h"

namespace spotify_auth_provider {
namespace {

class SpotifyAuthProviderImplTest : public gtest::TestWithLoop {
 public:
  SpotifyAuthProviderImplTest()
      : network_wrapper_(dispatcher()),
        app_context_(
            component::ApplicationContext::CreateFromStartupInfo().get()),
        spotify_auth_provider_impl_(app_context_,
                                   &network_wrapper_,
                                   auth_provider_.NewRequest()) {}

  ~SpotifyAuthProviderImplTest() override {}

 protected:
  network_wrapper::FakeNetworkWrapper network_wrapper_;
  component::ApplicationContext* app_context_;
  auth::AuthProviderPtr auth_provider_;
  SpotifyAuthProviderImpl spotify_auth_provider_impl_;

 private:
  FXL_DISALLOW_COPY_AND_ASSIGN(SpotifyAuthProviderImplTest);
};

TEST_F(SpotifyAuthProviderImplTest, EmptyWhenClientDisconnected) {
  bool on_empty_called = false;
  spotify_auth_provider_impl_.set_on_empty([this, &on_empty_called] {
    on_empty_called = true;
    QuitLoop();
  });
  auth_provider_.Unbind();
  RunLoopUntilIdle();
  EXPECT_TRUE(on_empty_called);
}

TEST_F(SpotifyAuthProviderImplTest, GetAppAccessTokenSuccess) {
  bool callback_called = false;
  auto status = auth::AuthProviderStatus::INTERNAL_ERROR;
  auth::AuthTokenPtr access_token;
  auto scopes = fidl::VectorPtr<fidl::StringPtr>::New(0);
  scopes.push_back("http://spotifyapis.test.com/scope1");
  scopes.push_back("http://spotifyapis.test.com/scope2");

  rapidjson::Document ok_response;
  ok_response.Parse("{\"access_token\":\"at_token\", \"expires_in\":3600}");
  network_wrapper_.SetStringResponse(
      modular::JsonValueToPrettyString(ok_response), 200);

  auth_provider_->GetAppAccessToken(
      "credential", "app_client_id", std::move(scopes),
      callback::Capture(callback::SetWhenCalled(&callback_called), &status,
                        &access_token));

  RunLoopUntilIdle();
  EXPECT_TRUE(callback_called);
  EXPECT_EQ(status, auth::AuthProviderStatus::OK);
  EXPECT_FALSE(access_token == NULL);
  EXPECT_EQ(access_token->token_type, auth::TokenType::ACCESS_TOKEN);
  EXPECT_EQ(access_token->token, "at_token");
  EXPECT_EQ(access_token->expires_in, 3600u);
}

TEST_F(SpotifyAuthProviderImplTest, GetAppAccessTokenError) {
  bool callback_called = false;
  auto status = auth::AuthProviderStatus::INTERNAL_ERROR;
  auth::AuthTokenPtr access_token;
  auto scopes = fidl::VectorPtr<fidl::StringPtr>::New(0);
  scopes.push_back("http://spotifyapis.test.com/scope1");
  scopes.push_back("http://spotifyapis.test.com/scope2");

  rapidjson::Document ok_response;
  ok_response.Parse("{\"error\":\"invalid_client\"}");
  network_wrapper_.SetStringResponse(
      modular::JsonValueToPrettyString(ok_response), 401);

  auth_provider_->GetAppAccessToken(
      "credential", "invalid_client_id", std::move(scopes),
      callback::Capture(callback::SetWhenCalled(&callback_called), &status,
                        &access_token));

  RunLoopUntilIdle();
  EXPECT_TRUE(callback_called);
  EXPECT_EQ(status, auth::AuthProviderStatus::OAUTH_SERVER_ERROR);
  EXPECT_TRUE(access_token == NULL);
}

TEST_F(SpotifyAuthProviderImplTest, GetAppIdTokenUnsupported) {
  bool callback_called = false;
  auto status = auth::AuthProviderStatus::INTERNAL_ERROR;
  auth::AuthTokenPtr id_token;

  auth_provider_->GetAppIdToken(
      "", "",
      callback::Capture(callback::SetWhenCalled(&callback_called), &status,
                        &id_token));

  RunLoopUntilIdle();
  EXPECT_TRUE(callback_called);
  EXPECT_EQ(status, auth::AuthProviderStatus::BAD_REQUEST);
  EXPECT_TRUE(id_token == NULL);
}

TEST_F(SpotifyAuthProviderImplTest, GetAppFirebaseTokenUnsupported) {
  bool callback_called = false;
  auto status = auth::AuthProviderStatus::INTERNAL_ERROR;
  auth::FirebaseTokenPtr fb_token;

  auth_provider_->GetAppFirebaseToken(
      "", "",
      callback::Capture(callback::SetWhenCalled(&callback_called), &status,
                        &fb_token));

  RunLoopUntilIdle();
  EXPECT_TRUE(callback_called);
  EXPECT_EQ(status, auth::AuthProviderStatus::BAD_REQUEST);
  EXPECT_TRUE(fb_token == NULL);
}

TEST_F(SpotifyAuthProviderImplTest,
       RevokeAppOrPersistentCredentialUnsupported) {
  bool callback_called = false;
  auto status = auth::AuthProviderStatus::INTERNAL_ERROR;

  auth_provider_->RevokeAppOrPersistentCredential(
      "",
      callback::Capture(callback::SetWhenCalled(&callback_called), &status));

  RunLoopUntilIdle();
  EXPECT_TRUE(callback_called);
  EXPECT_EQ(status, auth::AuthProviderStatus::BAD_REQUEST);
}

}  // namespace
}  // namespace spotify_auth_provider
