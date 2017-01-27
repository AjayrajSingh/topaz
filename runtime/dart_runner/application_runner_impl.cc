// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "apps/dart_content_handler/application_runner_impl.h"

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

void RunApplication(
    modular::ApplicationPackagePtr application,
    modular::ApplicationStartupInfoPtr startup_info,
    ::fidl::InterfaceRequest<modular::ApplicationController> controller) {
  // Extract a dart snapshot from the application package data.
  std::vector<char> bundle;
  if (!mtl::VectorFromVmo(application->data, &bundle)) {
    FTL_LOG(ERROR) << "Failed to read application data.";
    return;
  }
  std::vector<char> snapshot = ExtractSnapshot(std::move(bundle));

  mtl::MessageLoop loop;

  DartApplicationController app(std::move(snapshot), std::move(startup_info),
                                std::move(controller));
  if (app.Main())
    loop.Run();
}

}  // namespace

ApplicationRunnerImpl::ApplicationRunnerImpl(
    fidl::InterfaceRequest<modular::ApplicationRunner> app_runner)
    : binding_(this, std::move(app_runner)) {}

ApplicationRunnerImpl::~ApplicationRunnerImpl() {}

void ApplicationRunnerImpl::StartApplication(
    modular::ApplicationPackagePtr application,
    modular::ApplicationStartupInfoPtr startup_info,
    ::fidl::InterfaceRequest<modular::ApplicationController> controller) {
  std::thread thread(RunApplication, std::move(application),
                     std::move(startup_info), std::move(controller));
  thread.detach();
}

}  // namespace dart_content_handler
