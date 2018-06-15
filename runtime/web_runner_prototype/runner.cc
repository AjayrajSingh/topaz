// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "topaz/runtime/web_runner_prototype/runner.h"

#include <utility>

namespace web {

Runner::Runner(std::unique_ptr<fuchsia::sys::StartupContext> context)
    : context_(std::move(context)) {}

Runner::~Runner() = default;

void Runner::StartComponent(
    fuchsia::sys::Package package, fuchsia::sys::StartupInfo startup_info,
    fidl::InterfaceRequest<fuchsia::sys::ComponentController> controller) {}

}  // namespace web
