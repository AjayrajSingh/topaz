// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "apps/maxwell/services/context/context_engine.fidl.h"
#include "apps/maxwell/services/context/context_publisher.fidl.h"
#include "apps/maxwell/services/context/context_provider.fidl.h"
#include "apps/maxwell/src/context_engine/context_repository.h"
#include "lib/fidl/cpp/bindings/binding_set.h"

namespace maxwell {

class ContextEngineImpl : public ContextEngine {
 public:
  ContextEngineImpl();
  ~ContextEngineImpl() override;

 private:
  // |ContextEngine|
  void GetPublisher(
      ComponentScopePtr scope,
      fidl::InterfaceRequest<ContextPublisher> request) override;

  // |ContextEngine|
  void GetProvider(
      ComponentScopePtr scope,
      fidl::InterfaceRequest<ContextProvider> request) override;

  ContextRepository repository_;

  fidl::BindingSet<ContextPublisher, std::unique_ptr<ContextPublisher>>
      publisher_bindings_;
  fidl::BindingSet<ContextProvider, std::unique_ptr<ContextProvider>>
      provider_bindings_;

  FTL_DISALLOW_COPY_AND_ASSIGN(ContextEngineImpl);
};

}  // namespace maxwell
