// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef TOPAZ_APP_TERM_VIEW_CONTROLLER_H_
#define TOPAZ_APP_TERM_VIEW_CONTROLLER_H_

#include <lib/async/cpp/task.h>
#include <lib/fit/function.h>

#include "examples/ui/lib/skia_font_loader.h"
#include "examples/ui/lib/skia_view.h"
#include "third_party/skia/include/core/SkCanvas.h"
#include "third_party/skia/include/core/SkTypeface.h"
#include "topaz/app/term/pty_server.h"
#include "topaz/app/term/term_model.h"
#include "topaz/app/term/term_params.h"

namespace term {

class ViewController : public scenic::SkiaView, public TermModel::Delegate {
 public:
  using DisconnectCallback = fit::function<void(ViewController*)>;

  ViewController(scenic::ViewContext view_context,
                 const TermParams& term_params,
                 DisconnectCallback disconnect_handler);
  ~ViewController() override = default;

  ViewController(const ViewController&) = delete;
  ViewController& operator=(const ViewController&) = delete;

 private:
  // |scenic::V1BaseView|
  void OnPropertiesChanged(
      fuchsia::ui::viewsv1::ViewProperties old_properties) override;
  void OnSceneInvalidated(
      fuchsia::images::PresentationInfo presentation_info) override;
  bool OnInputEvent(fuchsia::ui::input::InputEvent event) override;

  // |TermModel::Delegate|:
  void OnResponse(const void* buf, size_t size) override;
  void OnSetKeypadMode(bool application_mode) override;

  void ScheduleDraw(bool force);
  void DrawContent(SkCanvas* canvas);
  void OnKeyPressed(fuchsia::ui::input::InputEvent key_event);

  // stdin/stdout
  void OnDataReceived(const void* bytes, size_t num_bytes);
  void SendData(const void* bytes, size_t num_bytes);

  void ComputeMetrics();
  void StartCommandIfNeeded();
  void Blink();
  void Resize();
  void OnCommandTerminated();

  DisconnectCallback disconnect_;

  TermModel model_;
  // State changes to the model since last draw.
  TermModel::StateChanges model_state_changes_;

  // If we skip drawing despite being forced to, we should force the next draw.
  bool force_next_draw_;

  mozart::SkiaFontLoader font_loader_;
  sk_sp<SkTypeface> regular_typeface_;

  int ascent_;
  int line_height_;
  int advance_width_;
  // Keyboard state.
  bool keypad_application_mode_;

  async::TaskClosureMethod<ViewController, &ViewController::Blink> blink_task_{
      this};
  zx::time last_key_;
  bool blink_on_ = true;
  bool focused_ = false;

  TermParams params_;
  PTYServer pty_;
};

}  // namespace term

#endif  // TOPAZ_APP_TERM_VIEW_CONTROLLER_H_
