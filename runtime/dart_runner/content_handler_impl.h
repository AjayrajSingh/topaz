// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "lib/ftl/macros.h"
#include "mojo/public/cpp/bindings/strong_binding.h"
#include "mojo/services/content_handler/interfaces/content_handler.mojom.h"

namespace dart_content_handler {

class ContentHandlerImpl : public mojo::ContentHandler {
 public:
  explicit ContentHandlerImpl(
      mojo::InterfaceRequest<mojo::ContentHandler> request);
  ~ContentHandlerImpl() override;

 private:
  // |mojo::ContentHandler| implementation:
  void StartApplication(mojo::InterfaceRequest<mojo::Application> application,
                        mojo::URLResponsePtr response) override;

  mojo::StrongBinding<mojo::ContentHandler> binding_;

  FTL_DISALLOW_COPY_AND_ASSIGN(ContentHandlerImpl);
};

}  // namespace dart_content_handler
