// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "topaz/runtime/dart/utils/handle_exception.h"

#include <fuchsia/feedback/cpp/fidl.h>
#include <fuchsia/mem/cpp/fidl.h>
#include <lib/syslog/global.h>
#include <lib/zx/vmo.h>
#include <sys/types.h>
#include <third_party/tonic/converter/dart_converter.h>
#include <zircon/status.h>

#include <string>

#include "topaz/runtime/dart/utils/logging.h"

namespace {
static bool SetStackTrace(const std::string& data,
                          fuchsia::feedback::RuntimeCrashReport* report) {
  uint64_t num_bytes = data.size();
  zx::vmo vmo;

  if (zx::vmo::create(num_bytes, 0u, &vmo) < 0) {
    return false;
  }

  if (num_bytes > 0) {
    if (vmo.write(data.data(), 0, num_bytes) < 0) {
      return false;
    }
  }

  fuchsia::mem::Buffer buffer;
  buffer.vmo = std::move(vmo);
  buffer.size = num_bytes;
  report->set_exception_stack_trace(std::move(buffer));

  return true;
}

fuchsia::feedback::CrashReport BuildCrashReport(
    const std::string& component_url, const std::string& error,
    const std::string& stack_trace) {
  // The runtime type has already been pre-pended to the error message so we
  // expect the format to be '$RuntimeType: $Message'.
  std::string error_type;
  std::string error_message;
  const size_t delimiter_pos = error.find_first_of(':');
  if (delimiter_pos == std::string::npos) {
    FX_LOGF(ERROR, LOG_TAG,
            "error parsing Dart exception: expected format '$RuntimeType: "
            "$Message', got '%s'",
            error.c_str());
    // We still need to specify a type, otherwise the stack trace does not
    // show up in the crash server UI.
    error_type = "UnknownError";
    error_message = error;
  } else {
    error_type = error.substr(0, delimiter_pos);
    error_message =
        error.substr(delimiter_pos + 2 /*to get rid of the leading ': '*/);
  }

  fuchsia::feedback::RuntimeCrashReport dart_report;
  dart_report.set_exception_type(error_type);
  dart_report.set_exception_message(error_message);
  if (!SetStackTrace(stack_trace, &dart_report)) {
    FX_LOG(ERROR, LOG_TAG, "Failed to convert Dart stack trace to VMO");
  }

  fuchsia::feedback::SpecificCrashReport specific_report;
  specific_report.set_dart(std::move(dart_report));
  fuchsia::feedback::CrashReport report;
  report.set_program_name(component_url);
  report.set_specific_report(std::move(specific_report));
  return report;
}

}  // namespace

namespace dart_utils {

void HandleIfException(std::shared_ptr<::sys::ServiceDirectory> services,
                       const std::string& component_url, Dart_Handle result) {
  if (!Dart_IsError(result) || !Dart_ErrorHasException(result)) {
    return;
  }

  const std::string error =
      tonic::StdStringFromDart(Dart_ToString(Dart_ErrorGetException(result)));
  const std::string stack_trace =
      tonic::StdStringFromDart(Dart_ToString(Dart_ErrorGetStackTrace(result)));

  return HandleException(services, component_url, error, stack_trace);
}

void HandleException(std::shared_ptr<::sys::ServiceDirectory> services,
                     const std::string& component_url, const std::string& error,
                     const std::string& stack_trace) {
  fuchsia::feedback::CrashReport crash_report =
      BuildCrashReport(component_url, error, stack_trace);

  fuchsia::feedback::CrashReporterPtr crash_reporter =
      services->Connect<fuchsia::feedback::CrashReporter>();
  crash_reporter->File(
      std::move(crash_report),
      [](fuchsia::feedback::CrashReporter_File_Result result) {
        if (result.is_err()) {
          FX_LOGF(ERROR, LOG_TAG, "Failed to report Dart exception: %d (%s)",
                  result.err(), zx_status_get_string(result.err()));
        }
      });
}

}  // namespace dart_utils
