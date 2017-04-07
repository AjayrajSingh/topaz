// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "apps/maxwell/src/acquirers/focus.h"

#include "application/lib/app/application_context.h"
#include "apps/maxwell/services/context/context_publisher.fidl.h"
#include "apps/modular/services/user/focus.fidl.h"

#include "lib/fidl/cpp/bindings/array.h"
#include "lib/fidl/cpp/bindings/binding.h"
#include "lib/mtl/tasks/message_loop.h"

#include "lib/ftl/logging.h"

using maxwell::acquirers::FocusAcquirer;

constexpr char FocusAcquirer::kLabel[];

namespace {

class FocusAcquirerApp : public modular::VisibleStoriesWatcher {
 public:
  FocusAcquirerApp()
      : app_ctx_(app::ApplicationContext::CreateFromStartupInfo()),
        visible_stories_watcher_(this) {
    publisher_ =
        app_ctx_->ConnectToEnvironmentService<maxwell::ContextPublisher>();

    auto visible_stories_provider_handle =
        app_ctx_
            ->ConnectToEnvironmentService<modular::VisibleStoriesProvider>();
    fidl::InterfaceHandle<modular::VisibleStoriesWatcher>
        visible_stories_watcher_handle;
    visible_stories_watcher_.Bind(&visible_stories_watcher_handle);
    visible_stories_provider_handle->Watch(
        std::move(visible_stories_watcher_handle));

    PublishFocusState();
  }

 private:
  // |VisibleStoriesWatcher|
  void OnVisibleStoriesChange(fidl::Array<fidl::String> ids) override {
    focused_story_ids_.clear();
    for (std::string str : ids) {
      focused_story_ids_.push_back(str);
    }

    PublishFocusState();
    FTL_VLOG(1) << "Focus changed -- there are now "
                << focused_story_ids_.size() << " active story ids.";
  }

  void PublishFocusState() {
    int modular_state = focused_story_ids_.size() ? 1 : 0;

    publisher_->Publish(FocusAcquirer::kLabel, std::to_string(modular_state));
    FTL_VLOG(1) << ": " << modular_state;
  }

  std::unique_ptr<app::ApplicationContext> app_ctx_;

  maxwell::ContextPublisherPtr publisher_;
  std::vector<std::string> focused_story_ids_;
  fidl::Binding<modular::VisibleStoriesWatcher> visible_stories_watcher_;
};

}  // namespace

int main(int argc, const char** argv) {
  mtl::MessageLoop loop;
  FocusAcquirerApp app;
  loop.Run();
  return 0;
}
