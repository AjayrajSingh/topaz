// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "apps/dart_content_handler/builtin_libraries.h"

#include "dart/runtime/bin/io_natives.h"
#include "dart/runtime/include/dart_api.h"
#include "lib/ftl/arraysize.h"
#include "lib/ftl/logging.h"
#include "lib/tonic/dart_converter.h"
#include "lib/tonic/dart_error.h"
#include "mojo/public/platform/dart/mojo_natives.h"

using tonic::ToDart;

namespace dart_content_handler {
namespace {

MojoHandle g_handle_watcher_producer_handle = MOJO_HANDLE_INVALID;

void SetHandleWatcherControlHandle(Dart_Handle mojo_internal) {
  FTL_CHECK(g_handle_watcher_producer_handle != MOJO_HANDLE_INVALID);
  Dart_Handle handle_watcher_type =
      Dart_GetType(mojo_internal, ToDart("MojoHandleWatcher"), 0, nullptr);
  Dart_Handle field_name = ToDart("mojoControlHandle");
  Dart_Handle control_port_value = ToDart(g_handle_watcher_producer_handle);
  DART_CHECK_VALID(
      Dart_SetField(handle_watcher_type, field_name, control_port_value));
}

#define REGISTER_FUNCTION(name, count) {#name, name, count},
#define DECLARE_FUNCTION(name, count) \
  extern void name(Dart_NativeArguments args);

#define BUILTIN_NATIVE_LIST(V) V(Logger_PrintString, 1)

BUILTIN_NATIVE_LIST(DECLARE_FUNCTION);

const struct NativeEntry {
  const char* name;
  Dart_NativeFunction function;
  int argument_count;
} kBuiltinEntries[] = {BUILTIN_NATIVE_LIST(REGISTER_FUNCTION)};

Dart_NativeFunction BuiltinNativeLookup(Dart_Handle name,
                                        int argument_count,
                                        bool* auto_setup_scope) {
  const char* function_name = nullptr;
  DART_CHECK_VALID(Dart_StringToCString(name, &function_name));
  FTL_DCHECK(function_name != nullptr);
  FTL_DCHECK(auto_setup_scope != nullptr);
  *auto_setup_scope = true;
  size_t num_entries = arraysize(kBuiltinEntries);
  for (size_t i = 0; i < num_entries; i++) {
    const NativeEntry& entry = kBuiltinEntries[i];
    if (!strcmp(function_name, entry.name) &&
        (entry.argument_count == argument_count)) {
      return entry.function;
    }
  }
  return nullptr;
}

const uint8_t* BuiltinNativeSymbol(Dart_NativeFunction native_function) {
  size_t num_entries = arraysize(kBuiltinEntries);
  for (size_t i = 0; i < num_entries; i++) {
    const NativeEntry& entry = kBuiltinEntries[i];
    if (entry.function == native_function)
      return reinterpret_cast<const uint8_t*>(entry.name);
  }
  return nullptr;
}

void Logger_PrintString(Dart_NativeArguments args) {
  intptr_t length = 0;
  uint8_t* chars = nullptr;
  Dart_Handle str = Dart_GetNativeArgument(args, 0);
  Dart_Handle result = Dart_StringToUTF8(str, &chars, &length);
  if (Dart_IsError(result)) {
    Dart_PropagateError(result);
  } else {
    fwrite(chars, 1, length, stdout);
    fputc('\n', stdout);
    fflush(stdout);
  }
}

}  // namespace

void SetHandleWatcherProducerHandle(MojoHandle handle) {
  FTL_CHECK(g_handle_watcher_producer_handle == MOJO_HANDLE_INVALID);
  g_handle_watcher_producer_handle = handle;
}

void InitBuiltinLibrariesForIsolate(const std::string& base_uri,
                                    const std::string& script_uri) {
  // dart:mojo.internal --------------------------------------------------------

  Dart_Handle mojo_internal = Dart_LookupLibrary(ToDart("dart:mojo.internal"));
  DART_CHECK_VALID(Dart_SetNativeResolver(mojo_internal,
                                          mojo::dart::MojoNativeLookup,
                                          mojo::dart::MojoNativeSymbol));
  SetHandleWatcherControlHandle(mojo_internal);

  // dart:mojo.builtin ---------------------------------------------------------

  Dart_Handle builtin_lib = Dart_LookupLibrary(ToDart("dart:mojo.builtin"));
  DART_CHECK_VALID(Dart_SetNativeResolver(builtin_lib, BuiltinNativeLookup,
                                          BuiltinNativeSymbol));

  // dart:io -------------------------------------------------------------------

  DART_CHECK_VALID(Dart_SetNativeResolver(Dart_LookupLibrary(ToDart("dart:io")),
                                          dart::bin::IONativeLookup,
                                          dart::bin::IONativeSymbol));

  // Core libraries ------------------------------------------------------------

  Dart_Handle async_lib = Dart_LookupLibrary(ToDart("dart:async"));
  Dart_Handle core_lib = Dart_LookupLibrary(ToDart("dart:core"));
  Dart_Handle internal_lib = Dart_LookupLibrary(ToDart("dart:_internal"));
  Dart_Handle isolate_lib = Dart_LookupLibrary(ToDart("dart:isolate"));

  // We need to ensure that all the scripts loaded so far are finalized
  // as we are about to invoke some Dart code below to setup closures.
  DART_CHECK_VALID(Dart_FinalizeLoading(false));

  // Import dart:_internal into dart:mojo.builtin for setting up hooks.
  DART_CHECK_VALID(
      Dart_LibraryImportLibrary(builtin_lib, internal_lib, Dart_Null()));

  // Setup the internal library's 'internalPrint' function.
  Dart_Handle print =
      Dart_Invoke(builtin_lib, ToDart("_getPrintClosure"), 0, nullptr);
  DART_CHECK_VALID(print);
  DART_CHECK_VALID(Dart_SetField(internal_lib, ToDart("_printClosure"), print));

  // Setup the 'scheduleImmediate' closure.
  Dart_Handle schedule_immediate_closure = Dart_Invoke(
      isolate_lib, ToDart("_getIsolateScheduleImmediateClosure"), 0, nullptr);
  DART_CHECK_VALID(schedule_immediate_closure);

  Dart_Handle schedule_args[1];
  schedule_args[0] = schedule_immediate_closure;
  DART_CHECK_VALID(Dart_Invoke(
      async_lib, ToDart("_setScheduleImmediateClosure"), 1, schedule_args));

  // Set the script location.
  DART_CHECK_VALID(
      Dart_SetField(builtin_lib, ToDart("_rawScript"), ToDart(script_uri)));

  // Set the base URI.
  DART_CHECK_VALID(
      Dart_SetField(builtin_lib, ToDart("_rawUriBase"), ToDart(base_uri)));

  // Setup the uriBase with the base uri of the mojo app.
  Dart_Handle uri_base =
      Dart_Invoke(builtin_lib, ToDart("_getUriBaseClosure"), 0, nullptr);
  DART_CHECK_VALID(uri_base);
  DART_CHECK_VALID(
      Dart_SetField(core_lib, ToDart("_uriBaseClosure"), uri_base));

  DART_CHECK_VALID(Dart_Invoke(builtin_lib, ToDart("_setupHooks"), 0, nullptr));
  DART_CHECK_VALID(Dart_Invoke(isolate_lib, ToDart("_setupHooks"), 0, nullptr));
}

}  // namespace dart_content_handler
