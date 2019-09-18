// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "examples/ui/lib/host_surfaces.h"

#include "examples/ui/lib/image_info.h"
#include "src/lib/fxl/logging.h"

namespace scenic {
namespace skia {
namespace {

// Keeps the HostData alive until skia calls us back in DestroySurfaceContext.
//
// If the ref pointer for HostData would allow us to AddRef/Release manually, we
// would not need to allocate this object on the heap to keep the HostData
// alive. Hopefully a future fit::ref_ptr will replace std::shared_ptr and let
// us avoid the heap allocation.
class SurfaceContext {
 public:
  explicit SurfaceContext(std::shared_ptr<scenic_util::HostData> data)
      : data_(std::move(data)) {}

 private:
  std::shared_ptr<scenic_util::HostData> data_;
};

void DestroySurfaceContext(void* pixels, void* context) {
  delete static_cast<SurfaceContext*>(context);
}

}  // namespace

sk_sp<SkSurface> MakeSkSurface(const scenic_util::HostImage& image) {
  return MakeSkSurface(image.info(), image.data(), image.memory_offset());
}

sk_sp<SkSurface> MakeSkSurface(const fuchsia::images::ImageInfo& image_info,
                               std::shared_ptr<scenic_util::HostData> data,
                               off_t memory_offset) {
  return MakeSkSurface(MakeSkImageInfo(image_info), image_info.stride,
                       std::move(data), memory_offset);
}

sk_sp<SkSurface> MakeSkSurface(SkImageInfo image_info, size_t row_bytes,
                               std::shared_ptr<scenic_util::HostData> data,
                               off_t memory_offset) {
  return SkSurface::MakeRasterDirectReleaseProc(
      image_info, static_cast<uint8_t*>(data->ptr()) + memory_offset, row_bytes,
      &DestroySurfaceContext, new SurfaceContext(data));
}

HostSkSurfacePool::HostSkSurfacePool(Session* session, uint32_t num_images)
    : image_pool_(session, num_images), surface_ptrs_(num_images) {}

HostSkSurfacePool::~HostSkSurfacePool() = default;

bool HostSkSurfacePool::Configure(
    const fuchsia::images::ImageInfo* image_info) {
  if (!image_pool_.Configure(std::move(image_info)))
    return false;

  for (uint32_t i = 0; i < num_images(); i++)
    surface_ptrs_[i].reset();
  return true;
}

sk_sp<SkSurface> HostSkSurfacePool::GetSkSurface(uint32_t index) {
  FXL_DCHECK(index < num_images());

  if (surface_ptrs_[index])
    return surface_ptrs_[index];

  const scenic_util::HostImage* image = image_pool_.GetImage(index);
  if (!image)
    return nullptr;

  surface_ptrs_[index] = MakeSkSurface(*image);
  return surface_ptrs_[index];
}

}  // namespace skia
}  // namespace scenic
