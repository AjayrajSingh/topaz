// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "runner.h"

#include <zircon/types.h>

#include <sstream>
#include <utility>

#include "flutter/lib/ui/text/font_collection.h"
#include "fuchsia_font_manager.h"
#include "lib/fxl/functional/make_copyable.h"
#include "lib/icu_data/cpp/icu_data.h"
#include "third_party/flutter/runtime/dart_vm.h"
#include "third_party/skia/include/core/SkGraphics.h"

namespace flutter {

static void SetProcessName() {
  std::stringstream stream;
  stream << "io.flutter.runner.";
  if (blink::DartVM::IsRunningPrecompiledCode()) {
    stream << "aot";
  } else {
    stream << "jit";
  }
  const auto name = stream.str();
  zx::process::self()->set_property(ZX_PROP_NAME, name.c_str(), name.size());
}

static void SetThreadName(const std::string& thread_name) {
  zx::thread::self()->set_property(ZX_PROP_NAME, thread_name.c_str(),
                                  thread_name.size());
}

Runner::Runner()
    : host_context_(component::StartupContext::CreateFromStartupInfo()) {
  SkGraphics::Init();

  SetupICU();

  SetProcessName();

  SetThreadName("io.flutter.runner.main");

  host_context_->outgoing_services()->AddService<fuchsia::sys::Runner>(
      std::bind(&Runner::RegisterApplication, this, std::placeholders::_1));
}

Runner::~Runner() {
  host_context_->outgoing_services()->RemoveService<fuchsia::sys::Runner>();
}

void Runner::RegisterApplication(
    fidl::InterfaceRequest<fuchsia::sys::Runner> request) {
  active_applications_bindings_.AddBinding(this, std::move(request));
}

void Runner::StartComponent(
    fuchsia::sys::Package package, fuchsia::sys::StartupInfo startup_info,
    fidl::InterfaceRequest<fuchsia::sys::ComponentController> controller) {
  // Notes on application termination: Application typically terminate on the
  // thread on which they were created. This usually means the thread was
  // specifically created to host the application. But we want to ensure that
  // access to the active applications collection is made on the same thread. So
  // we capture the runner in the termination callback. There is no risk of
  // there being multiple application runner instance in the process at the same
  // time. So it is safe to use the raw pointer.
  Application::TerminationCallback termination_callback =
      [task_runner =
           deprecated_loop::MessageLoop::GetCurrent()->task_runner(),  //
       application_runner = this                                       //
  ](const Application* application) {
        task_runner->PostTask([application_runner, application]() {
          application_runner->OnApplicationTerminate(application);
        });
      };

  auto thread_application_pair = Application::Create(
      std::move(termination_callback),  // termination callback
      std::move(package),               // application pacakge
      std::move(startup_info),          // startup info
      std::move(controller)             // controller request
  );

  auto key = thread_application_pair.second.get();

  active_applications_[key] = std::move(thread_application_pair);
}

void Runner::OnApplicationTerminate(const Application* application) {
  auto app = active_applications_.find(application);
  if (app == active_applications_.end()) {
    FXL_LOG(INFO) <<
        "The remote end of the application runner tried to terminate an "
        "application that has already been terminated, possibly because we "
        "initiated the termination";
    return;
  }
  auto& active_application = app->second;

  // Grab the items out of the entry because we will have to rethread the
  // destruction.
  auto application_to_destroy = std::move(active_application.application);
  auto application_destruction_thread = std::move(active_application.thread);

  // Delegate the entry.
  active_applications_.erase(application);

  // Post the task to destroy the application and quit its message loop.
  auto runner = application_destruction_thread->TaskRunner();
  runner->PostTask(fxl::MakeCopyable(
      [instance = std::move(application_to_destroy)]() mutable {
        instance.reset();

        deprecated_loop::MessageLoop::GetCurrent()->PostQuitTask();
      }));

  // This works because just posted the quit task on the hosted thread.
  application_destruction_thread->Join();
}

void Runner::SetupICU() {
  if (!icu_data::Initialize(host_context_.get())) {
    FXL_LOG(ERROR) << "Could not initialize ICU data.";
  }
}

}  // namespace flutter
