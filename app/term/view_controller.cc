// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "topaz/app/term/view_controller.h"

#include <unistd.h>

#include <lib/async/default.h>
#include <zircon/status.h>

#include "lib/fxl/logging.h"
#include "lib/fxl/strings/string_printf.h"
#include "lib/ui/input/cpp/formatting.h"
#include "third_party/skia/include/core/SkFont.h"
#include "third_party/skia/include/core/SkPaint.h"
#include "topaz/app/term/key_util.h"
#include "topaz/app/term/pty_server.h"
#include "topaz/app/term/term_model.h"

namespace term {
namespace {

constexpr zx::duration kBlinkInterval = zx::msec(500);
constexpr char kShell[] = "/boot/bin/sh";

}  // namespace

ViewController::ViewController(scenic::ViewContext view_context,
                               const TermParams& term_params,
                               DisconnectCallback disconnect_handler)
    : SkiaView(std::move(view_context), "Term"),
      disconnect_(std::move(disconnect_handler)),
      model_(TermModel::Size(24, 80), this),
      font_loader_(
          startup_context()
              ->ConnectToEnvironmentService<fuchsia::fonts::Provider>()),
      params_(term_params) {
  SetReleaseHandler([this](zx_status_t status) { disconnect_(this); });

  fuchsia::fonts::Request font_request;
  font_request.family = "RobotoMono";
  font_request.language = fidl::VectorPtr<fidl::StringPtr>::New(0);
  font_loader_.LoadFont(
      std::move(font_request), [this](sk_sp<SkTypeface> typeface) {
        FXL_CHECK(typeface);  // TODO(jpoichet): Fail gracefully.
        regular_typeface_ = std::move(typeface);
        ComputeMetrics();
        StartCommandIfNeeded();
      });
}

void ViewController::ComputeMetrics() {
  if (!regular_typeface_)
    return;

  SkFont fg_font;
  fg_font.setTypeface(regular_typeface_);
  fg_font.setSize(params_.font_size);
  // Figure out appropriate metrics.
  SkFontMetrics fm = {};
  fg_font.getMetrics(&fm);

  ascent_ = static_cast<int>(ceilf(-fm.fAscent));
  line_height_ = ascent_ + static_cast<int>(ceilf(fm.fDescent + fm.fLeading));
  FXL_DCHECK(line_height_ > 0);
  // To figure out the advance width, measure an X. Better hope the font
  // is monospace.
  advance_width_ = static_cast<int>(
      ceilf(fg_font.measureText("X", 1, kUTF8_SkTextEncoding)));
  FXL_DCHECK(advance_width_ > 0);
}

void ViewController::StartCommandIfNeeded() {
  if (!regular_typeface_)
    return;
  if (!has_logical_size())
    return;
  if (pty_.process())
    return;

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
    disconnect_(this);
  }

  Blink();
  InvalidateScene();
}

void ViewController::Blink() {
  if (focused_) {
    zx::duration delta = zx::clock::get_monotonic() - last_key_;
    if (delta > kBlinkInterval) {
      blink_on_ = !blink_on_;
      InvalidateScene();
    }
    blink_task_.Cancel();
    blink_task_.PostDelayed(async_get_default_dispatcher(), kBlinkInterval);
  }
}

void ViewController::OnSceneInvalidated(
    fuchsia::images::PresentationInfo presentation_info) {
  if (!regular_typeface_)
    return;

  SkCanvas* canvas = AcquireCanvas();
  if (canvas) {
    DrawContent(canvas);
    ReleaseAndSwapCanvas();
  }
}

void ViewController::OnPropertiesChanged(
    fuchsia::ui::viewsv1::ViewProperties old_properties) {
  ComputeMetrics();
  Resize();
}

void ViewController::Resize() {
  if (!has_logical_size() || !regular_typeface_)
    return;

  uint32_t columns = std::max(logical_size().width / advance_width_, 1.f);
  uint32_t rows = std::max(logical_size().height / line_height_, 1.f);
  TermModel::Size current = model_.GetSize();
  if (current.columns != columns || current.rows != rows) {
    model_.SetSize(TermModel::Size(rows, columns), false);
    pty_.SetWindowSize(columns, rows);
  }
  StartCommandIfNeeded();
  InvalidateScene();
}

void ViewController::DrawContent(SkCanvas* canvas) {
  canvas->clear(SK_ColorBLACK);

  SkPaint bg_paint;
  bg_paint.setStyle(SkPaint::kFill_Style);

  SkFont fg_font;
  fg_font.setTypeface(regular_typeface_);
  fg_font.setSize(params_.font_size);

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
          SkPaint fg_paint;
          fg_paint.setFlags(flags);
          fg_paint.setColor(SkColorSetRGB(ch.foreground_color.red,
                                          ch.foreground_color.green,
                                          ch.foreground_color.blue));

          canvas->drawSimpleText(&ch.code_point, sizeof(ch.code_point),
              SkTextEncoding::kUTF32, x, y + ascent_, fg_font, fg_paint);
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

void ViewController::ScheduleDraw(bool force) {
  if (!model_state_changes_.IsDirty() && !force && !force_next_draw_) {
    force_next_draw_ |= force;
    return;
  }

  force_next_draw_ = false;
  InvalidateScene();
}

void ViewController::OnResponse(const void* buf, size_t size) {
  SendData(buf, size);
}

void ViewController::OnSetKeypadMode(bool application_mode) {
  keypad_application_mode_ = application_mode;
}

bool ViewController::OnInputEvent(fuchsia::ui::input::InputEvent event) {
  bool handled = false;
  if (event.is_keyboard()) {
    const fuchsia::ui::input::KeyboardEvent& keyboard = event.keyboard();
    if (keyboard.phase == fuchsia::ui::input::KeyboardEventPhase::PRESSED ||
        keyboard.phase == fuchsia::ui::input::KeyboardEventPhase::REPEAT) {
      if (keyboard.code_point == '+' &&
          keyboard.modifiers & fuchsia::ui::input::kModifierAlt) {
        params_.font_size++;
        ComputeMetrics();
        Resize();
      } else if (keyboard.code_point == '-' &&
                 keyboard.modifiers & fuchsia::ui::input::kModifierAlt) {
        params_.font_size--;
        ComputeMetrics();
        Resize();
      }
      OnKeyPressed(std::move(event));
      handled = true;
    }
  } else if (event.is_focus()) {
    const fuchsia::ui::input::FocusEvent& focus = event.focus();
    focused_ = focus.focused;
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

void ViewController::OnKeyPressed(fuchsia::ui::input::InputEvent key_event) {
  last_key_ = zx::clock::get_monotonic();
  blink_on_ = true;

  std::string input_sequence =
      GetInputSequenceForKeyPressedEvent(key_event, keypad_application_mode_);
  if (input_sequence.empty())
    return;

  SendData(input_sequence.data(), input_sequence.size());
}

void ViewController::SendData(const void* bytes, size_t num_bytes) {
  pty_.Write(bytes, num_bytes);
}

void ViewController::OnDataReceived(const void* bytes, size_t num_bytes) {
  model_.ProcessInput(bytes, num_bytes, &model_state_changes_);
  ScheduleDraw(false);
}

void ViewController::OnCommandTerminated() { disconnect_(this); }

}  // namespace term
