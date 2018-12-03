// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef TOPAZ_RUNTIME_DART_UTILS_HANDLE_EXCEPTION_H_
#define TOPAZ_RUNTIME_DART_UTILS_HANDLE_EXCEPTION_H_

#include <string>

#include <lib/component/cpp/startup_context.h>
#include <sys/types.h>
#include <third_party/dart/runtime/include/dart_api.h>

namespace fuchsia {
namespace dart {

// If |result| is a Dart Exception, passes the exception message and stack trace
// to the crash analyzer service for further handling.
//
// Otherwise early returns with OK status.
zx_status_t HandleIfException(component::StartupContext* context,
                              const std::string& component_url,
                              Dart_Handle result);

}  // namespace dart
}  // namespace fuchsia

#endif  // TOPAZ_RUNTIME_DART_UTILS_HANDLE_EXCEPTION_H_
