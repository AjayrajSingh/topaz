// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "topaz/auth_providers/spotify/factory_impl.h"

#include "garnet/lib/callback/capture.h"
#include "garnet/lib/callback/set_when_called.h"
#include "garnet/lib/gtest/test_with_message_loop.h"
#include "garnet/lib/network_wrapper/fake_network_wrapper.h"
#include "lib/fidl/cpp/binding.h"
#include "lib/fxl/macros.h"

namespace spotify_auth_provider {

class SpotifyFactoryImplTest : public gtest::TestWithMessageLoop {
 public:
  SpotifyFactoryImplTest()
      : network_wrapper_(message_loop_.async()),
        app_context_(
            component::ApplicationContext::CreateFromStartupInfo().get()),
        factory_impl_(message_loop_.task_runner(), app_context_,
                      &network_wrapper_) {
    factory_impl_.Bind(factory_.NewRequest());
  }

  ~SpotifyFactoryImplTest() override {}

 protected:
  network_wrapper::FakeNetworkWrapper network_wrapper_;
  component::ApplicationContext* app_context_;
  auth::AuthProviderPtr auth_provider_;
  auth::AuthProviderFactoryPtr factory_;

  FactoryImpl factory_impl_;

 private:
  FXL_DISALLOW_COPY_AND_ASSIGN(SpotifyFactoryImplTest);
};

TEST_F(SpotifyFactoryImplTest, GetAuthProvider) {
  auth::AuthProviderStatus status;
  auth_provider_.Unbind();
  bool callback_called = false;
  factory_->GetAuthProvider(
      auth_provider_.NewRequest(),
      callback::Capture(callback::SetWhenCalled(&callback_called), &status));
  RunLoopUntilIdle();
  EXPECT_TRUE(callback_called);
  EXPECT_EQ(auth::AuthProviderStatus::OK, status);
}

} // namespace spotify_auth_provider
