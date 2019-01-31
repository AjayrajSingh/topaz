// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "engine.h"

#include <sstream>

#include "flutter/common/task_runners.h"
#include "flutter/fml/make_copyable.h"
#include "flutter/fml/synchronization/waitable_event.h"
#include "flutter/fml/task_runner.h"
#include "flutter/shell/common/rasterizer.h"
#include "flutter/shell/common/run_configuration.h"
#include "fuchsia_font_manager.h"
#include "lib/fxl/files/file.h"
#include "platform_view.h"
#include "task_runner_adapter.h"
#include "topaz/lib/deprecated_loop/message_loop.h"

namespace flutter {

static void UpdateNativeThreadLabelNames(const std::string& label,
                                         const blink::TaskRunners& runners) {
  auto set_thread_name = [](fml::RefPtr<fml::TaskRunner> runner,
                            std::string prefix, std::string suffix) {
    if (!runner) {
      return;
    }
    fml::TaskRunner::RunNowOrPostTask(runner, [name = prefix + suffix]() {
      zx::thread::self()->set_property(ZX_PROP_NAME, name.c_str(), name.size());
    });
  };
  set_thread_name(runners.GetPlatformTaskRunner(), label, ".platform");
  set_thread_name(runners.GetUITaskRunner(), label, ".ui");
  set_thread_name(runners.GetGPUTaskRunner(), label, ".gpu");
  set_thread_name(runners.GetIOTaskRunner(), label, ".io");
}

Engine::Engine(Delegate& delegate, std::string thread_label,
               component::StartupContext& startup_context,
               blink::Settings settings,
               fml::RefPtr<blink::DartSnapshot> isolate_snapshot,
               fml::RefPtr<blink::DartSnapshot> shared_snapshot,
               zx::eventpair view_token, UniqueFDIONS fdio_ns,
               fidl::InterfaceRequest<fuchsia::io::Directory> directory_request)
    : delegate_(delegate),
      thread_label_(std::move(thread_label)),
      settings_(std::move(settings)),
      weak_factory_(this) {
  if (zx::event::create(0, &vsync_event_) != ZX_OK) {
    FML_DLOG(ERROR) << "Could not create the vsync event.";
    return;
  }

  // Launch the threads that will be used to run the shell. These threads will
  // be joined in the destructor.
  for (auto& thread : host_threads_) {
    thread.Run();
  }

  // Set up the session connection.
  auto scenic = startup_context
                    .ConnectToEnvironmentService<fuchsia::ui::scenic::Scenic>();
  fidl::InterfaceHandle<fuchsia::ui::scenic::Session> session;
  fidl::InterfaceHandle<fuchsia::ui::scenic::SessionListener> session_listener;
  auto session_listener_request = session_listener.NewRequest();
  scenic->CreateSession(session.NewRequest(), session_listener.Bind());

#ifndef SCENIC_VIEWS2
  fuchsia::ui::viewsv1::ViewManagerPtr view_manager;
  startup_context.ConnectToEnvironmentService(view_manager.NewRequest());

  zx::eventpair import_token, export_token;
  if (zx::eventpair::create(0u, &import_token, &export_token) != ZX_OK) {
    FML_DLOG(ERROR) << "Could not create event pair.";
    return;
  }
#endif

  // Grab the parent environent services. The platform view may want to access
  // some of these services.
  fidl::InterfaceHandle<fuchsia::sys::ServiceProvider>
      parent_environment_service_provider;
  startup_context.environment()->GetServices(
      parent_environment_service_provider.NewRequest());

  // Grab the accessibilty context writer that can understand the semantics tree
  // on the platform view.
  fidl::InterfaceHandle<fuchsia::modular::ContextWriter>
      accessibility_context_writer;
  startup_context.ConnectToEnvironmentService(
      accessibility_context_writer.NewRequest());

  // We need to manually schedule a frame when the session metrics change.
  OnMetricsUpdate on_session_metrics_change_callback = std::bind(
      &Engine::OnSessionMetricsDidChange, this, std::placeholders::_1);

  OnSizeChangeHint on_session_size_change_hint_callback =
      std::bind(&Engine::OnSessionSizeChangeHint, this, std::placeholders::_1,
                std::placeholders::_2);

  // SessionListener has a OnScenicError method; invoke this callback on the
  // platform thread when that happens. The Session itself should also be
  // disconnected when this happens, and it will also attempt to terminate.
  fit::closure on_session_listener_error_callback =
      [runner = deprecated_loop::MessageLoop::GetCurrent()->task_runner(),
       weak = weak_factory_.GetWeakPtr()]() {
        runner->PostTask([weak]() {
          if (weak) {
            weak->Terminate();
          }
        });
      };

  // Setup the callback that will instantiate the platform view.
  shell::Shell::CreateCallback<shell::PlatformView> on_create_platform_view =
      fml::MakeCopyable([debug_label = thread_label_,
                         parent_environment_service_provider =
                             std::move(parent_environment_service_provider),
                         session_listener_request =
                             std::move(session_listener_request),
                         on_session_listener_error_callback =
                             std::move(on_session_listener_error_callback),
                         on_session_metrics_change_callback =
                             std::move(on_session_metrics_change_callback),
                         on_session_size_change_hint_callback =
                             std::move(on_session_size_change_hint_callback),
#ifndef SCENIC_VIEWS2
                         view_manager = view_manager.Unbind(),
                         view_token = std::move(view_token),
                         export_token = std::move(export_token),
#endif
                         accessibility_context_writer =
                             std::move(accessibility_context_writer),
                         vsync_handle =
                             vsync_event_.get()](shell::Shell& shell) mutable {
        return std::make_unique<flutter::PlatformView>(
            shell,                                           // delegate
            debug_label,                                     // debug label
            shell.GetTaskRunners(),                          // task runners
            std::move(parent_environment_service_provider),  // services
            std::move(session_listener_request),             // session listener
            std::move(on_session_listener_error_callback),
            std::move(on_session_metrics_change_callback),
            std::move(on_session_size_change_hint_callback),
#ifndef SCENIC_VIEWS2
            std::move(view_manager),  // view manager
            std::move(view_token),    // view token
            std::move(export_token),  // export token
#endif
            std::move(
                accessibility_context_writer),  // accessibility context writer
            vsync_handle                        // vsync handle
        );
      });

  // Session can be terminated on the GPU thread, but we must terminate
  // ourselves on the platform thread.
  //
  // This handles the fidl error callback when the Session connection is
  // broken. The SessionListener interface also has an OnError method, which is
  // invoked on the platform thread (in PlatformView).
  fit::closure on_session_error_callback =
      [runner = deprecated_loop::MessageLoop::GetCurrent()->task_runner(),
       weak = weak_factory_.GetWeakPtr()]() {
        runner->PostTask([weak]() {
          if (weak) {
            weak->Terminate();
          }
        });
      };

  // Create the compositor context from the scenic pointer to create the
  // rasterizer.
  std::unique_ptr<flow::CompositorContext> compositor_context;
  {
    TRACE_DURATION("flutter", "CreateCompositorContext");
    compositor_context = std::make_unique<flutter::CompositorContext>(
        thread_label_,  // debug label
#ifndef SCENIC_VIEWS2
        std::move(import_token),  // import token (scenic node we attach our
                                  // tree to)
#else
        std::move(view_token),    // scenic view we attach our tree to
#endif
        std::move(session),                    // scenic session
        std::move(on_session_error_callback),  // session did encounter error
        vsync_event_.get()                     // vsync event handle
    );
  }

  // Setup the callback that will instantiate the rasterizer.
  shell::Shell::CreateCallback<shell::Rasterizer> on_create_rasterizer =
      fml::MakeCopyable([compositor_context = std::move(compositor_context)](
                            shell::Shell& shell) mutable {
        return std::make_unique<shell::Rasterizer>(
            shell.GetTaskRunners(),        // task runners
            std::move(compositor_context)  // compositor context
        );
      });

  // Get the task runners from the managed threads. The current thread will be
  // used as the "platform" thread.
  const blink::TaskRunners task_runners(
      thread_label_,  // Dart thread labels
      CreateFMLTaskRunner(deprecated_loop::MessageLoop::GetCurrent()
                              ->task_runner()),            // platform
      CreateFMLTaskRunner(host_threads_[0].TaskRunner()),  // gpu
      CreateFMLTaskRunner(host_threads_[1].TaskRunner()),  // ui
      CreateFMLTaskRunner(host_threads_[2].TaskRunner())   // io
  );

  UpdateNativeThreadLabelNames(thread_label_, task_runners);

  settings_.verbose_logging = true;

  settings_.advisory_script_uri = thread_label_;

  settings_.root_isolate_create_callback =
      std::bind(&Engine::OnMainIsolateStart, this);

  settings_.root_isolate_shutdown_callback =
      std::bind([weak = weak_factory_.GetWeakPtr(),
                 runner = task_runners.GetPlatformTaskRunner()]() {
        runner->PostTask([weak = std::move(weak)] {
          if (weak) {
            weak->OnMainIsolateShutdown();
          }
        });
      });

  if (!isolate_snapshot) {
    isolate_snapshot =
        blink::DartVM::ForProcess(settings_)->GetIsolateSnapshot();
  }
  if (!shared_snapshot) {
    shared_snapshot = blink::DartSnapshot::Empty();
  }

  {
    TRACE_DURATION("flutter", "CreateShell");
    shell_ = shell::Shell::Create(
        task_runners,                 // host task runners
        settings_,                    // shell launch settings
        std::move(isolate_snapshot),  // isolate snapshot
        std::move(shared_snapshot),   // shared snapshot
        on_create_platform_view,      // platform view create callback
        on_create_rasterizer          // rasterizer create callback
    );
  }

  if (!shell_) {
    FML_LOG(ERROR) << "Could not launch the shell with settings: "
                   << settings_.ToString();
    return;
  }

  // Shell has been created. Before we run the engine, setup the isolate
  // configurator.
  {
#ifndef SCENIC_VIEWS2
    auto view_container =
        static_cast<PlatformView*>(shell_->GetPlatformView().get())
            ->TakeViewContainer();
#endif

    fuchsia::sys::EnvironmentPtr environment;
    startup_context.ConnectToEnvironmentService(environment.NewRequest());

    isolate_configurator_ = std::make_unique<IsolateConfigurator>(
        std::move(fdio_ns),  //
#ifndef SCENIC_VIEWS2
        std::move(view_container),  //
#endif
        std::move(environment),          //
        directory_request.TakeChannel()  //
    );
  }

  //  This platform does not get a separate surface platform view creation
  //  notification. Fire one eagerly.
  shell_->GetPlatformView()->NotifyCreated();

  // Launch the engine in the appropriate configuration.
  auto run_configuration = shell::RunConfiguration::InferFromSettings(
      settings_, task_runners.GetIOTaskRunner());

  auto on_run_failure =
      [weak = weak_factory_.GetWeakPtr(),                                  //
       runner = deprecated_loop::MessageLoop::GetCurrent()->task_runner()  //
  ]() {
        // The engine could have been killed by the caller right after the
        // constructor was called but before it could run on the UI thread.
        if (weak) {
          weak->Terminate();
        }
      };

  // Connect to the system font provider.
  fuchsia::fonts::ProviderSyncPtr sync_font_provider;
  startup_context.ConnectToEnvironmentService(sync_font_provider.NewRequest());

  shell_->GetTaskRunners().GetUITaskRunner()->PostTask(
      fml::MakeCopyable([engine = shell_->GetEngine(),                        //
                         run_configuration = std::move(run_configuration),    //
                         sync_font_provider = std::move(sync_font_provider),  //
                         on_run_failure                                       //
  ]() mutable {
        if (!engine) {
          return;
        }

        // Set default font manager.
        engine->GetFontCollection().GetFontCollection()->SetDefaultFontManager(
            sk_make_sp<txt::FuchsiaFontManager>(std::move(sync_font_provider)));

        if (engine->Run(std::move(run_configuration)) ==
            shell::Engine::RunStatus::Failure) {
          on_run_failure();
        }
      }));
}

Engine::~Engine() {
  shell_.reset();
  for (const auto& thread : host_threads_) {
    thread.TaskRunner()->PostTask(
        []() { deprecated_loop::MessageLoop::GetCurrent()->PostQuitTask(); });
  }
}

std::pair<bool, uint32_t> Engine::GetEngineReturnCode() const {
  std::pair<bool, uint32_t> code(false, 0);
  if (!shell_) {
    return code;
  }
  fml::AutoResetWaitableEvent latch;
  fml::TaskRunner::RunNowOrPostTask(
      shell_->GetTaskRunners().GetUITaskRunner(),
      [&latch, &code, engine = shell_->GetEngine()]() {
        if (engine) {
          code = engine->GetUIIsolateReturnCode();
        }
        latch.Signal();
      });
  latch.Wait();
  return code;
}

static void CreateCompilationTrace(Dart_Isolate isolate) {
  Dart_EnterIsolate(isolate);

  {
    Dart_EnterScope();
    uint8_t* trace = nullptr;
    intptr_t trace_length = 0;
    Dart_Handle result = Dart_SaveCompilationTrace(&trace, &trace_length);
    tonic::LogIfError(result);
    const std::string kCompilationTraceFile = "/data/dart_compilation_trace.txt";
    if (files::WriteFile(kCompilationTraceFile,
                         reinterpret_cast<const char*>(trace),
                         trace_length)) {
      FML_LOG(ERROR) << "Dart compilation trace written to "
                     << kCompilationTraceFile;
    } else {
      FML_LOG(ERROR) << "Could not write Dart compilation trace to "
                     << kCompilationTraceFile;
    }
    Dart_ExitScope();
  }

  // Re-enter Dart scope to release the compilation trace's memory.

  {
    Dart_EnterScope();
    uint8_t* feedback = nullptr;
    intptr_t feedback_length = 0;
    Dart_Handle result = Dart_SaveTypeFeedback(&feedback, &feedback_length);
    tonic::LogIfError(result);
    const std::string kTypeFeedbackFile = "/data/dart_type_feedback.bin";
    if (files::WriteFile(kTypeFeedbackFile,
                         reinterpret_cast<const char*>(feedback),
                         feedback_length)) {
      FML_LOG(ERROR) << "Dart type feedback written to "
                     << kTypeFeedbackFile;
    } else {
      FML_LOG(ERROR) << "Could not write Dart type feedback to "
                     << kTypeFeedbackFile;
    }
    Dart_ExitScope();
  }

  Dart_ExitIsolate();
}

void Engine::OnMainIsolateStart() {
  if (!isolate_configurator_ ||
      !isolate_configurator_->ConfigureCurrentIsolate(this)) {
    FML_LOG(ERROR) << "Could not configure some native embedder bindings for a "
                      "new root isolate.";
  }
  FML_DLOG(INFO) << "Main isolate for engine '" << thread_label_
                 << "' was started.";

  const intptr_t kCompilationTraceDelayInSeconds = 0;
  if (kCompilationTraceDelayInSeconds != 0) {
    Dart_Isolate isolate = Dart_CurrentIsolate();
    FML_CHECK(isolate);
    shell_->GetTaskRunners().GetUITaskRunner()->PostDelayedTask(
        [engine = shell_->GetEngine(), isolate]() {
          if (!engine) {
            return;
          }
          CreateCompilationTrace(isolate);
        },
        fml::TimeDelta::FromSeconds(kCompilationTraceDelayInSeconds));
  }
}

void Engine::OnMainIsolateShutdown() {
  FML_DLOG(INFO) << "Main isolate for engine '" << thread_label_
                 << "' shutting down.";
  Terminate();
}

void Engine::Terminate() {
  delegate_.OnEngineTerminate(this);
  // Warning. Do not do anything after this point as the delegate may have
  // collected this object.
}

void Engine::OnSessionMetricsDidChange(
    const fuchsia::ui::gfx::Metrics& metrics) {
  if (!shell_) {
    return;
  }

  shell_->GetTaskRunners().GetGPUTaskRunner()->PostTask(
      [rasterizer = shell_->GetRasterizer(), metrics]() {
        if (rasterizer) {
          auto compositor_context =
              reinterpret_cast<flutter::CompositorContext*>(
                  rasterizer->compositor_context());

          compositor_context->OnSessionMetricsDidChange(metrics);
        }
      });
}

void Engine::OnSessionSizeChangeHint(float width_change_factor,
                                     float height_change_factor) {
  if (!shell_) {
    return;
  }

  shell_->GetTaskRunners().GetGPUTaskRunner()->PostTask(
      [rasterizer = shell_->GetRasterizer(), width_change_factor,
       height_change_factor]() {
        if (rasterizer) {
          auto compositor_context =
              reinterpret_cast<flutter::CompositorContext*>(
                  rasterizer->compositor_context());

          compositor_context->OnSessionSizeChangeHint(width_change_factor,
                                                      height_change_factor);
        }
      });
}

// |mozart::NativesDelegate|
void Engine::OfferServiceProvider(
    fidl::InterfaceHandle<fuchsia::sys::ServiceProvider> service_provider,
    std::vector<std::string> services) {
#ifndef SCENIC_VIEWS2
  if (!shell_) {
    return;
  }

  shell_->GetTaskRunners().GetPlatformTaskRunner()->PostTask(
      fml::MakeCopyable([platform_view = shell_->GetPlatformView(),       //
                         service_provider = std::move(service_provider),  //
                         services = std::move(services)                   //
  ]() mutable {
        if (platform_view) {
          reinterpret_cast<flutter::PlatformView*>(platform_view.get())
              ->OfferServiceProvider(std::move(service_provider),
                                     std::move(services));
        }
      }));
#else
                                  // TODO(SCN-840): Remove OfferServiceProvider.
#endif
}

}  // namespace flutter
