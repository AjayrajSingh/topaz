// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "topaz/runtime/flutter_runner/semantics_bridge.h"

namespace flutter {

// Helper function to convert SkRect, Flutter semantics node bounding box
// format to fuchsia::ui::gfx::BoundingBox, the Fidl equivalent.
fuchsia::ui::gfx::BoundingBox WrapBoundingBox(SkRect& rect) {
  fuchsia::ui::gfx::BoundingBox box;
  box.min.x = rect.fLeft;
  box.min.y = rect.fTop;
  box.min.z = 0;
  box.max.x = rect.fRight;
  box.max.y = rect.fBottom;
  box.max.z = 0;
  return box;
}

// Helper function to convert SkMatrix44, Flutter semantics node transform
// format to fuchsia::ui::gfx::mat4, the Fidl equivalent.
fuchsia::ui::gfx::mat4 WrapSkMatrix(SkMatrix44& args) {
  fuchsia::ui::gfx::mat4 value;
  FXL_DCHECK(value.matrix.count() == 16);
  float* m = value.matrix.mutable_data();
  args.asColMajorf(m);
  return value;
}

// Helper function to convert Flutter SemanticsNode to fuchsia Fidl
// accessibility node format.
fuchsia::accessibility::Node SerializeNode(blink::SemanticsNode node,
                                           float scale) {
  fuchsia::accessibility::Node s_node = fuchsia::accessibility::Node();
  s_node.node_id = node.id;
  s_node.children_hit_test_order =
      fidl::VectorPtr<int32_t>(node.childrenInHitTestOrder);
  s_node.children_traversal_order =
      fidl::VectorPtr<int32_t>(node.childrenInTraversalOrder);

  s_node.data = fuchsia::accessibility::Data();
  s_node.data.role = fuchsia::accessibility::Role::NONE;
  s_node.data.label = node.label;

  s_node.data.location = WrapBoundingBox(node.rect);
  SkMatrix44 inverse(SkMatrix44::kUninitialized_Constructor);
  node.transform.invert(&inverse);

  if (s_node.node_id == 0) {
    SkMatrix44 scaling(SkMatrix44::kIdentity_Constructor);
    scaling.setScale(scale, scale, 1);
    inverse = inverse * scaling;
  }
  s_node.data.transform = WrapSkMatrix(inverse);
  return s_node;
}

SemanticsBridge::SemanticsBridge(shell::PlatformView* platform_view,
                                 blink::LogicalMetrics* metrics)
    : binding_(this), platform_view_(platform_view), metrics_(metrics) {}

void SemanticsBridge::SetupConnection(
    uint32_t view_id,
    fidl::InterfaceHandle<fuchsia::accessibility::SemanticsRoot> handle) {
  view_id_ = view_id;
  root_.set_error_handler([this]() {
    FXL_LOG(INFO) << "A11y bridge disconnected from a11y manager";
    platform_view_->SetSemanticsEnabled(false);
  });
  root_ = handle.Bind();
  root_->RegisterSemanticsProvider(view_id_, binding_.NewBinding());
  platform_view_->SetSemanticsEnabled(true);
}

void SemanticsBridge::UpdateSemantics(
    const blink::SemanticsNodeUpdates& update) {
  fidl::VectorPtr<int32_t> delete_nodes;
  fidl::VectorPtr<fuchsia::accessibility::Node> update_nodes;
  for (auto it = update.begin(); it != update.end(); ++it) {
    blink::SemanticsNode node = it->second;
    // We delete nodes that are hidden from the screen.
    if (node.HasFlag(blink::SemanticsFlags::kIsHidden)) {
      delete_nodes.push_back(node.id);
    } else {
      update_nodes.push_back(SerializeNode(node, (float)metrics_->scale));
    }
  }
  if (!delete_nodes.get().empty()) {
    root_->DeleteSemanticNodes(view_id_, std::move(delete_nodes));
  }
  if (!update_nodes.get().empty()) {
    root_->UpdateSemanticNodes(view_id_, std::move(update_nodes));
  }
  root_->Commit(view_id_);
}

void SemanticsBridge::PerformAccessibilityAction(
    int32_t node_id, fuchsia::accessibility::Action action) {
  std::vector<uint8_t> args = {};
  switch (action) {
    case fuchsia::accessibility::Action::GAIN_ACCESSIBILITY_FOCUS:
      platform_view_->DispatchSemanticsAction(
          node_id, blink::SemanticsAction::kDidGainAccessibilityFocus, args);
      break;
    case fuchsia::accessibility::Action::LOSE_ACCESSIBILITY_FOCUS:
      platform_view_->DispatchSemanticsAction(
          node_id, blink::SemanticsAction::kDidLoseAccessibilityFocus, args);
      break;
    case fuchsia::accessibility::Action::TAP:
      platform_view_->DispatchSemanticsAction(
          node_id, blink::SemanticsAction::kTap, args);
      break;
    default:
      FXL_LOG(ERROR) << "Accessibility action not supported";
  }
}

}  // namespace flutter