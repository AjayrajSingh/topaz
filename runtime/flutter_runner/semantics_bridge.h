// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef TOPAZ_RUNTIME_FLUTTER_RUNNER_SEMANTICS_BRIDGE_H_
#define TOPAZ_RUNTIME_FLUTTER_RUNNER_SEMANTICS_BRIDGE_H_

#include <map>
#include <unordered_set>

#include <fuchsia/accessibility/cpp/fidl.h>
#include <fuchsia/sys/cpp/fidl.h>
#include <fuchsia/ui/input/cpp/fidl.h>

#include "flutter/lib/ui/semantics/semantics_node.h"
#include "flutter/lib/ui/window/viewport_metrics.h"
#include "lib/fidl/cpp/binding_set.h"
#include "lib/fxl/logging.h"
#include "lib/fxl/macros.h"

#include "flutter/shell/common/platform_view.h"

namespace flutter {

// Connects the Flutter PlatformView to the Fuchsia accessibility manager and
// provides a way to push semantic tree updates to the manager. Also provides
// a SemanticsProvider implementation for the manager to call SemanticActions
// on nodes on the screen.
class SemanticsBridge final : public fuchsia::accessibility::SemanticsProvider {
 public:
  SemanticsBridge(shell::PlatformView* platform_view,
                  blink::LogicalMetrics* metrics);
  ~SemanticsBridge() = default;

  // Sets up a connection to the accessibility manager with the view id
  // passed in from the PlatformView. In order for Flutter to start sending
  // semantics updates, we must call SetSemanticsEnabled(true) in the
  // associated |platform_view_|. For now, we choose to enable it upon
  // registering with the accessibility manager.
  // TODO(SCN-860): Find a better place to enable and disable semantics.
  void SetupConnection(
      uint32_t view_id,
      fidl::InterfaceHandle<fuchsia::accessibility::SemanticsRoot> handle);

  // Converts the updated semantics nodes in |update| to Fidl accessibility
  // node format to send to the accessibility manager. The update is split into
  // three manager calls, one to send updated nodes, one to send deleted node
  // ids, and one to finalize the update.
  void UpdateSemantics(const blink::SemanticsNodeUpdates& update);

 private:
  // |fuchsia::accessibility::SemanticsProvider|
  void PerformAccessibilityAction(
      int32_t node_id, fuchsia::accessibility::Action action) override;

  fidl::Binding<fuchsia::accessibility::SemanticsProvider> binding_;
  fuchsia::accessibility::SemanticsRootPtr root_;

  // The associated Scenic view id for the associated PlatformView. This id
  // must registered with the accessibility manager, and sent with every
  // update, delete, and commit.
  // TODO(SCN-847): Update the view_id system to initialize connections with
  // event pair kernel objects.
  uint32_t view_id_;
  // We keep a reference to the associated PlatformView to call
  // SemanticsActions.
  shell::PlatformView* platform_view_;
  // Metrics is needed to scale Scenic view space into local
  // Flutter space when performing hit-tests. This is converted into
  // a transform matrix that is applied to this semantic tree's root node
  // transform matrix when sent to the manager.
  blink::LogicalMetrics* metrics_;

  FXL_DISALLOW_COPY_AND_ASSIGN(SemanticsBridge);
};

}  // namespace flutter

#endif  // TOPAZ_RUNTIME_FLUTTER_RUNNER_SEMANTICS_BRIDGE_H_
