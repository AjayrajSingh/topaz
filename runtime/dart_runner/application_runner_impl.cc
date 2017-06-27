// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "apps/dart_content_handler/application_runner_impl.h"

#include <mx/process.h>
#include <thread>
#include <utility>

#include "apps/dart_content_handler/dart_application_controller.h"
#include "lib/mtl/tasks/message_loop.h"
#include "lib/mtl/vmo/vector.h"
#include "lib/zip/unzipper.h"

namespace dart_content_handler {
namespace {

constexpr char kSnapshotKey[] = "snapshot_blob.bin";

std::vector<char> ExtractSnapshot(std::vector<char> bundle) {
  zip::Unzipper unzipper(std::move(bundle));
  return unzipper.Extract(kSnapshotKey);
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
  std::vector<char> snapshot = ExtractSnapshot(std::move(bundle));

  mtl::MessageLoop loop;

  // Name this process after the url of the application being launched.
  std::string label = "dart:" + GetLabelFromURL(startup_info->launch_info->url);
  mx::process::self().set_property(MX_PROP_NAME, label.c_str(), label.size());

  DartApplicationController app(std::move(snapshot), std::move(startup_info),
                                std::move(controller));

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
