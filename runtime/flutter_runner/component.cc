// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "component.h"

#include <dlfcn.h>
#include <sys/stat.h>
#include <zircon/dlfcn.h>
#include <zircon/status.h>

#include <regex>
#include <sstream>

#include "flutter/fml/synchronization/waitable_event.h"
#include "flutter/shell/common/switches.h"
#include "lib/fsl/vmo/file.h"
#include "lib/fsl/vmo/vector.h"
#include "lib/fxl/command_line.h"
#include "task_observers.h"
#include "topaz/runtime/dart/utils/tempfs.h"

namespace flutter {

constexpr char kDataKey[] = "data";

std::pair<std::unique_ptr<deprecated_loop::Thread>,
          std::unique_ptr<Application>>
Application::Create(
    TerminationCallback termination_callback, fuchsia::sys::Package package,
    fuchsia::sys::StartupInfo startup_info,
    fidl::InterfaceRequest<fuchsia::sys::ComponentController> controller) {
  auto thread = std::make_unique<deprecated_loop::Thread>();
  std::unique_ptr<Application> application;

  fml::AutoResetWaitableEvent latch;
  thread->TaskRunner()->PostTask([&]() mutable {
    application.reset(
        new Application(std::move(termination_callback), std::move(package),
                        std::move(startup_info), std::move(controller)));
    latch.Signal();
  });
  thread->Run();
  latch.Wait();
  return {std::move(thread), std::move(application)};
}

static std::string DebugLabelForURL(const std::string& url) {
  auto found = url.rfind("/");
  if (found == std::string::npos) {
    return url;
  } else {
    return {url, found + 1};
  }
}

static bool ShouldEnableInterpreter(int appdir_fd) {
  struct stat stat_buffer = {};
  return fstatat(appdir_fd, "pkg/data/enable_interpreter", &stat_buffer, 0) ==
         0;
}

Application::Application(
    TerminationCallback termination_callback, fuchsia::sys::Package package,
    fuchsia::sys::StartupInfo startup_info,
    fidl::InterfaceRequest<fuchsia::sys::ComponentController>
        application_controller_request)
    : termination_callback_(std::move(termination_callback)),
      debug_label_(DebugLabelForURL(startup_info.launch_info.url)),
      application_controller_(this) {
  application_controller_.set_error_handler(
      [this](zx_status_t status) { Kill(); });

  FML_DCHECK(fdio_ns_.is_valid());
  // LaunchInfo::url non-optional.
  auto& launch_info = startup_info.launch_info;

  // LaunchInfo::arguments optional.
  if (auto& arguments = launch_info.arguments) {
    settings_ = shell::SettingsFromCommandLine(
        fml::CommandLineFromIterators(arguments->begin(), arguments->end()));
  }

  // TODO: LaunchInfo::out.

  // TODO: LaunchInfo::err.

  // LaunchInfo::service_request optional.
  if (launch_info.directory_request) {
    service_provider_bridge_.ServeDirectory(
        std::move(launch_info.directory_request));
  }

  // Determine /pkg/data directory from StartupInfo.
  std::string data_path;
  for (size_t i = 0; i < startup_info.program_metadata->size(); ++i) {
    auto pg = startup_info.program_metadata->at(i);
    if (pg.key.get().compare(kDataKey) == 0) {
      data_path = "pkg/" + pg.value.get();
    }
  }
  if (data_path.empty()) {
    FML_DLOG(ERROR) << "Could not find a /pkg/data directory for "
                    << package.resolved_url;
    return;
  }

  // Setup /tmp to be mapped to the process-local memfs.
  fuchsia::dart::SetupComponentTemp(fdio_ns_.get());

  // LaunchInfo::flat_namespace optional.
  for (size_t i = 0; i < startup_info.flat_namespace.paths->size(); ++i) {
    const auto& path = startup_info.flat_namespace.paths->at(i);
    if (path == "/tmp" || path == "/svc") {
      continue;
    }

    zx::channel dir = std::move(startup_info.flat_namespace.directories->at(i));
    zx_handle_t dir_handle = dir.release();
    if (fdio_ns_bind(fdio_ns_.get(), path->data(), dir_handle) != ZX_OK) {
      FML_DLOG(ERROR) << "Could not bind path to namespace: " << path;
      zx_handle_close(dir_handle);
    }
  }

  application_directory_.reset(fdio_ns_opendir(fdio_ns_.get()));
  FML_DCHECK(application_directory_.is_valid());

  application_assets_directory_.reset(openat(
      application_directory_.get(), data_path.c_str(), O_RDONLY | O_DIRECTORY));

  // TODO: LaunchInfo::additional_services optional.

  // All launch arguments have been read. Perform service binding and
  // final settings configuration. The next call will be to create a view
  // for this application.

  service_provider_bridge_.AddService<fuchsia::ui::viewsv1::ViewProvider>(
      [this](fidl::InterfaceRequest<fuchsia::ui::viewsv1::ViewProvider>
                 view_provider_request) {
        v1_shells_bindings_.AddBinding(this, std::move(view_provider_request));
      });

  service_provider_bridge_.AddService<fuchsia::ui::app::ViewProvider>(
      [this](fidl::InterfaceRequest<fuchsia::ui::app::ViewProvider>
                 view_provider_request) {
        shells_bindings_.AddBinding(this, std::move(view_provider_request));
      });

  fuchsia::sys::ServiceProviderPtr outgoing_services;
  outgoing_services_request_ = outgoing_services.NewRequest();
  service_provider_bridge_.set_backend(std::move(outgoing_services));

  // Setup the application controller binding.
  if (application_controller_request) {
    application_controller_.Bind(std::move(application_controller_request));
  }

  startup_context_ =
      component::StartupContext::CreateFrom(std::move(startup_info));

  // Compare flutter_jit_runner in BUILD.gn.
  settings_.vm_snapshot_data_path = "pkg/data/vm_snapshot_data.bin";
  settings_.vm_snapshot_instr_path = "pkg/data/vm_snapshot_instructions.bin";
  settings_.isolate_snapshot_data_path =
      "pkg/data/isolate_core_snapshot_data.bin";
  settings_.isolate_snapshot_instr_path =
      "pkg/data/isolate_core_snapshot_instructions.bin";

#if defined(DART_PRODUCT)
  settings_.enable_observatory = false;
#else
  settings_.enable_observatory = true;
#endif

  settings_.icu_data_path = "";

  settings_.assets_dir = application_assets_directory_.get();

  // Compare flutter_jit_app in flutter_app.gni.
  settings_.application_kernel_list_asset = "app.dilplist";

  settings_.log_tag = debug_label_ + std::string{"(flutter)"};

#ifndef NDEBUG
  // Debug mode
  settings_.disable_dart_asserts = false;
#else   // NDEBUG
  // Release mode
  settings_.disable_dart_asserts = true;
#endif  // NDEBUG

  settings_.task_observer_add =
      std::bind(&CurrentMessageLoopAddAfterTaskObserver, std::placeholders::_1,
                std::placeholders::_2);

  settings_.task_observer_remove = std::bind(
      &CurrentMessageLoopRemoveAfterTaskObserver, std::placeholders::_1);

  // TODO(FL-117): Re-enable causal async stack traces when this issue is
  // addressed.
  settings_.dart_flags = {"--no_causal_async_stacks"};

  if (ShouldEnableInterpreter(application_directory_.get())) {
    FML_DLOG(INFO)
        << "Found pkg/data/enable_interpreter. Passing --enable_interpreter";
    settings_.dart_flags.push_back("--enable_interpreter");
  } else {
    FML_DLOG(INFO) << "Did NOT find pkg/data/enable_interpreter.";
    settings_.dart_flags.push_back("--no_use_field_guards");
  }

  AttemptVMLaunchWithCurrentSettings(settings_);
}

Application::~Application() = default;

const std::string& Application::GetDebugLabel() const { return debug_label_; }

class FileInNamespaceBuffer final : public blink::DartSnapshotBuffer {
 public:
  FileInNamespaceBuffer(int namespace_fd, const char* path, bool executable)
      : address_(nullptr), size_(0) {
    fsl::SizedVmo vmo;
    if (!fsl::VmoFromFilenameAt(namespace_fd, path, &vmo)) {
      return;
    }
    if (vmo.size() == 0) {
      return;
    }

    uint32_t flags = ZX_VM_PERM_READ;
    if (executable) {
      flags |= ZX_VM_PERM_EXECUTE;

      // VmoFromFilenameAt will return VMOs without ZX_RIGHT_EXECUTE,
      // so we need replace_as_executable to be able to map them as
      // ZX_VM_PERM_EXECUTE.
      // TODO(mdempsky): Update comment once SEC-42 is fixed.
      zx_status_t status =
          vmo.vmo().replace_as_executable(zx::handle(), &vmo.vmo());
      if (status != ZX_OK) {
        FML_LOG(FATAL) << "Failed to make VMO executable: "
                       << zx_status_get_string(status);
      }
    }
    uintptr_t addr;
    zx_status_t status =
        zx::vmar::root_self()->map(0, vmo.vmo(), 0, vmo.size(), flags, &addr);
    if (status != ZX_OK) {
      FML_LOG(FATAL) << "Failed to map " << path << ": "
                     << zx_status_get_string(status);
    }

    address_ = reinterpret_cast<void*>(addr);
    size_ = vmo.size();
  }

