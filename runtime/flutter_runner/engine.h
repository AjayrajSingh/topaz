// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef TOPAZ_RUNTIME_FLUTTER_RUNNER_ENGINE_H_
#define TOPAZ_RUNTIME_FLUTTER_RUNNER_ENGINE_H_

#include <fuchsia/io/cpp/fidl.h>
#include <fuchsia/ui/viewsv1/cpp/fidl.h>
#include <zx/event.h>
#include <zx/eventpair.h>

#include "flutter/fml/macros.h"
#include "flutter/shell/common/shell.h"
#include "isolate_configurator.h"
#include "lib/component/cpp/startup_context.h"
#include "lib/fxl/memory/weak_ptr.h"
#include "lib/ui/flutter/sdk_ext/src/natives.h"
#include "topaz/lib/deprecated_loop/thread.h"

namespace flutter {

// Represents an instance of running Flutter engine along with the threads
// that host the same.
class Engine final : public mozart::NativesDelegate {
 public:
  class Delegate {
   public:
    virtual void OnEngineTerminate(const Engine* holder) = 0;
  };

  Engine(Delegate& delegate, std::string thread_label,
         component::StartupContext& startup_context, blink::Settings settings,
         fml::RefPtr<blink::DartSnapshot> isolate_snapshot,
         fml::RefPtr<blink::DartSnapshot> shared_snapshot,
         zx::eventpair view_token, UniqueFDIONS fdio_ns,
         fidl::InterfaceRequest<fuchsia::io::Directory> directory_request);
  ~Engine();

  // Returns the Dart return code for the root isolate if one is present. This
  // call is thread safe and synchronous. This call must be made infrequently.
  std::pair<bool, uint32_t> GetEngineReturnCode() const;

 private:
  Delegate& delegate_;
  const std::string thread_label_;
  blink::Settings settings_;
  std::array<deprecated_loop::Thread, 3> host_threads_;
  std::unique_ptr<IsolateConfigurator> isolate_configurator_;
  std::unique_ptr<shell::Shell> shell_;
  zx::event vsync_event_;
  fml::WeakPtrFactory<Engine> weak_factory_;

  void OnMainIsolateStart();

  void OnMainIsolateShutdown();

  void Terminate();

  void OnSessionMetricsDidChange(const fuchsia::ui::gfx::Metrics& metrics);
  void OnSessionSizeChangeHint(float width_change_factor,
                               float height_change_factor);

  // |mozart::NativesDelegate|
  void OfferServiceProvider(
      fidl::InterfaceHandle<fuchsia::sys::ServiceProvider> service_provider,
      std::vector<std::string> services);

  FML_DISALLOW_COPY_AND_ASSIGN(Engine);
};

}  // namespace flutter

#endif  // TOPAZ_RUNTIME_FLUTTER_RUNNER_ENGINE_H_
