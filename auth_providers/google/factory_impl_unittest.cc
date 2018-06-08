// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "topaz/auth_providers/google/factory_impl.h"

#include "lib/callback/capture.h"
#include "lib/callback/set_when_called.h"
#include "lib/fidl/cpp/binding.h"
#include "lib/fxl/macros.h"
#include "lib/gtest/test_with_loop.h"
#include "lib/network_wrapper/fake_network_wrapper.h"

namespace google_auth_provider {

class GoogleFactoryImplTest : public gtest::TestWithLoop {
 public:
  GoogleFactoryImplTest()
      : network_wrapper_(dispatcher()),
        context_(fuchsia::sys::StartupContext::CreateFromStartupInfo().get()),
        factory_impl_(dispatcher(), context_, &network_wrapper_) {
    factory_impl_.Bind(factory_.NewRequest());
  }

  ~GoogleFactoryImplTest() override {}

 protected:
  network_wrapper::FakeNetworkWrapper network_wrapper_;
  fuchsia::sys::StartupContext* context_;
  fuchsia::auth::AuthProviderPtr auth_provider_;
  fuchsia::auth::AuthProviderFactoryPtr factory_;

  FactoryImpl factory_impl_;

 private:
  FXL_DISALLOW_COPY_AND_ASSIGN(GoogleFactoryImplTest);
};

TEST_F(GoogleFactoryImplTest, GetAuthProvider) {
  fuchsia::auth::AuthProviderStatus status;
  auth_provider_.Unbind();
  bool callback_called = false;
  factory_->GetAuthProvider(
      auth_provider_.NewRequest(),
      callback::Capture(callback::SetWhenCalled(&callback_called), &status));
  RunLoopUntilIdle();
  EXPECT_TRUE(callback_called);
  EXPECT_EQ(fuchsia::auth::AuthProviderStatus::OK, status);
}

}  // namespace google_auth_provider
