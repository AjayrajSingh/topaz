// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef TOPAZ_RUNTIME_FLUTTER_RUNNER_COMPONENT_H_
#define TOPAZ_RUNTIME_FLUTTER_RUNNER_COMPONENT_H_

#include <array>
#include <memory>
#include <set>

#include <fuchsia/sys/cpp/fidl.h>
#include <fuchsia/ui/views_v1/cpp/fidl.h>
#include <fuchsia/ui/views_v1_token/cpp/fidl.h>
#include <lib/fit/function.h>

#include "engine.h"
#include "flutter/common/settings.h"
#include "lib/app/cpp/startup_context.h"
#include "lib/fidl/cpp/binding_set.h"
#include "lib/fidl/cpp/interface_request.h"
#include "lib/fxl/files/unique_fd.h"
#include "lib/fxl/macros.h"
#include "lib/svc/cpp/service_provider_bridge.h"
#include "topaz/lib/deprecated_loop/thread.h"
#include "unique_fdio_ns.h"

namespace flutter {

// Represents an instance of a Flutter application that contains one of more
// Flutter engine instances.
class Application final : public Engine::Delegate,
                          public fuchsia::sys::ComponentController,
                          public fuchsia::ui::views_v1::ViewProvider {
 public:
  using TerminationCallback = fit::function<void(const Application*)>;

  // Creates a dedicated thread to run the application and constructions the
  // application on it. The application can be accessed only on this thread.
  // This is a synchronous operation.
  static std::pair<std::unique_ptr<deprecated_loop::Thread>,
                   std::unique_ptr<Application>>
  Create(TerminationCallback termination_callback,
         fuchsia::sys::Package package, fuchsia::sys::StartupInfo startup_info,
         fidl::InterfaceRequest<fuchsia::sys::ComponentController> controller);

  // Must be called on the same thread returned from the create call. The thread
  // may be collected after.
  ~Application();

  const std::string& GetDebugLabel() const;

 private:
  blink::Settings settings_;
  TerminationCallback termination_callback_;
  const std::string debug_label_;
  UniqueFDIONS fdio_ns_ = UniqueFDIONSCreate();
  fxl::UniqueFD application_directory_;
  fxl::UniqueFD application_assets_directory_;
  fidl::Binding<fuchsia::sys::ComponentController> application_controller_;
  fidl::InterfaceRequest<fuchsia::sys::ServiceProvider>
      outgoing_services_request_;
  fuchsia::sys::ServiceProviderBridge service_provider_bridge_;
  std::unique_ptr<fuchsia::sys::StartupContext> startup_context_;
  fidl::BindingSet<fuchsia::ui::views_v1::ViewProvider> shells_bindings_;
  fxl::RefPtr<blink::DartSnapshot> isolate_snapshot_;
  fxl::RefPtr<blink::DartSnapshot> shared_snapshot_;
  std::set<std::unique_ptr<Engine>> shell_holders_;
  std::vector<WaitCallback> wait_callbacks_;
  std::pair<bool, uint32_t> last_return_code_;

  Application(
      TerminationCallback termination_callback, fuchsia::sys::Package package,
      fuchsia::sys::StartupInfo startup_info,
      fidl::InterfaceRequest<fuchsia::sys::ComponentController> controller);

  // |fuchsia::sys::ComponentController|
  void Kill() override;

  // |fuchsia::sys::ComponentController|
  void Detach() override;

  // |fuchsia::sys::ComponentController|
  void Wait(WaitCallback callback) override;

  // |fuchsia::ui::views_v1::ViewProvider|
  void CreateView(
      fidl::InterfaceRequest<fuchsia::ui::views_v1_token::ViewOwner> view_owner,
      fidl::InterfaceRequest<fuchsia::sys::ServiceProvider> services) override;

  // |flutter::Engine::Delegate|
  void OnEngineTerminate(const Engine* holder) override;

  void CreateShellForView(
      fidl::InterfaceRequest<fuchsia::ui::views_v1::ViewProvider>
          view_provider_request);

  void AttemptVMLaunchWithCurrentSettings(const blink::Settings& settings);

  FXL_DISALLOW_COPY_AND_ASSIGN(Application);
};

}  // namespace flutter

#endif  // TOPAZ_RUNTIME_FLUTTER_RUNNER_COMPONENT_H_
