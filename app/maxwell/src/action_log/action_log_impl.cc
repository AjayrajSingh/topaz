// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "apps/maxwell/src/action_log/action_log_impl.h"

#include "lib/ftl/logging.h"
#include "lib/ftl/time/time_delta.h"
#include "lib/mtl/tasks/message_loop.h"

#include "apps/maxwell/services/suggestion/proposal.fidl.h"
#include "apps/maxwell/services/suggestion/suggestion_display.fidl.h"
#include "apps/maxwell/src/action_log/action_log_data.h"

#include "third_party/rapidjson/rapidjson/document.h"
#include "third_party/rapidjson/rapidjson/pointer.h"
#include "third_party/rapidjson/rapidjson/stringbuffer.h"
#include "third_party/rapidjson/rapidjson/writer.h"

namespace maxwell {

UserActionLogImpl::UserActionLogImpl(ProposalPublisherPtr proposal_publisher)
    : action_log_([this](const ActionData& action_data) {
        BroadcastToSubscribers(action_data);
        MaybeProposeSharingVideo(action_data);
        MaybeRecordEmailRecipient(action_data);
      }),
      proposal_publisher_(std::move(proposal_publisher)) {}

void UserActionLogImpl::BroadcastToSubscribers(const ActionData& action_data) {
  UserActionPtr action(UserAction::New());
  action->component_url = action_data.component_url;
  action->method = action_data.method;
  action->parameters = action_data.params;
  subscribers_.ForAllPtrs([action = std::move(action)](
      ActionLogListener * listener) { listener->OnAction(action.Clone()); });
}

void UserActionLogImpl::MaybeProposeSharingVideo(
    const ActionData& action_data) {
  if (action_data.story_id.empty() || action_data.module_path.empty()) {
    return;
  }
  if (action_data.method.compare("ViewVideo") != 0) {
    return;
  }
  // TODO(azani): Put information relevant to the video in the proposal.
  rapidjson::Document doc_params;
  if (doc_params.Parse(action_data.params).HasParseError()) {
    return;
  }
  rapidjson::Value* vid_value =
      rapidjson::Pointer("/youtube-doc/youtube-video-id").Get(doc_params);

  if (vid_value == nullptr || !vid_value->IsString()) {
    return;
  }
  std::string video_id = vid_value->GetString();
  std::string proposal_id = "Share Video " + action_data.story_id;

  ProposalPtr proposal(Proposal::New());
  proposal->id = proposal_id;

  auto add_module = AddModuleToStory::New();
  add_module->story_id = action_data.story_id;
  add_module->module_url = "file:///system/apps/email/composer";
  add_module->module_name = video_id;

  for (auto segment = action_data.module_path.begin();
       segment != action_data.module_path.end(); segment++) {
    add_module->module_path.push_back(*segment);
  }

  // HACK(alhaad): There is an issue that the root youtube module (A) actually
  // embeds 2 other modules (B and C) and it's an embeded module (B) that
  // produces this action log.
  // Story shell freaks out when we try to add a new module (D) parented at (B)
  // because it does not know about it (B). So instead we use some domain
  // specific information to parent new module (D) at (A) instead.
  size_t module_path_size = add_module->module_path.size();
  if (module_path_size > 0) {
    add_module->module_path.resize(module_path_size - 1);
  }

  add_module->link_name = "email-composer-link";
  // TODO(azani): Do something sane.
  std::string initial_data = "{\"email-composer\": {\"message\": {";
  if (!last_email_rcpt_.empty()) {
    initial_data += "\"to\": [\"" + last_email_rcpt_ + "\"]";
  }
  initial_data += "\"subject\": \"Really cool video!!!!1one\",";
  initial_data += "\"text\": \"http://www.youtube.com/watch?v=";
  initial_data += video_id + "\"}}}";
  add_module->initial_data = initial_data;

  ActionPtr action(Action::New());
  action->set_add_module_to_story(std::move(add_module));
  proposal->on_selected.push_back(std::move(action));

  SuggestionDisplayPtr display(SuggestionDisplay::New());
  display->headline = "Share Video via email";
  display->subheadline = "";
  display->details = "";
  display->color = 0xff42ebf4;
  display->icon_urls.push_back("");
  display->image_url = "";
  display->image_type = SuggestionImageType::OTHER;
  proposal->display = std::move(display);

  // We clear any existing proposal for this story.
  proposal_publisher_->Remove(proposal_id);
  proposal_publisher_->Propose(std::move(proposal));
}

void UserActionLogImpl::MaybeRecordEmailRecipient(
    const ActionData& action_data) {
  if (action_data.method.compare("SendEmail") != 0) {
    return;
  }
  rapidjson::Document doc_params;
  if (doc_params.Parse(action_data.params).HasParseError()) {
    return;
  }
  rapidjson::Value* rcpt_value =
      rapidjson::Pointer("/to/0/address").Get(doc_params);

  if (rcpt_value == nullptr || !rcpt_value->IsString()) {
    return;
  }

  last_email_rcpt_ = rcpt_value->GetString();
}

void UserActionLogImpl::GetComponentActionLog(
    ComponentScopePtr scope,
    fidl::InterfaceRequest<ComponentActionLog> action_log_request) {
  std::unique_ptr<ComponentActionLogImpl> module_action_log_impl(
      new ComponentActionLogImpl(
          action_log_.GetActionLogger(std::move(scope))));

  action_log_bindings_.AddBinding(std::move(module_action_log_impl),
                                  std::move(action_log_request));
}

void UserActionLogImpl::Duplicate(
    fidl::InterfaceRequest<UserActionLog> request) {
  bindings_.AddBinding(this, std::move(request));
}

void UserActionLogImpl::Subscribe(
    fidl::InterfaceHandle<ActionLogListener> listener_handle) {
  ActionLogListenerPtr listener =
      ActionLogListenerPtr::Create(std::move(listener_handle));
  subscribers_.AddInterfacePtr(std::move(listener));
}

void ComponentActionLogImpl::LogAction(const fidl::String& method,
                                       const fidl::String& json_params) {
  rapidjson::Document params;
  if (params.Parse(json_params.get().c_str()).HasParseError()) {
    FTL_LOG(WARNING) << "Parse error.";
    return;
  }

  log_action_(method, json_params);
}

}  // namespace maxwell
