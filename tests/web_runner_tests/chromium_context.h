// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef TOPAZ_TESTS_WEB_RUNNER_TESTS_CHROMIUM_CONTEXT_H_
#define TOPAZ_TESTS_WEB_RUNNER_TESTS_CHROMIUM_CONTEXT_H_

#include <chromium/web/cpp/fidl.h>
#include <lib/component/cpp/startup_context.h>

// This sub-fixture uses chromium.web FIDL services to interact with Chromium.
//
// See also:
// https://chromium.googlesource.com/chromium/src/+/master/fuchsia/engine/test/webrunner_browser_test.h
class ChromiumContext {
 public:
  ChromiumContext(component::StartupContext* startup_context);
  void Navigate(const std::string& url);

  chromium::web::Frame* frame() { return chromium_frame_.get(); }

 private:
  // This has to stay open while we're interacting with Chromium.
  chromium::web::ContextPtr chromium_context_;

  chromium::web::FramePtr chromium_frame_;
};

#endif  // TOPAZ_TESTS_WEB_RUNNER_TESTS_CHROMIUM_CONTEXT_H_
