// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "topaz/runtime/dart_runner/dart_runner.h"

#include <sys/stat.h>
#include <thread>
#include <utility>
#include <zircon/syscalls.h>

#include "lib/fxl/arraysize.h"
#include "lib/tonic/dart_microtask_queue.h"
#include "lib/tonic/dart_state.h"
#include "third_party/dart/runtime/bin/embedded_dart_io.h"
#include "topaz/lib/deprecated_loop/message_loop.h"
#include "topaz/runtime/dart_runner/dart_component_controller.h"
#include "topaz/runtime/dart_runner/service_isolate.h"

#if defined(AOT_RUNTIME)
extern "C" uint8_t _kDartVmSnapshotData[];
extern "C" uint8_t _kDartVmSnapshotInstructions[];
#endif

namespace dart_runner {
namespace {

const char* kDartVMArgs[] = {
    // clang-format off
    // TODO(https://github.com/dart-lang/sdk/issues/32608): Default flags.
    "--reify_generic_functions",
    "--strong",
    "--sync_async",
#if defined(AOT_RUNTIME)
    "--precompilation",
#else
    "--enable_mirrors=false",
    "--await_is_keyword",
#endif
#if !defined(NDEBUG) && !defined(DART_PRODUCT)
    "--enable_asserts",
    "--systrace_timeline",
    "--timeline_streams=VM,Isolate,Compiler,Dart,GC,Embedder,API",
#endif
    // clang-format on
};

Dart_Isolate IsolateCreateCallback(const char* uri, const char* main,
                                   const char* package_root,
                                   const char* package_config,
                                   Dart_IsolateFlags* flags,
                                   void* callback_data, char** error) {
  if (std::string(uri) == DART_VM_SERVICE_ISOLATE_NAME) {
#if defined(DART_PRODUCT)
    *error = strdup("The service isolate is not implemented in product mode");
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
  // deprecated_loop::MessageLoop.
  deprecated_loop::MessageLoop* loop = deprecated_loop::MessageLoop::GetCurrent();
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
    DartRunner* runner, ControllerToken* token, fuchsia::sys::Package package,
    fuchsia::sys::StartupInfo startup_info,
    ::fidl::InterfaceRequest<fuchsia::sys::ComponentController> controller) {
  int64_t start = Dart_TimelineGetMicros();
  deprecated_loop::MessageLoop loop;
  DartComponentController app(token->label(), std::move(package),
                              std::move(startup_info), std::move(controller));
  bool success = app.Setup();
  int64_t end = Dart_TimelineGetMicros();
  Dart_TimelineEvent("DartComponentController::Setup", start, end,
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

  runner->PostRemoveController(token);
}

// Find the last path component that is longer than 1 character.
// file:///system/pkgs/hello_dart_jit -> hello_dart_jit
// file:///pkgfs/packages/hello_dart_jit/0 -> hello_dart_jit
std::string GetLabelFromURL(const std::string& url) {
  size_t last_slash = url.length();
  for (size_t i = url.length() - 1; i > 0; i--) {
    if (url[i] == '/') {
      size_t component_length = last_slash - i - 1;
      if (component_length > 1) {
        return url.substr(i + 1, component_length);
      } else {
        last_slash = i;
      }
    }
  }
  return url;
}

bool EntropySource(uint8_t* buffer, intptr_t count) {
  zx_cprng_draw(buffer, count);
  return true;
}

}  // namespace

DartRunner::DartRunner()
    : context_(fuchsia::sys::StartupContext::CreateFromStartupInfo()),
      loop_(deprecated_loop::MessageLoop::GetCurrent()) {
  context_->outgoing().AddPublicService<fuchsia::sys::Runner>(
      [this](fidl::InterfaceRequest<fuchsia::sys::Runner> request) {
        bindings_.AddBinding(this, std::move(request));
      });

  dart::bin::BootstrapDartIo();

  char* error = Dart_SetVMFlags(arraysize(kDartVMArgs), kDartVMArgs);
  if (error) {
    FXL_LOG(FATAL) << "Dart_SetVMFlags failed: " << error;
  }

  Dart_InitializeParams params = {};
  params.version = DART_INITIALIZE_PARAMS_CURRENT_VERSION;
#if defined(AOT_RUNTIME)
  params.vm_snapshot_data = ::_kDartVmSnapshotData;
  params.vm_snapshot_instructions = ::_kDartVmSnapshotInstructions;
#else
  if (!MappedResource::LoadFromNamespace(
          nullptr, "pkg/data/vm_snapshot_data.bin", vm_snapshot_data_)) {
    FXL_LOG(FATAL) << "Failed to load vm snapshot data";
  }
  if (!MappedResource::LoadFromNamespace(
          nullptr, "pkg/data/vm_snapshot_instructions.bin",
          vm_snapshot_instructions_, true /* executable */)) {
    FXL_LOG(FATAL) << "Failed to load vm snapshot instructions";
  }
  params.vm_snapshot_data = vm_snapshot_data_.address();
  params.vm_snapshot_instructions = vm_snapshot_instructions_.address();
#endif
  params.create = IsolateCreateCallback;
  params.shutdown = IsolateShutdownCallback;
  params.cleanup = IsolateCleanupCallback;
  params.entropy_source = EntropySource;
#if !defined(DART_PRODUCT)
  params.get_service_assets = GetVMServiceAssetsArchiveCallback;
#endif
  error = Dart_Initialize(&params);
  if (error)
    FXL_LOG(FATAL) << "Dart_Initialize failed: " << error;
}

DartRunner::~DartRunner() {
  char* error = Dart_Cleanup();
  if (error)
    FXL_LOG(FATAL) << "Dart_Cleanup failed: " << error;
}

void DartRunner::StartComponent(
    fuchsia::sys::Package package, fuchsia::sys::StartupInfo startup_info,
    ::fidl::InterfaceRequest<fuchsia::sys::ComponentController> controller) {
  std::string label = GetLabelFromURL(package.resolved_url);
  std::thread thread(RunApplication, this, AddController(label),
                     std::move(package), std::move(startup_info),
                     std::move(controller));
  thread.detach();
}

ControllerToken* DartRunner::AddController(std::string label) {
  ControllerToken* token = new ControllerToken(label);
  controllers_.push_back(token);
  UpdateProcessLabel();
  return token;
}

void DartRunner::RemoveController(ControllerToken* token) {
  for (auto it = controllers_.begin(); it != controllers_.end(); ++it) {
    if (*it == token) {
      controllers_.erase(it);
      break;
    }
  }
  delete token;
  UpdateProcessLabel();
}

void DartRunner::PostRemoveController(ControllerToken* token) {
  loop_->task_runner()->PostTask([this, token] { RemoveController(token); });
}

void DartRunner::UpdateProcessLabel() {
  std::string label;
  if (controllers_.empty()) {
    label = "dart_runner";
  } else {
    std::string base_label = "dart:" + controllers_[0]->label();
    if (controllers_.size() < 2) {
      label = base_label;
    } else {
      std::string suffix =
          " (+" + std::to_string(controllers_.size() - 1) + ")";
      if (base_label.size() + suffix.size() <= ZX_MAX_NAME_LEN - 1) {
        label = base_label + suffix;
      } else {
        label = base_label.substr(0, ZX_MAX_NAME_LEN - 1 - suffix.size() - 3) +
                "..." + suffix;
      }
    }
  }
  zx::process::self().set_property(ZX_PROP_NAME, label.c_str(), label.size());
}

}  // namespace dart_runner
