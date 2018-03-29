// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef TOPAZ_SHELL_ERMINE_USER_SHELL_APP_H_
#define TOPAZ_SHELL_ERMINE_USER_SHELL_APP_H_

#include <memory>
#include <vector>

#include <fuchsia/cpp/views_v1.h>

#include "lib/app/cpp/application_context.h"
#include "lib/fidl/cpp/binding_set.h"
#include "lib/fidl/cpp/interface_request.h"

namespace ermine_user_shell {
class ViewController;

class App : public views_v1::ViewProvider {
 public:
  App();
  ~App();

  // |views_v1::ViewProvider|
  void CreateView(fidl::InterfaceRequest<views_v1_token::ViewOwner> view_owner_request,
                  fidl::InterfaceRequest<component::ServiceProvider>
                      view_services) override;

  void DestroyController(ViewController* controller);

 private:
  App(const App&) = delete;
  App& operator=(const App&) = delete;

  std::unique_ptr<component::ApplicationContext> context_;
  fidl::BindingSet<views_v1::ViewProvider> bindings_;
  std::vector<std::unique_ptr<ViewController>> controllers_;
};

}  // namespace ermine_user_shell

#endif  // TOPAZ_SHELL_ERMINE_USER_SHELL_APP_H_