  ~FileInNamespaceBuffer() {
    if (address_ != nullptr) {
      zx::vmar::root_self()->unmap(reinterpret_cast<uintptr_t>(address_),
                                   size_);
      address_ = nullptr;
      size_ = 0;
    }
  }

  const uint8_t* GetSnapshotPointer() const override {
    return reinterpret_cast<const uint8_t*>(address_);
  }
  size_t GetSnapshotSize() const override { return size_; }

 private:
  void* address_;
  size_t size_;

  FML_DISALLOW_COPY_AND_ASSIGN(FileInNamespaceBuffer);
};

std::unique_ptr<blink::DartSnapshotBuffer> CreateWithContentsOfFile(
    int namespace_fd, const char* file_path, bool executable) {
  auto source = std::make_unique<FileInNamespaceBuffer>(namespace_fd, file_path,
                                                        executable);
  return source->GetSnapshotPointer() == nullptr ? nullptr : std::move(source);
}

void Application::AttemptVMLaunchWithCurrentSettings(
    const blink::Settings& settings) {
  if (!blink::DartVM::IsRunningPrecompiledCode()) {
    // We will be initializing the VM lazily in this case.
    return;
  }

  // Compare flutter_aot_app in flutter_app.gni.
  fml::RefPtr<blink::DartSnapshot> vm_snapshot =
      fml::MakeRefCounted<blink::DartSnapshot>(
          CreateWithContentsOfFile(
              application_assets_directory_.get() /* /pkg/data */,
              "vm_snapshot_data.bin", false),
          CreateWithContentsOfFile(
              application_assets_directory_.get() /* /pkg/data */,
              "vm_snapshot_instructions.bin", true));

  isolate_snapshot_ = fml::MakeRefCounted<blink::DartSnapshot>(
      CreateWithContentsOfFile(
          application_assets_directory_.get() /* /pkg/data */,
          "isolate_snapshot_data.bin", false),
      CreateWithContentsOfFile(
          application_assets_directory_.get() /* /pkg/data */,
          "isolate_snapshot_instructions.bin", true));

  shared_snapshot_ = fml::MakeRefCounted<blink::DartSnapshot>(
      CreateWithContentsOfFile(
          application_assets_directory_.get() /* /pkg/data */,
          "shared_snapshot_data.bin", false),
      CreateWithContentsOfFile(
          application_assets_directory_.get() /* /pkg/data */,
          "shared_snapshot_instructions.bin", true));

  blink::DartVM::ForProcess(settings_,               //
                            std::move(vm_snapshot),  //
                            isolate_snapshot_,       //
                            shared_snapshot_         //
  );
  if (blink::DartVM::ForProcessIfInitialized()) {
    FML_DLOG(INFO) << "VM successfully initialized for AOT mode.";
  } else {
    FML_LOG(ERROR) << "VM could not be initialized for AOT mode.";
  }
}

// |fuchsia::sys::ComponentController|
void Application::Kill() {
  application_controller_.events().OnTerminated(
      last_return_code_.second, fuchsia::sys::TerminationReason::EXITED);

  termination_callback_(this);
  // WARNING: Don't do anything past this point as this instance may have been
  // collected.
}

// |fuchsia::sys::ComponentController|
void Application::Detach() {
  application_controller_.set_error_handler(nullptr);
}

// |flutter::Engine::Delegate|
void Application::OnEngineTerminate(const Engine* shell_holder) {
  auto found = std::find_if(shell_holders_.begin(), shell_holders_.end(),
                            [shell_holder](const auto& holder) {
                              return holder.get() == shell_holder;
                            });

  if (found == shell_holders_.end()) {
    return;
  }

  // We may launch multiple shell in this application. However, we will
  // terminate when the last shell goes away. The error code return to the
  // application controller will be the last isolate that had an error.
  auto return_code = shell_holder->GetEngineReturnCode();
  if (return_code.first) {
    last_return_code_ = return_code;
  }

  shell_holders_.erase(found);

  if (shell_holders_.size() == 0) {
    Kill();
    // WARNING: Don't do anything past this point because the delegate may have
    // collected this instance via the termination callback.
  }
}

// |fuchsia::ui::viewsv1::ViewProvider|
void Application::CreateView(
    fidl::InterfaceRequest<fuchsia::ui::viewsv1token::ViewOwner> view_owner,
    fidl::InterfaceRequest<fuchsia::sys::ServiceProvider> services) {
  CreateView(zx::eventpair(view_owner.TakeChannel().release()),
             std::move(services), nullptr);
}

// |fuchsia::ui::app::ViewProvider|
void Application::CreateView(
    zx::eventpair view_token,
    fidl::InterfaceRequest<fuchsia::sys::ServiceProvider> incoming_services,
    fidl::InterfaceHandle<fuchsia::sys::ServiceProvider> outgoing_services) {
  if (!startup_context_) {
    FML_DLOG(ERROR) << "Application context was invalid when attempting to "
                       "create a shell for a view provider request.";
    return;
  }

  shell_holders_.emplace(std::make_unique<Engine>(
      *this,                                 // delegate
      debug_label_,                          // thread label
      *startup_context_,                     // application context
      settings_,                             // settings
      std::move(isolate_snapshot_),          // isolate snapshot
      std::move(shared_snapshot_),           // shared snapshot
      std::move(view_token),                 // view token
      std::move(fdio_ns_),                   // FDIO namespace
      std::move(outgoing_services_request_)  // outgoing request
      ));
}

}  // namespace flutter
