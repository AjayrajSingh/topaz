// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "application/lib/app/application_context.h"
#include "apps/maxwell/src/acquirers/story_info/story_info.h"
#include "apps/modular/services/agent/agent.fidl.h"

#include "lib/mtl/tasks/message_loop.h"

namespace maxwell {

class StoryInfoApp {
 public:
  StoryInfoApp(app::ApplicationContext* app_context)
      : agent_binding_(&story_info_acquirer_) {
    app_context->outgoing_services()->AddService<modular::Agent>(
        [this](fidl::InterfaceRequest<modular::Agent> request) {
          FTL_DCHECK(!agent_binding_.is_bound());
          agent_binding_.Bind(std::move(request));
        });
  }

 private:
  StoryInfoAcquirer story_info_acquirer_;
  fidl::Binding<modular::Agent> agent_binding_;

  FTL_DISALLOW_COPY_AND_ASSIGN(StoryInfoApp);
};

}  // namespace maxwell

int main(int argc, const char** argv) {
  mtl::MessageLoop loop;
  auto app_context = app::ApplicationContext::CreateFromStartupInfo();
  maxwell::StoryInfoApp app(app_context.get());
  loop.Run();
  return 0;
}
