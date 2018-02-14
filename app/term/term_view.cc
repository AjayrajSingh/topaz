// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "topaz/app/term/term_view.h"

#include <async/default.h>
#include <async/loop.h>
#include <unistd.h>
#include <zircon/status.h>

#include "lib/fonts/fidl/font_provider.fidl.h"
#include "lib/fxl/logging.h"
#include "lib/fxl/strings/string_printf.h"
#include "lib/ui/input/cpp/formatting.h"
#include "third_party/skia/include/core/SkPaint.h"
#include "topaz/app/term/key_util.h"
#include "topaz/app/term/pty_server.h"
#include "topaz/app/term/term_model.h"

namespace term {
namespace {

constexpr zx::duration kBlinkInterval = zx::msec(500);
constexpr char kShell[] = "/boot/bin/sh";

}  // namespace

TermView::TermView(mozart::ViewManagerPtr view_manager,
                   fidl::InterfaceRequest<mozart::ViewOwner> view_owner_request,
                   app::ApplicationContext* context,
                   const TermParams& term_params)
    : SkiaView(std::move(view_manager), std::move(view_owner_request), "Term"),
      model_(TermModel::Size(24, 80), this),
      context_(context),
      font_loader_(
          context_->ConnectToEnvironmentService<fonts::FontProvider>()),
      blink_task_(async_get_default()),
      params_(term_params) {
  FXL_DCHECK(context_);

  auto font_request = fonts::FontRequest::New();
  font_request->family = "RobotoMono";
  font_loader_.LoadFont(
      std::move(font_request), [this](sk_sp<SkTypeface> typeface) {
        FXL_CHECK(typeface);  // TODO(jpoichet): Fail gracefully.
        regular_typeface_ = std::move(typeface);
        ComputeMetrics();
        StartCommand();
      });
}

TermView::~TermView() {}

void TermView::ComputeMetrics() {
  if (!regular_typeface_)
    return;

  // TODO(vtl): This duplicates some code.
  SkPaint fg_paint;
  fg_paint.setTypeface(regular_typeface_);
  fg_paint.setTextSize(params_.font_size);
  // Figure out appropriate metrics.
  SkPaint::FontMetrics fm = {};
  fg_paint.getFontMetrics(&fm);
  ascent_ = static_cast<int>(ceilf(-fm.fAscent));
  line_height_ = ascent_ + static_cast<int>(ceilf(fm.fDescent + fm.fLeading));
  FXL_DCHECK(line_height_ > 0);
  // To figure out the advance width, measure an X. Better hope the font
  // is monospace.
  advance_width_ = static_cast<int>(ceilf(fg_paint.measureText("X", 1)));
  FXL_DCHECK(advance_width_ > 0);
}

void TermView::StartCommand() {
  std::vector<std::string> argv = params_.command;
  if (argv.empty())
    argv = {kShell};

  zx_status_t status = pty_.Run(argv,
                                [this](const void* bytes, size_t num_bytes) {
                                  OnDataReceived(bytes, num_bytes);
                                },
                                [this] { OnCommandTerminated(); });
  if (status != ZX_OK) {
    FXL_LOG(ERROR) << "Error starting command: " << status << " ("
                   << zx_status_get_string(status) << ")";
    exit(1);
  }

  Blink();
  InvalidateScene();
}

void TermView::Blink() {
  if (focused_) {
    zx::duration delta = zx::clock::get(ZX_CLOCK_MONOTONIC) - last_key_;
    if (delta > kBlinkInterval) {
      blink_on_ = !blink_on_;
      InvalidateScene();
    }
    if (blink_task_.is_pending())
      blink_task_.Cancel();
    blink_task_.set_deadline(zx::deadline_after(kBlinkInterval).get());
    blink_task_.set_handler([this](async_t* async, zx_status_t status) {
      if (status != ZX_OK)
        return ASYNC_TASK_FINISHED;
      Blink();
      return ASYNC_TASK_FINISHED;
    });
    blink_task_.Post();
  }
}

void TermView::OnSceneInvalidated(
    ui_mozart::PresentationInfoPtr presentation_info) {
  if (!regular_typeface_)
    return;

  SkCanvas* canvas = AcquireCanvas();
  if (canvas) {
    DrawContent(canvas);
    ReleaseAndSwapCanvas();
  }
}

void TermView::OnPropertiesChanged(mozart::ViewPropertiesPtr old_properties) {
  ComputeMetrics();
  Resize();
}

void TermView::Resize() {
  if (!has_logical_size() || !regular_typeface_)
    return;

  uint32_t columns = std::max(logical_size().width / advance_width_, 1.f);
  uint32_t rows = std::max(logical_size().height / line_height_, 1.f);
  TermModel::Size current = model_.GetSize();
  if (current.columns != columns || current.rows != rows) {
    model_.SetSize(TermModel::Size(rows, columns), false);
    pty_.SetWindowSize(columns, rows);
  }
  InvalidateScene();
}

void TermView::DrawContent(SkCanvas* canvas) {
  canvas->clear(SK_ColorBLACK);

  SkPaint bg_paint;
  bg_paint.setStyle(SkPaint::kFill_Style);

  SkPaint fg_paint;
  fg_paint.setTypeface(regular_typeface_);
  fg_paint.setTextSize(params_.font_size);
  fg_paint.setTextEncoding(SkPaint::kUTF32_TextEncoding);

  TermModel::Size size = model_.GetSize();
  int y = 0;
  for (unsigned i = 0; i < size.rows; i++, y += line_height_) {
    int x = 0;
    for (unsigned j = 0; j < size.columns; j++, x += advance_width_) {
      TermModel::CharacterInfo ch =
          model_.GetCharacterInfoAt(TermModel::Position(i, j));

      // Paint the background.
      bg_paint.setColor(SkColorSetRGB(ch.background_color.red,
                                      ch.background_color.green,
                                      ch.background_color.blue));
      canvas->drawRect(SkRect::MakeXYWH(x, y, advance_width_, line_height_),
                       bg_paint);

      // Paint the foreground.
      if (ch.code_point) {
        if (!(ch.attributes & TermModel::kAttributesBlink) || blink_on_) {
          uint32_t flags = SkPaint::kAntiAlias_Flag;
          // TODO(jpoichet): Use real bold font
          if ((ch.attributes & TermModel::kAttributesBold))
            flags |= SkPaint::kFakeBoldText_Flag;
          // TODO(jpoichet): Account for TermModel::kAttributesUnderline
          // without using the deprecated flag SkPaint::kUnderlineText_Flag
          fg_paint.setFlags(flags);
          fg_paint.setColor(SkColorSetRGB(ch.foreground_color.red,
                                          ch.foreground_color.green,
                                          ch.foreground_color.blue));

          canvas->drawText(&ch.code_point, sizeof(ch.code_point), x,
                           y + ascent_, fg_paint);
        }
      }
    }
  }

  if (model_.GetCursorVisibility() && blink_on_) {
    // Draw the cursor.
    TermModel::Position cursor_pos = model_.GetCursorPosition();
    // TODO(jpoichet): Vary how we draw the cursor, depending on if we're
    // focused and/or active.
    SkPaint caret_paint;
    caret_paint.setStyle(SkPaint::kFill_Style);
    if (!focused_) {
      caret_paint.setStyle(SkPaint::kStroke_Style);
      caret_paint.setStrokeWidth(2);
    }

    caret_paint.setARGB(64, 255, 255, 255);
    canvas->drawRect(SkRect::MakeXYWH(cursor_pos.column * advance_width_,
                                      cursor_pos.row * line_height_,
                                      advance_width_, line_height_),
                     caret_paint);
  }
}

void TermView::ScheduleDraw(bool force) {
  if (!properties() ||
      (!model_state_changes_.IsDirty() && !force && !force_next_draw_)) {
    force_next_draw_ |= force;
    return;
  }

  force_next_draw_ = false;
  InvalidateScene();
}

void TermView::OnResponse(const void* buf, size_t size) {
  SendData(buf, size);
}

void TermView::OnSetKeypadMode(bool application_mode) {
  keypad_application_mode_ = application_mode;
}

bool TermView::OnInputEvent(mozart::InputEventPtr event) {
  bool handled = false;
  if (event->is_keyboard()) {
    const mozart::KeyboardEventPtr& keyboard = event->get_keyboard();
    if (keyboard->phase == mozart::KeyboardEvent::Phase::PRESSED ||
        keyboard->phase == mozart::KeyboardEvent::Phase::REPEAT) {
      if (keyboard->code_point == '+' &&
          keyboard->modifiers & mozart::kModifierAlt) {
        params_.font_size++;
        ComputeMetrics();
        Resize();
      } else if (keyboard->code_point == '-' &&
                 keyboard->modifiers & mozart::kModifierAlt) {
        params_.font_size--;
        ComputeMetrics();
        Resize();
      }
      OnKeyPressed(std::move(event));
      handled = true;
    }
  } else if (event->is_focus()) {
    const mozart::FocusEventPtr& focus = event->get_focus();
    focused_ = focus->focused;
    blink_on_ = true;
    if (focused_) {
      Blink();
    } else {
      InvalidateScene();
    }
    handled = true;
  }
  return handled;
}

void TermView::OnKeyPressed(mozart::InputEventPtr key_event) {
  last_key_ = zx::clock::get(ZX_CLOCK_MONOTONIC);
  blink_on_ = true;

  std::string input_sequence =
      GetInputSequenceForKeyPressedEvent(*key_event, keypad_application_mode_);
  if (input_sequence.empty())
    return;

  SendData(input_sequence.data(), input_sequence.size());
}

void TermView::SendData(const void* bytes, size_t num_bytes) {
  pty_.Write(bytes, num_bytes);
}

void TermView::OnDataReceived(const void* bytes, size_t num_bytes) {
  model_.ProcessInput(bytes, num_bytes, &model_state_changes_);
  ScheduleDraw(false);
}

void TermView::OnCommandTerminated() {
  FXL_LOG(INFO) << "PTY terminated.";
  async_loop_quit(async_get_default());
}

}  // namespace term
