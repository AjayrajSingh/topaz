// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "topaz/auth_providers/google/google_auth_provider_impl.h"

#include "garnet/lib/gtest/test_with_message_loop.h"
#include "garnet/lib/network_wrapper/fake_network_wrapper.h"
#include "lib/fidl/cpp/binding.h"
#include "lib/fxl/macros.h"

namespace google_auth_provider {

class GoogleAuthProviderImplTest : public gtest::TestWithMessageLoop {
 public:
  GoogleAuthProviderImplTest()
      : network_wrapper_(message_loop_.async()),
        app_context_(
            component::ApplicationContext::CreateFromStartupInfo().get()),
        google_auth_provider_impl_(message_loop_.task_runner(), app_context_,
                                   &network_wrapper_,
                                   auth_provider_.NewRequest()) {}

  ~GoogleAuthProviderImplTest() override {}

 protected:
  network_wrapper::FakeNetworkWrapper network_wrapper_;
  component::ApplicationContext* app_context_;
  auth::AuthProviderPtr auth_provider_;
  GoogleAuthProviderImpl google_auth_provider_impl_;

 private:
  FXL_DISALLOW_COPY_AND_ASSIGN(GoogleAuthProviderImplTest);
};

TEST_F(GoogleAuthProviderImplTest, EmptyWhenClientDisconnected) {
  bool on_empty_called = false;
  google_auth_provider_impl_.set_on_empty([this, &on_empty_called] {
    on_empty_called = true;
    message_loop_.PostQuitTask();
  });
  auth_provider_.Unbind();
  EXPECT_FALSE(RunLoopWithTimeout());
  EXPECT_TRUE(on_empty_called);
}

}  // namespace google_auth_provider
