// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef LIB_UI_SKIA_TYPE_CONVERTERS_H_
#define LIB_UI_SKIA_TYPE_CONVERTERS_H_

#include <fuchsia/math/cpp/fidl.h>

#include "lib/fsl/types/type_converters.h"
#include "third_party/skia/include/core/SkMatrix.h"
#include "third_party/skia/include/core/SkMatrix44.h"
#include "third_party/skia/include/core/SkPoint.h"
#include "third_party/skia/include/core/SkRRect.h"
#include "third_party/skia/include/core/SkRect.h"

// The TypeConverter template is defined in the fxl namespace.
namespace fidl {

template <>
struct TypeConverter<SkIPoint, fuchsia::math::Point> {
  static SkIPoint Convert(const fuchsia::math::Point& input);
};
template <>
struct TypeConverter<fuchsia::math::Point, SkIPoint> {
  static fuchsia::math::Point Convert(const SkIPoint& input);
};

template <>
struct TypeConverter<SkPoint, fuchsia::math::PointF> {
  static SkPoint Convert(const fuchsia::math::PointF& input);
};
template <>
struct TypeConverter<fuchsia::math::PointF, SkPoint> {
  static fuchsia::math::PointF Convert(const SkPoint& input);
};

template <>
struct TypeConverter<SkIRect, fuchsia::math::Rect> {
  static SkIRect Convert(const fuchsia::math::Rect& input);
};
template <>
struct TypeConverter<fuchsia::math::Rect, SkIRect> {
  static fuchsia::math::Rect Convert(const SkIRect& input);
};

template <>
struct TypeConverter<SkRect, fuchsia::math::RectF> {
  static SkRect Convert(const fuchsia::math::RectF& input);
};
template <>
struct TypeConverter<fuchsia::math::RectF, SkRect> {
  static fuchsia::math::RectF Convert(const SkRect& input);
};

template <>
struct TypeConverter<SkRRect, fuchsia::math::RRectF> {
  static SkRRect Convert(const fuchsia::math::RRectF& input);
};
template <>
struct TypeConverter<fuchsia::math::RRectF, SkRRect> {
  static fuchsia::math::RRectF Convert(const SkRRect& input);
};

// Note: This transformation is lossy since Transform is 4x4 whereas
// SkMatrix is only 3x3 so we drop the 3rd row and column.
template <>
struct TypeConverter<SkMatrix, fuchsia::math::Transform> {
  static SkMatrix Convert(const fuchsia::math::Transform& input);
};
template <>
struct TypeConverter<fuchsia::math::Transform, SkMatrix> {
  static fuchsia::math::Transform Convert(const SkMatrix& input);
};

// Note: This transformation is lossless.
template <>
struct TypeConverter<SkMatrix44, fuchsia::math::Transform> {
  static SkMatrix44 Convert(const fuchsia::math::Transform& input);
};
template <>
struct TypeConverter<fuchsia::math::Transform, SkMatrix44> {
  static fuchsia::math::Transform Convert(const SkMatrix44& input);
};

}  // namespace fidl

#endif  // LIB_UI_SKIA_TYPE_CONVERTERS_H_
