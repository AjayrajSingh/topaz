// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "topaz/runtime/dart_runner/service_isolate.h"

#include <dlfcn.h>
#include <zircon/dlfcn.h>

#include "lib/fsl/vmo/file.h"
#include "lib/tonic/converter/dart_converter.h"
#include "lib/tonic/dart_library_natives.h"
#include "lib/tonic/dart_microtask_queue.h"
#include "lib/tonic/dart_state.h"
#include "lib/tonic/typed_data/uint8_list.h"
#include "third_party/dart/runtime/bin/embedded_dart_io.h"
#include "topaz/runtime/dart_runner/builtin_libraries.h"
#include "topaz/runtime/dart_runner/dart_application_controller.h"

namespace dart_runner {
namespace {

MappedResource mapped_isolate_snapshot_data;
MappedResource mapped_isolate_snapshot_instructions;
tonic::DartLibraryNatives* service_natives = nullptr;

Dart_NativeFunction GetNativeFunction(Dart_Handle name,
                                      int argument_count,
                                      bool* auto_setup_scope) {
  FXL_CHECK(service_natives);
  return service_natives->GetNativeFunction(name, argument_count,
                                            auto_setup_scope);
}

const uint8_t* GetSymbol(Dart_NativeFunction native_function) {
  FXL_CHECK(service_natives);
  return service_natives->GetSymbol(native_function);
}

#define SHUTDOWN_ON_ERROR(handle)           \
  if (Dart_IsError(handle)) {               \
    *error = strdup(Dart_GetError(handle)); \
    FXL_LOG(ERROR) << *error;               \
    Dart_ExitScope();                       \
    Dart_ShutdownIsolate();                 \
    return nullptr;                         \
  }

void NotifyServerState(Dart_NativeArguments args) {
  // NOP.
}

void Shutdown(Dart_NativeArguments args) {
  // NOP.
}

void EmbedderInformationCallback(Dart_EmbedderInformation* info) {
  info->version = DART_EMBEDDER_INFORMATION_CURRENT_VERSION;
  info->name = "dart_runner";
  info->current_rss = -1;
  info->max_rss = -1;

  zx_info_task_stats_t task_stats;
  zx_handle_t process = zx_process_self();
  zx_status_t status = zx_object_get_info(
      process, ZX_INFO_TASK_STATS, &task_stats, sizeof(task_stats), NULL, NULL);
  if (status == ZX_OK) {
    info->current_rss =
        task_stats.mem_private_bytes + task_stats.mem_shared_bytes;
  }
}

}  // namespace

Dart_Isolate CreateServiceIsolate(const char* uri,
                                  Dart_IsolateFlags* flags,
                                  char** error) {
  Dart_SetEmbedderInformationCallback(EmbedderInformationCallback);

  void* isolate_snapshot_data = nullptr;
  void* isolate_snapshot_instructions = nullptr;
#if defined(AOT_RUNTIME)
  fsl::SizedVmo dylib;
  if (!fsl::VmoFromFilename("pkg/data/libvmservice.so", &dylib)) {
    FXL_LOG(ERROR) << "Failed to read "
                   << "pkg/data/libvmservice.so";
    return nullptr;
  }

  dlerror();
  void* shared_library = dlopen_vmo(dylib.vmo().get(), RTLD_LAZY);
  if (shared_library == nullptr) {
    FXL_LOG(ERROR) << "dlopen failed: " << dlerror();
    return nullptr;
  }

  isolate_snapshot_data = dlsym(shared_library, "_kDartIsolateSnapshotData");
  if (isolate_snapshot_data == nullptr) {
    FXL_LOG(ERROR) << "dlsym(_kDartIsolateSnapshotData) failed: " << dlerror();
    return nullptr;
  }

  isolate_snapshot_instructions =
      dlsym(shared_library, "_kDartIsolateSnapshotInstructions");
  if (isolate_snapshot_instructions == nullptr) {
    FXL_LOG(ERROR) << "dlsym(_kDartIsolateSnapshotInstructions) failed: "
                   << dlerror();
    return nullptr;
  }
#else
  if (!MappedResource::LoadFromNamespace(
          nullptr, "pkg/data/isolate_core_snapshot_data.bin",
          mapped_isolate_snapshot_data)) {
    *error = strdup("Failed to load core snapshot for service isolate");
    return nullptr;
  }
  isolate_snapshot_data = mapped_isolate_snapshot_data.address();
  if (!MappedResource::LoadFromNamespace(
          nullptr, "pkg/data/isolate_core_snapshot_instructions.bin",
          mapped_isolate_snapshot_instructions, true /* executable */)) {
    *error = strdup("Failed to load core snapshot for service isolate");
    return nullptr;
  }
  isolate_snapshot_instructions =
      mapped_isolate_snapshot_instructions.address();
#endif

  auto state = new tonic::DartState();
  Dart_Isolate isolate = Dart_CreateIsolate(
      uri, "main", reinterpret_cast<const uint8_t*>(isolate_snapshot_data),
      reinterpret_cast<const uint8_t*>(isolate_snapshot_instructions), nullptr,
      state, error);
  if (!isolate) {
    FXL_LOG(ERROR) << "Dart_CreateIsolate failed: " << *error;
    return nullptr;
  }

  state->SetIsolate(isolate);

  // Setup native entries.
  service_natives = new tonic::DartLibraryNatives();
  service_natives->Register({
      {"VMServiceIO_NotifyServerState", NotifyServerState, 1, true},
      {"VMServiceIO_Shutdown", Shutdown, 0, true},
  });

  Dart_EnterScope();

  Dart_Handle library =
      Dart_LookupLibrary(Dart_NewStringFromCString("dart:vmservice_io"));
  SHUTDOWN_ON_ERROR(library);
  Dart_Handle result = Dart_SetRootLibrary(library);
  SHUTDOWN_ON_ERROR(result);
  result = Dart_SetNativeResolver(library, GetNativeFunction, GetSymbol);
  SHUTDOWN_ON_ERROR(result);

  // _ip = '127.0.0.1'
  result = Dart_SetField(library, Dart_NewStringFromCString("_ip"),
                         Dart_NewStringFromCString("127.0.0.1"));
  SHUTDOWN_ON_ERROR(result);

  // _port = 0
  result = Dart_SetField(library, Dart_NewStringFromCString("_port"),
                         Dart_NewInteger(0));
  SHUTDOWN_ON_ERROR(result);

  // _autoStart = true
  result = Dart_SetField(library, Dart_NewStringFromCString("_autoStart"),
                         Dart_NewBoolean(true));
  SHUTDOWN_ON_ERROR(result);

  InitBuiltinLibrariesForIsolate(std::string(uri), nullptr, fileno(stdout),
                                 fileno(stderr), nullptr, nullptr, true);

  // Make runnable.
  Dart_ExitScope();
  Dart_ExitIsolate();
  bool retval = Dart_IsolateMakeRunnable(isolate);
  if (!retval) {
    Dart_EnterIsolate(isolate);
    Dart_ShutdownIsolate();
    *error = strdup("Invalid isolate state - Unable to make it runnable.");
    return nullptr;
  }
  return isolate;
}

Dart_Handle GetVMServiceAssetsArchiveCallback() {
  MappedResource observatory_tar;
  if (!MappedResource::LoadFromNamespace(nullptr, "pkg/data/observatory.tar",
                                         observatory_tar)) {
    FXL_LOG(ERROR) << "Failed to load Observatory assets";
    return nullptr;
  }
  // TODO(rmacnak): Should we avoid copying the tar? Or does the service library
  // not hold onto it anyway?
  return tonic::DartConverter<tonic::Uint8List>::ToDart(
      reinterpret_cast<const uint8_t*>(observatory_tar.address()),
      observatory_tar.size());
}

}  // namespace dart_runner
