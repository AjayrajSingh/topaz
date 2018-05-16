// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef LIB_UI_SKIA_TYPE_CONVERTERS_H_
#define LIB_UI_SKIA_TYPE_CONVERTERS_H_

#include <geometry/cpp/fidl.h>

#include "lib/fsl/types/type_converters.h"
#include "third_party/skia/include/core/SkMatrix.h"
#include "third_party/skia/include/core/SkMatrix44.h"
#include "third_party/skia/include/core/SkPoint.h"
#include "third_party/skia/include/core/SkRRect.h"
#include "third_party/skia/include/core/SkRect.h"

// The TypeConverter template is defined in the fxl namespace.
namespace fxl {

template <>
struct TypeConverter<SkIPoint, geometry::Point> {
  static SkIPoint Convert(const geometry::Point& input);
};
template <>
struct TypeConverter<geometry::Point, SkIPoint> {
  static geometry::Point Convert(const SkIPoint& input);
};

template <>
struct TypeConverter<SkPoint, geometry::PointF> {
  static SkPoint Convert(const geometry::PointF& input);
};
template <>
struct TypeConverter<geometry::PointF, SkPoint> {
  static geometry::PointF Convert(const SkPoint& input);
};

template <>
struct TypeConverter<SkIRect, geometry::Rect> {
  static SkIRect Convert(const geometry::Rect& input);
};
template <>
struct TypeConverter<geometry::Rect, SkIRect> {
  static geometry::Rect Convert(const SkIRect& input);
};

template <>
struct TypeConverter<SkRect, geometry::RectF> {
  static SkRect Convert(const geometry::RectF& input);
};
template <>
struct TypeConverter<geometry::RectF, SkRect> {
  static geometry::RectF Convert(const SkRect& input);
};

template <>
struct TypeConverter<SkRRect, geometry::RRectF> {
  static SkRRect Convert(const geometry::RRectF& input);
};
template <>
struct TypeConverter<geometry::RRectF, SkRRect> {
  static geometry::RRectF Convert(const SkRRect& input);
};

// Note: This transformation is lossy since Transform is 4x4 whereas
// SkMatrix is only 3x3 so we drop the 3rd row and column.
template <>
struct TypeConverter<SkMatrix, geometry::Transform> {
  static SkMatrix Convert(const geometry::Transform& input);
};
template <>
struct TypeConverter<geometry::Transform, SkMatrix> {
  static geometry::Transform Convert(const SkMatrix& input);
};

// Note: This transformation is lossless.
template <>
struct TypeConverter<SkMatrix44, geometry::Transform> {
  static SkMatrix44 Convert(const geometry::Transform& input);
};
template <>
struct TypeConverter<geometry::Transform, SkMatrix44> {
  static geometry::Transform Convert(const SkMatrix44& input);
};

}  // namespace fxl

#endif  // LIB_UI_SKIA_TYPE_CONVERTERS_H_
