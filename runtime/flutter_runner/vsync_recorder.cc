// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "vsync_recorder.h"

#include <mutex>

namespace flutter {

namespace {

std::mutex g_mutex;

// Since we don't have any presentation info until we call |Present| for the
// first time, assume a 60hz refresh rate in the meantime.
constexpr fxl::TimeDelta kDefaultPresentationInterval =
    fxl::TimeDelta::FromSecondsF(1.0 / 60.0);

}  // namespace

VsyncRecorder& VsyncRecorder::GetInstance() {
  static VsyncRecorder vsync_manager;
  return vsync_manager;
}

VsyncInfo VsyncRecorder::GetCurrentVsyncInfo() const {
  {
    std::unique_lock<std::mutex> lock(g_mutex);
    if (last_presentation_info_set_) {
      return {fxl::TimePoint::FromEpochDelta(fxl::TimeDelta::FromNanoseconds(
                  last_presentation_info_.presentation_time)),
              fxl::TimeDelta::FromNanoseconds(
                  last_presentation_info_.presentation_interval)};
    }
  }
  return {fxl::TimePoint::Now(), kDefaultPresentationInterval};
}

void VsyncRecorder::UpdateVsyncInfo(
    fuchsia::images::PresentationInfo presentation_info) {
  std::unique_lock<std::mutex> lock(g_mutex);
  if (last_presentation_info_set_ &&
      presentation_info.presentation_time >
          last_presentation_info_.presentation_time) {
    last_presentation_info_ = presentation_info;
  } else if (!last_presentation_info_set_) {
    last_presentation_info_ = presentation_info;
    last_presentation_info_set_ = true;
  }
}

}  // namespace flutter
