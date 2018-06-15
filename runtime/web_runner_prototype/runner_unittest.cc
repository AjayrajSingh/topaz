// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "topaz/runtime/web_runner_prototype/runner.h"
#include "lib/app/cpp/testing/test_with_context.h"

namespace web {
namespace testing {

class RunnerTest : public fuchsia::sys::testing::TestWithContext {
 public:
  void SetUp() override {
    TestWithContext::SetUp();
    runner_ = std::make_unique<Runner>(TakeContext());
  }

  void TearDown() override {
    runner_.reset();
    TestWithContext::TearDown();
  }

 private:
  std::unique_ptr<Runner> runner_;
};

TEST_F(RunnerTest, Trivial) {}

}  // namespace testing
}  // namespace web
