// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "topaz/lib/deprecated_loop/thread.h"

#include "gtest/gtest.h"
#include "topaz/lib/deprecated_loop/message_loop.h"

namespace deprecated_loop {
namespace {

TEST(Thread, Control) {
  Thread thread;
  EXPECT_FALSE(thread.IsRunning());
  EXPECT_TRUE(thread.Run());
  EXPECT_TRUE(thread.IsRunning());
  thread.TaskRunner()->PostTask(
      [] { MessageLoop::GetCurrent()->QuitNow(); });
  EXPECT_TRUE(thread.Join());
}

}  // namespace
}  // namespace deprecated_loop
