// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "topaz/auth_providers/google/google_auth_provider_impl.h"

#include "lib/fidl/cpp/binding.h"
#include "lib/fxl/macros.h"
#include "lib/gtest/test_loop_fixture.h"
#include "lib/network_wrapper/fake_network_wrapper.h"

namespace google_auth_provider {
namespace {

class GoogleAuthProviderImplTest : public gtest::TestLoopFixture {
 public:
  GoogleAuthProviderImplTest()
      : network_wrapper_(dispatcher()),
        context_(fuchsia::sys::StartupContext::CreateFromStartupInfo().get()),
        google_auth_provider_impl_(dispatcher(), context_, &network_wrapper_,
                                   auth_provider_.NewRequest()) {}

  ~GoogleAuthProviderImplTest() override {}

 protected:
  network_wrapper::FakeNetworkWrapper network_wrapper_;
  fuchsia::sys::StartupContext* context_;
  fuchsia::auth::AuthProviderPtr auth_provider_;
  GoogleAuthProviderImpl google_auth_provider_impl_;

 private:
  FXL_DISALLOW_COPY_AND_ASSIGN(GoogleAuthProviderImplTest);
};

TEST_F(GoogleAuthProviderImplTest, EmptyWhenClientDisconnected) {
  bool on_empty_called = false;
  google_auth_provider_impl_.set_on_empty([this, &on_empty_called] {
    on_empty_called = true;
    QuitLoop();
  });
  auth_provider_.Unbind();
  RunLoopUntilIdle();
  EXPECT_TRUE(on_empty_called);
}

}  // namespace
}  // namespace google_auth_provider
