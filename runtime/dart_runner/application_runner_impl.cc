// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "apps/dart_content_handler/application_runner_impl.h"

#include <dlfcn.h>
#include <magenta/dlfcn.h>
#include <magenta/status.h>
#include <mx/process.h>
#include <thread>
#include <utility>

#include "apps/dart_content_handler/dart_application_controller.h"
#include "apps/dart_content_handler/embedder/snapshot.h"
#include "dart/runtime/bin/embedded_dart_io.h"
#include "lib/ftl/arraysize.h"
#include "lib/mtl/tasks/message_loop.h"
#include "lib/mtl/vmo/vector.h"
#include "lib/tonic/dart_microtask_queue.h"
#include "lib/tonic/dart_state.h"

namespace dart_content_handler {
namespace {

const char* kDartVMArgs[] = {
// clang-format off
#if defined(AOT_RUNTIME)
    "--precompilation",
#else
    "--enable_mirrors=false",
#endif
    // clang-format on
};

void IsolateShutdownCallback(void* callback_data) {
  mtl::MessageLoop::GetCurrent()->SetAfterTaskCallback(nullptr);
  tonic::DartMicrotaskQueue::GetForCurrentThread()->Destroy();
  mtl::MessageLoop::GetCurrent()->QuitNow();
}

void IsolateCleanupCallback(void* callback_data) {
  tonic::DartState* dart_state = static_cast<tonic::DartState*>(callback_data);
  delete dart_state;
}

#if defined(AOT_RUNTIME)

bool ExtractSnapshots(const mx::vmo& bundle,
                      const uint8_t*& isolate_snapshot_data,
                      const uint8_t*& isolate_snapshot_instructions,
                      const uint8_t*& script_snapshot,
                      intptr_t* script_snapshot_len) {
  // The AOT bundle consists of:
  //   1. The Fuchsia shebang: #!fuchsia dart_aot_runner\n
  //   2. Padding up to the page size
  //   3. The dylib containing the AOT compiled Dart snapshot.
  // To make a vmo that we can pass to dlopen_vmo(), we clone the bundle vmo
  // at an offset of one page.
  mx_status_t status;
  uint64_t bundle_size;
  status = bundle.get_size(&bundle_size);
  if (status != MX_OK) {
    FTL_LOG(ERROR) << "bundle.get_size() failed: "
                   << mx_status_get_string(status);
    return false;
  }

  mx::vmo dylib_vmo;
  const int pagesize = getpagesize();
  status = bundle.clone(MX_VMO_CLONE_COPY_ON_WRITE | MX_RIGHT_EXECUTE, pagesize,
                        bundle_size - pagesize, &dylib_vmo);
  if (status != MX_OK) {
    FTL_LOG(ERROR) << "bundle.clone() failed: " << mx_status_get_string(status);
    return false;
  }

  dlerror();
  void* lib = dlopen_vmo(dylib_vmo.get(), RTLD_LAZY);
  // TODO(rmacnak): It is currently not safe to unload this library when the
  // isolate shuts down because it may be backing part of the vm isolate's heap.
  if (lib == NULL) {
    FTL_LOG(ERROR) << "dlopen failed: " << dlerror();
    return false;
  }

  isolate_snapshot_data =
      reinterpret_cast<const uint8_t*>(dlsym(lib, "_kDartIsolateSnapshotData"));
  if (isolate_snapshot_data == NULL) {
    FTL_LOG(ERROR) << "dlsym(_kDartIsolateSnapshotData) failed: " << dlerror();
    return false;
  }
  isolate_snapshot_instructions = reinterpret_cast<const uint8_t*>(
      dlsym(lib, "_kDartIsolateSnapshotInstructions"));
  if (isolate_snapshot_instructions == NULL) {
    FTL_LOG(ERROR) << "dlsym(_kDartIsolateSnapshotInstructions) failed: "
                   << dlerror();
    return false;
  }

  return true;
}

#else  // !defined(AOT_RUNTIME)

bool ExtractSnapshots(const mx::vmo& bundle,
                      const uint8_t*& isolate_snapshot_data,
                      const uint8_t*& isolate_snapshot_instructions,
                      const uint8_t*& script_snapshot,
                      intptr_t* script_snapshot_len) {
  isolate_snapshot_data = dart_content_handler::isolate_snapshot_buffer;
  isolate_snapshot_instructions = NULL;

  mx_status_t status;
  uint64_t bundle_size;
  status = bundle.get_size(&bundle_size);
  if (status != MX_OK) {
    FTL_LOG(ERROR) << "bundle.get_size() failed: "
                   << mx_status_get_string(status);
    return false;
  }

  const int pagesize = getpagesize();
  uintptr_t addr;
  status = mx::vmar::root_self().map(
      0, bundle, pagesize, bundle_size - pagesize, MX_VM_FLAG_PERM_READ, &addr);
  if (status != MX_OK) {
    FTL_LOG(ERROR) << "bundle map failed: " << mx_status_get_string(status);
    return false;
  }

  script_snapshot = reinterpret_cast<uint8_t*>(addr);
  *script_snapshot_len = bundle_size - pagesize;
  return true;
}

#endif  // !defined(AOT_RUNTIME)

std::string GetLabelFromURL(const std::string& url) {
  size_t last_slash = url.rfind('/');
  if (last_slash == std::string::npos || last_slash + 1 == url.length())
    return url;
  return url.substr(last_slash + 1);
}

void RunApplication(
    app::ApplicationPackagePtr application,
    app::ApplicationStartupInfoPtr startup_info,
    ::fidl::InterfaceRequest<app::ApplicationController> controller) {
  std::string url = std::move(application->resolved_url);

  // Name the process and bundle after the url of the application being
  // launched. Name the bundle before extract snapshot for the name to carry to
  // the mappings.
  std::string label = "dart:" + GetLabelFromURL(url);
  mx::process::self().set_property(MX_PROP_NAME, label.c_str(), label.size());
  application->data.set_property(MX_PROP_NAME, label.c_str(), label.size());

  const uint8_t* isolate_snapshot_data = NULL;
  const uint8_t* isolate_snapshot_instructions = NULL;
  const uint8_t* script_snapshot = NULL;
  intptr_t script_snapshot_len = 0;
  if (!ExtractSnapshots(application->data, isolate_snapshot_data,
                        isolate_snapshot_instructions, script_snapshot,
                        &script_snapshot_len)) {
    return;
  }

  mtl::MessageLoop loop;

  DartApplicationController app(
      isolate_snapshot_data, isolate_snapshot_instructions,
#if !defined(AOT_RUNTIME)
      script_snapshot, script_snapshot_len,
#endif  // !defined(AOT_RUNTIME)
      std::move(startup_info), std::move(url), std::move(controller));

  if (app.CreateIsolate()) {
    loop.task_runner()->PostTask([&loop, &app] {
      if (!app.Main())
        loop.PostQuitTask();
    });

    loop.Run();
  }
}

}  // namespace

ApplicationRunnerImpl::ApplicationRunnerImpl(
    fidl::InterfaceRequest<app::ApplicationRunner> app_runner)
    : binding_(this, std::move(app_runner)) {
  dart::bin::BootstrapDartIo();

  // TODO(abarth): Make checked mode configurable.
  FTL_CHECK(Dart_SetVMFlags(arraysize(kDartVMArgs), kDartVMArgs));

  Dart_InitializeParams params = {};
  params.version = DART_INITIALIZE_PARAMS_CURRENT_VERSION;
#if defined(AOT_RUNTIME)
  params.vm_snapshot_data = ::_kDartVmSnapshotData;
  params.vm_snapshot_instructions = ::_kDartVmSnapshotInstructions;
#else
  params.vm_snapshot_data = dart_content_handler::vm_isolate_snapshot_buffer;
  params.vm_snapshot_instructions = NULL;
#endif
  params.shutdown = IsolateShutdownCallback;
  params.cleanup = IsolateCleanupCallback;
  char* error = Dart_Initialize(&params);
  if (error)
    FTL_LOG(FATAL) << "Dart_Initialize failed: " << error;
}

ApplicationRunnerImpl::~ApplicationRunnerImpl() {
  char* error = Dart_Cleanup();
  if (error)
    FTL_LOG(FATAL) << "Dart_Cleanup failed: " << error;
}

void ApplicationRunnerImpl::StartApplication(
    app::ApplicationPackagePtr application,
    app::ApplicationStartupInfoPtr startup_info,
    ::fidl::InterfaceRequest<app::ApplicationController> controller) {
  std::thread thread(RunApplication, std::move(application),
                     std::move(startup_info), std::move(controller));
  thread.detach();
}

}  // namespace dart_content_handler
