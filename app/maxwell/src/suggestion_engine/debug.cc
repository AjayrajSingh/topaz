// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include <functional>

#include "apps/maxwell/src/suggestion_engine/debug.h"

namespace maxwell {

SuggestionDebugImpl::SuggestionDebugImpl() {}

void makeProposalSummary(const SuggestionPrototype* suggestion,
                         ProposalSummaryPtr* summary) {
  (*summary)->id = suggestion->proposal->id;
  (*summary)->display = suggestion->proposal->display.Clone();
}

void makeProposalSummaries(const RankedSuggestions* suggestions,
                           fidl::Array<ProposalSummaryPtr>* summaries) {
  for (auto it = suggestions->begin(); it < suggestions->end(); it++) {
    ProposalSummaryPtr summary = ProposalSummary::New();
    makeProposalSummary((*it)->prototype, &summary);
    summaries->push_back(std::move(summary));
  }
}

void SuggestionDebugImpl::OnAskStart(std::string query,
                                     const RankedSuggestions* suggestions) {
  ask_proposal_listeners_.ForAllPtrs(
      [query, suggestions](AskProposalListener* listener) {
        fidl::Array<ProposalSummaryPtr> proposals;
        makeProposalSummaries(suggestions, &proposals);
        listener->OnAskStart(query, std::move(proposals));
      });
}

void SuggestionDebugImpl::OnSuggestionSelected(
    const SuggestionPrototype* selected_suggestion) {
  ask_proposal_listeners_.ForAllPtrs(
      [selected_suggestion](AskProposalListener* listener) {
        ProposalSummaryPtr summary = ProposalSummary::New();
        makeProposalSummary(selected_suggestion, &summary);
        listener->OnProposalSelected(std::move(summary));
      });
}

void SuggestionDebugImpl::OnInterrupt(
    const SuggestionPrototype* interrupt_suggestion) {
  interruption_proposal_listeners_.ForAllPtrs(
      [interrupt_suggestion](InterruptionProposalListener* listener) {
        ProposalSummaryPtr summary = ProposalSummary::New();
        makeProposalSummary(interrupt_suggestion, &summary);
        listener->OnInterrupt(std::move(summary));
      });
}

void SuggestionDebugImpl::OnNextUpdate(const RankedSuggestions* suggestions) {
  next_proposal_listeners_.ForAllPtrs(
      [this, suggestions](NextProposalListener* listener) {
        fidl::Array<ProposalSummaryPtr> proposals;
        makeProposalSummaries(suggestions, &proposals);
        listener->OnNextUpdate(std::move(proposals));
        cached_next_proposals_ = std::move(proposals);
      });
}

void SuggestionDebugImpl::WatchAskProposals(
    fidl::InterfaceHandle<AskProposalListener> listener) {
  auto listener_ptr = AskProposalListenerPtr::Create(std::move(listener));
  ask_proposal_listeners_.AddInterfacePtr(std::move(listener_ptr));
}

void SuggestionDebugImpl::WatchInterruptionProposals(
    fidl::InterfaceHandle<InterruptionProposalListener> listener) {
  auto listener_ptr =
      InterruptionProposalListenerPtr::Create(std::move(listener));
  interruption_proposal_listeners_.AddInterfacePtr(std::move(listener_ptr));
}

void SuggestionDebugImpl::WatchNextProposals(
    fidl::InterfaceHandle<NextProposalListener> listener) {
  auto listener_ptr = NextProposalListenerPtr::Create(std::move(listener));
  next_proposal_listeners_.AddInterfacePtr(std::move(listener_ptr));
  if (cached_next_proposals_) {
    listener_ptr->OnNextUpdate(std::move(cached_next_proposals_));
  }
}

}  // namespace maxwell
