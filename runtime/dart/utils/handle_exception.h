// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef TOPAZ_RUNTIME_DART_UTILS_HANDLE_EXCEPTION_H_
#define TOPAZ_RUNTIME_DART_UTILS_HANDLE_EXCEPTION_H_

#include <memory>
#include <string>

#include <lib/sys/cpp/service_directory.h>
#include <sys/types.h>
#include <third_party/dart/runtime/include/dart_api.h>

namespace dart_utils {

// If |result| is a Dart Exception, passes the exception message and stack trace
// to the crash analyzer service for further handling.
//
// Otherwise early returns with OK status.
zx_status_t HandleIfException(std::shared_ptr<::sys::ServiceDirectory> services,
                              const std::string& component_url,
                              Dart_Handle result);

// Passes the exception message and stack trace to the crash analyzer service
// for further handling.
zx_status_t HandleException(std::shared_ptr<::sys::ServiceDirectory> services,
                            const std::string& component_url,
                            const std::string& error,
                            const std::string& stack_trace);

}  // namespace dart_utils

#endif  // TOPAZ_RUNTIME_DART_UTILS_HANDLE_EXCEPTION_H_
