// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef TOPAZ_RUNTIME_FLUTTER_RUNNER_COMPONENT_H_
#define TOPAZ_RUNTIME_FLUTTER_RUNNER_COMPONENT_H_

#include <array>
#include <memory>
#include <set>

#include <fuchsia/io/cpp/fidl.h>
#include <fuchsia/sys/cpp/fidl.h>
#include <fuchsia/ui/app/cpp/fidl.h>
#include <lib/async-loop/cpp/loop.h>
#include <lib/async/default.h>
#include <lib/fidl/cpp/binding_set.h>
#include <lib/fidl/cpp/interface_request.h>
#include <lib/fit/function.h>
#include <lib/sys/cpp/service_directory.h>
#include <lib/vfs/cpp/pseudo_dir.h>
#include <lib/zx/eventpair.h>

#include "engine.h"
#include "flutter/common/settings.h"
#include "flutter/fml/macros.h"

#include "thread.h"
#include "unique_fdio_ns.h"

namespace flutter_runner {

// Represents an instance of a Flutter application that contains one of more
// Flutter engine instances.
class Application final : public Engine::Delegate,
                          public fuchsia::sys::ComponentController,
                          public fuchsia::ui::app::ViewProvider {
 public:
  using TerminationCallback = fit::function<void(const Application*)>;

  // Creates a dedicated thread to run the application and constructions the
  // application on it. The application can be accessed only on this thread.
  // This is a synchronous operation.
  static std::pair<std::unique_ptr<Thread>, std::unique_ptr<Application>>
  Create(TerminationCallback termination_callback,
         fuchsia::sys::Package package, fuchsia::sys::StartupInfo startup_info,
         std::shared_ptr<sys::ServiceDirectory> runner_incoming_services,
         fidl::InterfaceRequest<fuchsia::sys::ComponentController> controller);

  // Must be called on the same thread returned from the create call. The thread
  // may be collected after.
  ~Application();

  const std::string& GetDebugLabel() const;

#if !defined(DART_PRODUCT)
  void WriteProfileToTrace() const;
#endif  // !defined(DART_PRODUCT)

 private:
  flutter::Settings settings_;
  TerminationCallback termination_callback_;
  const std::string debug_label_;
  UniqueFDIONS fdio_ns_ = UniqueFDIONSCreate();
  fml::UniqueFD application_directory_;
  fml::UniqueFD application_assets_directory_;

  fidl::Binding<fuchsia::sys::ComponentController> application_controller_;
  fuchsia::io::DirectoryPtr directory_ptr_;
  fuchsia::io::NodePtr cloned_directory_ptr_;
  fidl::InterfaceRequest<fuchsia::io::Directory> directory_request_;
  std::unique_ptr<vfs::PseudoDir> outgoing_dir_;
  std::shared_ptr<sys::ServiceDirectory> svc_;
  std::shared_ptr<sys::ServiceDirectory> runner_incoming_services_;
  fidl::BindingSet<fuchsia::ui::app::ViewProvider> shells_bindings_;

  fml::RefPtr<flutter::DartSnapshot> isolate_snapshot_;
  fml::RefPtr<flutter::DartSnapshot> shared_snapshot_;
  std::set<std::unique_ptr<Engine>> shell_holders_;
  std::pair<bool, uint32_t> last_return_code_;

  Application(
      TerminationCallback termination_callback, fuchsia::sys::Package package,
      fuchsia::sys::StartupInfo startup_info,
      std::shared_ptr<sys::ServiceDirectory> runner_incoming_services,
      fidl::InterfaceRequest<fuchsia::sys::ComponentController> controller);

  // |fuchsia::sys::ComponentController|
  void Kill() override;

  // |fuchsia::sys::ComponentController|
  void Detach() override;

  // |fuchsia::ui::app::ViewProvider|
  void CreateView(
      zx::eventpair view_token,
      fidl::InterfaceRequest<fuchsia::sys::ServiceProvider> incoming_services,
      fidl::InterfaceHandle<fuchsia::sys::ServiceProvider> outgoing_services)
      override;

  // |flutter::Engine::Delegate|
  void OnEngineTerminate(const Engine* holder) override;

  void AttemptVMLaunchWithCurrentSettings(const flutter::Settings& settings);

  FML_DISALLOW_COPY_AND_ASSIGN(Application);
};

}  // namespace flutter_runner

#endif  // TOPAZ_RUNTIME_FLUTTER_RUNNER_COMPONENT_H_
