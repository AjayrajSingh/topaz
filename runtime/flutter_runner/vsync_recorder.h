// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef TOPAZ_RUNTIME_FLUTTER_RUNNER_VSYNC_RECORDER_H_
#define TOPAZ_RUNTIME_FLUTTER_RUNNER_VSYNC_RECORDER_H_

#include "flutter/fml/time/time_delta.h"
#include "flutter/fml/time/time_point.h"
#include "lib/fxl/macros.h"
#include "lib/ui/scenic/cpp/session.h"

namespace flutter {

struct VsyncInfo {
  fml::TimePoint presentation_time;
  fml::TimeDelta presentation_interval;
};

class VsyncRecorder {
 public:
  static VsyncRecorder& GetInstance();

  // Retrieve the most recent |PresentationInfo| provided to us by scenic.
  // This function is safe to call from any thread.
  VsyncInfo GetCurrentVsyncInfo() const;

  // Update the current Vsync info to |presentation_info|.  This is expected
  // to be called in |scenic::Sesssion::Present| callbacks with the
  // presentation info provided by scenic.  Only the most recent vsync
  // information will be saved (in order to handle edge cases involving
  // multiple scenic sessions in the same process).  This function is safe to
  // call from any thread.
  void UpdateVsyncInfo(fuchsia::images::PresentationInfo presentation_info);

 private:
  VsyncRecorder() = default;

  fuchsia::images::PresentationInfo last_presentation_info_ = {};
  bool last_presentation_info_set_ = false;

  FXL_DISALLOW_COPY_ASSIGN_AND_MOVE(VsyncRecorder);
};

}  // namespace flutter

#endif  // TOPAZ_RUNTIME_FLUTTER_RUNNER_VSYNC_RECORDER_H_
