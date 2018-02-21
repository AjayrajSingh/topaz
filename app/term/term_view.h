// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef TOPAZ_APP_TERM_TERM_VIEW_H_
#define TOPAZ_APP_TERM_TERM_VIEW_H_

#include <async/cpp/auto_task.h>

#include "examples/ui/lib/skia_font_loader.h"
#include "examples/ui/lib/skia_view.h"
#include "lib/app/cpp/application_context.h"
#include "lib/app/fidl/application_environment.fidl.h"
#include "lib/fxl/macros.h"
#include "lib/fxl/memory/ref_ptr.h"
#include "lib/fxl/memory/weak_ptr.h"
#include "lib/fxl/tasks/task_runner.h"
#include "lib/fxl/time/time_point.h"
#include "third_party/skia/include/core/SkCanvas.h"
#include "third_party/skia/include/core/SkTypeface.h"
#include "topaz/app/term/command.h"
#include "topaz/app/term/history.h"
#include "topaz/app/term/shell_controller.h"
#include "topaz/app/term/term_model.h"
#include "topaz/app/term/term_params.h"

namespace term {
class MotermView : public mozart::SkiaView, public MotermModel::Delegate {
 public:
  MotermView(mozart::ViewManagerPtr view_manager,
             fidl::InterfaceRequest<mozart::ViewOwner> view_owner_request,
             app::ApplicationContext* context,
             History* history,
             const MotermParams& term_params);
  ~MotermView() override;

 private:
  // |BaseView|:
  void OnPropertiesChanged(mozart::ViewPropertiesPtr old_properties) override;
  void OnSceneInvalidated(
      scenic::PresentationInfoPtr presentation_info) override;
  bool OnInputEvent(mozart::InputEventPtr event) override;

  // |MotermModel::Delegate|:
  void OnResponse(const void* buf, size_t size) override;
  void OnSetKeypadMode(bool application_mode) override;

  void ScheduleDraw(bool force);
  void DrawContent(SkCanvas* canvas);
  void OnKeyPressed(mozart::InputEventPtr key_event);

  // stdin/stdout
  void OnDataReceived(const void* bytes, size_t num_bytes);
  void SendData(const void* bytes, size_t num_bytes);

  void ComputeMetrics();
  void StartCommand();
  void Blink();
  void Resize();
  void OnCommandTerminated();

  // TODO(vtl): Consider the structure of this app. Do we really want the "view"
  // owning the model?
  // The terminal model.
  MotermModel model_;
  // State changes to the model since last draw.
  MotermModel::StateChanges model_state_changes_;
  std::unique_ptr<ShellController> shell_controller_;

  // If we skip drawing despite being forced to, we should force the next draw.
  bool force_next_draw_;

  app::ApplicationContext* context_;
  mozart::SkiaFontLoader font_loader_;
  sk_sp<SkTypeface> regular_typeface_;

  int ascent_;
  int line_height_;
  int advance_width_;
  // Keyboard state.
  bool keypad_application_mode_;

  async::AutoTask blink_task_;
  zx::time last_key_;
  bool blink_on_ = true;
  bool focused_ = false;

  History* history_;

  MotermParams params_;
  std::unique_ptr<Command> command_;

  fxl::WeakPtrFactory<MotermView> weak_ptr_factory_;

  FXL_DISALLOW_COPY_AND_ASSIGN(MotermView);
};
}  // namespace term

#endif  // TOPAZ_APP_TERM_TERM_VIEW_H_
