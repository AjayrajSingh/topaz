// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "lib/ftl/macros.h"
#include "mojo/services/content_handler/interfaces/content_handler.mojom.h"

namespace dart_content_handler {

class DartApplication {
 public:
  DartApplication(mojo::InterfaceRequest<mojo::Application> application,
                  mojo::URLResponsePtr response);
  ~DartApplication();

  void Run();

 private:
  mojo::InterfaceRequest<mojo::Application> application_;
  mojo::URLResponsePtr response_;

  FTL_DISALLOW_COPY_AND_ASSIGN(DartApplication);
};

}  // namespace dart_content_handler
