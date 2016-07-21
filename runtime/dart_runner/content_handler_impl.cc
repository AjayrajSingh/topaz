// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "apps/dart_content_handler/content_handler_impl.h"

#include <thread>
#include <utility>

#include "apps/dart_content_handler/dart_application.h"

namespace dart_content_handler {
namespace {

void RunApplication(mojo::InterfaceRequest<mojo::Application> application,
                    mojo::URLResponsePtr response) {
  DartApplication app(std::move(application), std::move(response));
  app.Run();
}

}  // namespace

ContentHandlerImpl::ContentHandlerImpl(
    mojo::InterfaceRequest<mojo::ContentHandler> request)
    : binding_(this, std::move(request)) {}

ContentHandlerImpl::~ContentHandlerImpl() {}

void ContentHandlerImpl::StartApplication(
    mojo::InterfaceRequest<mojo::Application> application,
    mojo::URLResponsePtr response) {
  std::thread thread(RunApplication, std::move(application),
                     std::move(response));
  thread.detach();
}

}  // namespace dart_content_handler
