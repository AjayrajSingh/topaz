// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "apps/dart_content_handler/application_runner_impl.h"

#include <dlfcn.h>
#include <magenta/dlfcn.h>
#include <mx/process.h>
#include <thread>
#include <utility>

#include "apps/dart_content_handler/dart_application_controller.h"
#include "apps/dart_content_handler/embedder/snapshot.h"
#include "lib/mtl/tasks/message_loop.h"
#include "lib/mtl/vmo/vector.h"
#include "lib/zip/unzipper.h"

namespace dart_content_handler {
namespace {

bool ExtractSnapshots(std::vector<char> bundle,
                      const uint8_t*& vm_snapshot_data,
                      const uint8_t*& vm_snapshot_instructions,
                      const uint8_t*& isolate_snapshot_data,
                      const uint8_t*& isolate_snapshot_instructions,
                      std::vector<char>& script_snapshot) {
#if defined(AOT_RUNTIME)
  constexpr char kDylibKey[] = "libapp.so";
  zip::Unzipper unzipper(std::move(bundle));
  std::vector<char> dylib = unzipper.Extract(kDylibKey);

  mx::vmo dylib_vmo;
  if (!mtl::VmoFromVector(dylib, &dylib_vmo)) {
    FTL_LOG(ERROR) << "Failed to load dylib data";
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

  vm_snapshot_data =
      reinterpret_cast<const uint8_t*>(dlsym(lib, "_kDartVmSnapshotData"));
  if (vm_snapshot_data == NULL) {
    FTL_LOG(ERROR) << "dlsym(_kDartVmSnapshotData) failed: " << dlerror();
    return false;
  }
  vm_snapshot_instructions = reinterpret_cast<const uint8_t*>(
      dlsym(lib, "_kDartVmSnapshotInstructions"));
  if (vm_snapshot_instructions == NULL) {
    FTL_LOG(ERROR) << "dlsym(_kDartVmSnapshotInstructions) failed: "
                   << dlerror();
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
#else  // !AOT_RUNTIME
  vm_snapshot_data = dart_content_handler::vm_isolate_snapshot_buffer;
  vm_snapshot_instructions = NULL;
  isolate_snapshot_data = dart_content_handler::isolate_snapshot_buffer;
  isolate_snapshot_instructions = NULL;

  constexpr char kSnapshotKey[] = "snapshot_blob.bin";
  zip::Unzipper unzipper(std::move(bundle));
  script_snapshot = unzipper.Extract(kSnapshotKey);

  return true;
#endif
}

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
  // Extract a dart snapshot from the application package data.
  std::vector<char> bundle;
  if (!mtl::VectorFromVmo(application->data, &bundle)) {
    FTL_LOG(ERROR) << "Failed to read application data.";
    return;
  }
  std::string url = std::move(application->resolved_url);

  const uint8_t* vm_snapshot_data = NULL;
  const uint8_t* vm_snapshot_instructions = NULL;
  const uint8_t* isolate_snapshot_data = NULL;
  const uint8_t* isolate_snapshot_instructions = NULL;
  std::vector<char> script_snapshot;
  if (!ExtractSnapshots(bundle, vm_snapshot_data, vm_snapshot_instructions,
                        isolate_snapshot_data, isolate_snapshot_instructions,
                        script_snapshot)) {
    return;
  }

  mtl::MessageLoop loop;

  // Name this process after the url of the application being launched.
  std::string label = "dart:" + GetLabelFromURL(url);
  mx::process::self().set_property(MX_PROP_NAME, label.c_str(), label.size());

  DartApplicationController app(
      vm_snapshot_data, vm_snapshot_instructions, isolate_snapshot_data,
      isolate_snapshot_instructions, std::move(script_snapshot),
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
    : binding_(this, std::move(app_runner)) {}

ApplicationRunnerImpl::~ApplicationRunnerImpl() {}

void ApplicationRunnerImpl::StartApplication(
    app::ApplicationPackagePtr application,
    app::ApplicationStartupInfoPtr startup_info,
    ::fidl::InterfaceRequest<app::ApplicationController> controller) {
  std::thread thread(RunApplication, std::move(application),
                     std::move(startup_info), std::move(controller));
  thread.detach();
}

}  // namespace dart_content_handler
