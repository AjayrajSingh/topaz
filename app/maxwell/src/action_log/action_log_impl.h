// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#pragma once

#include <memory>
#include <string>
#include <vector>

#include "apps/maxwell/services/action_log/component.fidl.h"
#include "apps/maxwell/services/action_log/listener.fidl.h"
#include "apps/maxwell/services/action_log/user.fidl.h"
#include "apps/maxwell/services/suggestion/proposal_publisher.fidl.h"
#include "apps/maxwell/src/action_log/action_log_data.h"

#include "lib/fidl/cpp/bindings/binding_set.h"
#include "lib/fidl/cpp/bindings/interface_ptr_set.h"

namespace maxwell {

class UserActionLogImpl : public UserActionLog {
 public:
  UserActionLogImpl(ProposalPublisherPtr proposal_publisher);

 private:
  void GetComponentActionLog(
      maxwell::ComponentScopePtr scope,
      fidl::InterfaceRequest<ComponentActionLog> action_log_request) override;

  void Subscribe(
      fidl::InterfaceHandle<ActionLogListener> listener_handle) override;

  void Duplicate(fidl::InterfaceRequest<UserActionLog> request) override;

  void BroadcastToSubscribers(const std::string& component_url,
                              const std::string& method,
                              const std::string& params);

  void ProposeSharingVideo(const std::string& component_url,
                           const std::string& method,
                           const std::string& params);

  void LogDummyActionDelayed();

  ActionLogData action_log_;
  ProposalPublisherPtr proposal_publisher_;
  fidl::BindingSet<ComponentActionLog, std::unique_ptr<ComponentActionLog>>
      action_log_bindings_;
  fidl::InterfacePtrSet<ActionLogListener> subscribers_;
  fidl::BindingSet<UserActionLog> bindings_;

  FTL_DISALLOW_COPY_AND_ASSIGN(UserActionLogImpl);
};

class ComponentActionLogImpl : public ComponentActionLog {
 public:
  ComponentActionLogImpl(ActionLogger log_action) : log_action_(log_action) {}

  void LogAction(const fidl::String& method,
                 const fidl::String& params) override;

 private:
  const ActionLogger log_action_;

  FTL_DISALLOW_COPY_AND_ASSIGN(ComponentActionLogImpl);
};
}  // namespace maxwell
