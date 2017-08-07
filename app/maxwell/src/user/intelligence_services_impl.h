// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#pragma once

#include "apps/maxwell/services/action_log/user.fidl.h"
#include "apps/maxwell/services/user/intelligence_services.fidl.h"
#include "apps/maxwell/services/user/scope.fidl.h"

namespace maxwell {

class ContextEngine;
class SuggestionEngine;

class IntelligenceServicesImpl : public IntelligenceServices {
 public:
  // |context_engine| and |suggestion_engine| are not owned and must outlive
  // this instance.
  IntelligenceServicesImpl(ComponentScopePtr scope,
                           ContextEngine* context_engine,
                           SuggestionEngine* suggestion_engine,
                           UserActionLog* user_action_log);

  void GetContextReader(fidl::InterfaceRequest<ContextReader> request) override;

  void GetContextPublisher(
      fidl::InterfaceRequest<ContextPublisher> request) override;

  void GetProposalPublisher(
      fidl::InterfaceRequest<ProposalPublisher> request) override;

  void GetActionLog(
      fidl::InterfaceRequest<ComponentActionLog> request) override;

 private:
  ComponentScopePtr scope_;
  ContextEngine* const context_engine_;        // Not owned.
  SuggestionEngine* const suggestion_engine_;  // Not owned.
  UserActionLog* const user_action_log_;       // Not owned.
};

}  // namespace maxwell
