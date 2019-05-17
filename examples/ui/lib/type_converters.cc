// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "examples/ui/lib/type_converters.h"

namespace fidl {

SkIPoint TypeConverter<SkIPoint, fuchsia::math::Point>::Convert(
    const fuchsia::math::Point& input) {
  return SkIPoint::Make(input.x, input.y);
}

fuchsia::math::Point TypeConverter<fuchsia::math::Point, SkIPoint>::Convert(
    const SkIPoint& input) {
  fuchsia::math::Point output;
  output.x = input.x();
  output.y = input.y();
  return output;
}

SkPoint TypeConverter<SkPoint, fuchsia::math::PointF>::Convert(
    const fuchsia::math::PointF& input) {
  return SkPoint::Make(input.x, input.y);
}

fuchsia::math::PointF TypeConverter<fuchsia::math::PointF, SkPoint>::Convert(
    const SkPoint& input) {
  fuchsia::math::PointF output;
  output.x = input.x();
  output.y = input.y();
  return output;
}

SkIRect TypeConverter<SkIRect, fuchsia::math::Rect>::Convert(
    const fuchsia::math::Rect& input) {
  return SkIRect::MakeXYWH(input.x, input.y, input.width, input.height);
}

fuchsia::math::Rect TypeConverter<fuchsia::math::Rect, SkIRect>::Convert(
    const SkIRect& input) {
  fuchsia::math::Rect output;
  output.x = input.x();
  output.y = input.y();
  output.width = input.width();
  output.height = input.height();
  return output;
}

SkRect TypeConverter<SkRect, fuchsia::math::RectF>::Convert(
    const fuchsia::math::RectF& input) {
  return SkRect::MakeXYWH(input.x, input.y, input.width, input.height);
}

fuchsia::math::RectF TypeConverter<fuchsia::math::RectF, SkRect>::Convert(
    const SkRect& input) {
  fuchsia::math::RectF output;
  output.x = input.x();
  output.y = input.y();
  output.width = input.width();
  output.height = input.height();
  return output;
}

SkRRect TypeConverter<SkRRect, fuchsia::math::RRectF>::Convert(
    const fuchsia::math::RRectF& input) {
  SkVector radii[4] = {
      {input.top_left_radius_x, input.top_left_radius_y},
      {input.top_right_radius_x, input.top_right_radius_y},
      {input.bottom_left_radius_x, input.bottom_left_radius_y},
      {input.bottom_right_radius_x, input.bottom_right_radius_y}};
  SkRRect output;
  output.setRectRadii(
      SkRect::MakeXYWH(input.x, input.y, input.width, input.height), radii);
  return output;
}

fuchsia::math::RRectF TypeConverter<fuchsia::math::RRectF, SkRRect>::Convert(
    const SkRRect& input) {
  fuchsia::math::RRectF output;
  output.x = input.rect().x();
  output.y = input.rect().y();
  output.width = input.rect().width();
  output.height = input.rect().height();
  output.top_left_radius_x = input.radii(SkRRect::kUpperLeft_Corner).x();
  output.top_left_radius_y = input.radii(SkRRect::kUpperLeft_Corner).y();
  output.top_right_radius_x = input.radii(SkRRect::kUpperRight_Corner).x();
  output.top_right_radius_y = input.radii(SkRRect::kUpperRight_Corner).y();
  output.bottom_left_radius_x = input.radii(SkRRect::kLowerLeft_Corner).x();
  output.bottom_left_radius_y = input.radii(SkRRect::kLowerLeft_Corner).y();
  output.bottom_right_radius_x = input.radii(SkRRect::kLowerRight_Corner).x();
  output.bottom_right_radius_y = input.radii(SkRRect::kLowerRight_Corner).y();
  return output;
}

SkMatrix TypeConverter<SkMatrix, fuchsia::math::Transform>::Convert(
    const fuchsia::math::Transform& input) {
  // Drop 3D components during conversion from 4x4 to 3x3.
  const auto& m = input.matrix;
  SkMatrix output;
  output.setAll(m[0], m[1], m[3],
                m[4], m[5], m[7],
                m[12], m[13], m[15]);
  return output;
}

fuchsia::math::Transform TypeConverter<fuchsia::math::Transform, SkMatrix>::Convert(
    const SkMatrix& input) {
  // Expand 3x3 to 4x4.
  fuchsia::math::Transform output;
  float* m = output.matrix.data();
  m[0] = input[0];
  m[1] = input[1];
  m[2] = 0.f;
  m[3] = input[2];
  m[4] = input[3];
  m[5] = input[4];
  m[6] = 0.f;
  m[7] = input[5];
  m[8] = 0.f;
  m[9] = 0.f;
  m[10] = 1.f;
  m[11] = 0.f;
  m[12] = input[6];
  m[13] = input[7];
  m[14] = 0.f;
  m[15] = input[8];
  return output;
}

SkMatrix44 TypeConverter<SkMatrix44, fuchsia::math::Transform>::Convert(
    const fuchsia::math::Transform& input) {
  SkMatrix44 output(SkMatrix44::kUninitialized_Constructor);
  output.setRowMajorf(input.matrix.data());
  return output;
}

fuchsia::math::Transform TypeConverter<fuchsia::math::Transform, SkMatrix44>::Convert(
    const SkMatrix44& input) {
  fuchsia::math::Transform output;
  input.asRowMajorf(output.matrix.data());
  return output;
}

}  // namespace fidl
