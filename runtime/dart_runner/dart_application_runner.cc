// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "topaz/runtime/dart_runner/dart_application_runner.h"

#include <sys/stat.h>
#include <thread>
#include <utility>

#include "lib/fsl/tasks/message_loop.h"
#include "lib/fxl/arraysize.h"
#include "lib/tonic/dart_microtask_queue.h"
#include "lib/tonic/dart_state.h"
#include "third_party/dart/runtime/bin/embedded_dart_io.h"
#include "topaz/runtime/dart_runner/dart_application_controller.h"
#include "topaz/runtime/dart_runner/service_isolate.h"

#if defined(AOT_RUNTIME)
extern "C" uint8_t _kDartVmSnapshotData[];
extern "C" uint8_t _kDartVmSnapshotInstructions[];
#endif

namespace dart_content_handler {
namespace {

const char* kDartVMArgs[] = {
// clang-format off
#if defined(AOT_RUNTIME)
    "--precompilation",
#else
    "--enable_mirrors=false",
    "--await_is_keyword",
#endif
#if !defined(NDEBUG)
    "--enable_asserts",
    "--systrace_timeline",
    "--timeline_streams=VM,Isolate,Compiler,Dart,GC,Embedder",
#endif
    // clang-format on
};

const char* kDart2VMArgs[] = {
    // clang-format off
  "--strong",
  "--reify_generic_functions",
  "--limit_ints_to_64_bits",
    // clang-format on
};

void PushBackAll(std::vector<const char*>* args,
                 const char** argv,
                 size_t argc) {
  for (size_t i = 0; i < argc; ++i) {
    args->push_back(argv[i]);
  }
}

Dart_Isolate IsolateCreateCallback(const char* uri,
                                   const char* main,
                                   const char* package_root,
                                   const char* package_config,
                                   Dart_IsolateFlags* flags,
                                   void* callback_data,
                                   char** error) {
  if (std::string(uri) == DART_VM_SERVICE_ISOLATE_NAME) {
#if defined(NDEBUG)
    *error = strdup("The service isolate is not implemented in release mode");
    return NULL;
#else
    return CreateServiceIsolate(uri, flags, error);
#endif
  }

  if (std::string(uri) == DART_KERNEL_ISOLATE_NAME) {
    *error = strdup("The kernel isolate is not implemented in dart_runner");
    return NULL;
  }

  *error = strdup("Isolate spawning is not implemented in dart_runner");
  return NULL;
}

void IsolateShutdownCallback(void* callback_data) {
  // The service isolate (and maybe later the kernel isolate) doesn't have an
  // fsl::MessageLoop.
  fsl::MessageLoop* loop = fsl::MessageLoop::GetCurrent();
  if (loop) {
    loop->SetAfterTaskCallback(nullptr);
    tonic::DartMicrotaskQueue::GetForCurrentThread()->Destroy();
    loop->QuitNow();
  }
}

void IsolateCleanupCallback(void* callback_data) {
  tonic::DartState* dart_state = static_cast<tonic::DartState*>(callback_data);
  delete dart_state;
}

void RunApplication(
    app::ApplicationPackagePtr application,
    app::ApplicationStartupInfoPtr startup_info,
    ::f1dl::InterfaceRequest<app::ApplicationController> controller) {
  int64_t start = Dart_TimelineGetMicros();
  fsl::MessageLoop loop;
  DartApplicationController app(std::move(application), std::move(startup_info),
                                std::move(controller));
  bool success = app.Setup();
  int64_t end = Dart_TimelineGetMicros();
  Dart_TimelineEvent("DartApplicationController::Setup", start, end,
                     Dart_Timeline_Event_Duration, 0, NULL, NULL);
  if (success) {
    loop.task_runner()->PostTask([&loop, &app] {
      if (!app.Main())
        loop.PostQuitTask();
    });

    loop.Run();
    app.SendReturnCode();
  }

  if (Dart_CurrentIsolate()) {
    Dart_ShutdownIsolate();
  }
}

}  // namespace

DartApplicationRunner::DartApplicationRunner(
    f1dl::InterfaceRequest<app::ApplicationRunner> app_runner)
    : binding_(this, std::move(app_runner)) {
  dart::bin::BootstrapDartIo();

  struct stat buf;
  bool dart2 = stat("pkg/data/dart2", &buf) == 0;
  std::vector<const char*> args;
  PushBackAll(&args, kDartVMArgs, arraysize(kDartVMArgs));
  if (dart2) {
    PushBackAll(&args, kDart2VMArgs, arraysize(kDart2VMArgs));
  }
  FXL_CHECK(Dart_SetVMFlags(args.size(), args.data()));

  Dart_InitializeParams params = {};
  params.version = DART_INITIALIZE_PARAMS_CURRENT_VERSION;
#if defined(AOT_RUNTIME)
  params.vm_snapshot_data = ::_kDartVmSnapshotData;
  params.vm_snapshot_instructions = ::_kDartVmSnapshotInstructions;
#else
  if (!MappedResource::LoadFromNamespace(
          nullptr, "pkg/data/snapshot_vm_isolate.bin", vm_snapshot_data_)) {
    FXL_LOG(FATAL) << "Failed to load vm snapshot";
  }
  params.vm_snapshot_data =
      reinterpret_cast<const uint8_t*>(vm_snapshot_data_.address());
  params.vm_snapshot_instructions = NULL;
#endif
  params.create = IsolateCreateCallback;
  params.shutdown = IsolateShutdownCallback;
  params.cleanup = IsolateCleanupCallback;
#if !defined(NDEBUG)
  params.get_service_assets = GetVMServiceAssetsArchiveCallback;
#endif
  char* error = Dart_Initialize(&params);
  if (error)
    FXL_LOG(FATAL) << "Dart_Initialize failed: " << error;
}

DartApplicationRunner::~DartApplicationRunner() {
  char* error = Dart_Cleanup();
  if (error)
    FXL_LOG(FATAL) << "Dart_Cleanup failed: " << error;
}

void DartApplicationRunner::StartApplication(
    app::ApplicationPackagePtr application,
    app::ApplicationStartupInfoPtr startup_info,
    ::f1dl::InterfaceRequest<app::ApplicationController> controller) {
  std::thread thread(RunApplication, std::move(application),
                     std::move(startup_info), std::move(controller));
  thread.detach();
}

}  // namespace dart_content_handler
