// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef TOPAZ_SHELL_ECHIDNA_USER_SHELL_APP_H_
#define TOPAZ_SHELL_ECHIDNA_USER_SHELL_APP_H_

#include "lib/app/cpp/application_context.h"
#include "lib/fidl/cpp/bindings/binding_set.h"
#include "lib/fidl/cpp/bindings/interface_request.h"
#include "lib/ui/views/fidl/view_provider.fidl.h"

#include <memory>
#include <vector>

namespace echidna_user_shell {
class ViewController;

class App : public mozart::ViewProvider {
 public:
  App();
  ~App();

  // |mozart::ViewProvider|
  void CreateView(
      f1dl::InterfaceRequest<mozart::ViewOwner> view_owner_request,
      f1dl::InterfaceRequest<app::ServiceProvider> view_services) override;

  void DestroyController(ViewController* controller);

 private:
  App(const App&) = delete;
  App& operator=(const App&) = delete;

  std::unique_ptr<app::ApplicationContext> context_;
  f1dl::BindingSet<mozart::ViewProvider> bindings_;
  std::vector<std::unique_ptr<ViewController>> controllers_;
};

}  // namespace echidna_user_shell

#endif  // TOPAZ_SHELL_ECHIDNA_USER_SHELL_APP_H_
