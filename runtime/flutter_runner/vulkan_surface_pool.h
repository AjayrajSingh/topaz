// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#pragma once

#include <unordered_map>
#include <vector>

#include "flutter/fml/macros.h"
#include "vulkan_surface.h"

namespace flutter {

class VulkanSurfacePool final {
 public:
  // Only keep 12 surfaces at a time.  This value was based on how many
  // surfaces got cached in the old, exact-match-only caching logic.
  static constexpr int kMaxSurfaces = 12;
  // If a surface doesn't get used for 3 or more generations, we discard it.
  static constexpr int kMaxSurfaceAge = 3;

  VulkanSurfacePool(vulkan::VulkanProvider& vulkan_provider,
                    sk_sp<GrContext> context, scenic::Session* scenic_session);

  ~VulkanSurfacePool();

  std::unique_ptr<flow::SceneUpdateContext::SurfaceProducerSurface>
  AcquireSurface(const SkISize& size);

  void SubmitSurface(
      std::unique_ptr<flow::SceneUpdateContext::SurfaceProducerSurface>
          surface);

  void AgeAndCollectOldBuffers();

  // Shrink all oversized |VulkanSurfaces| in |available_surfaces_| to as
  // small as they can be.
  void ShrinkToFit();

 private:
  vulkan::VulkanProvider& vulkan_provider_;
  sk_sp<GrContext> context_;
  scenic::Session* scenic_session_;
  std::vector<std::unique_ptr<VulkanSurface>> available_surfaces_;
  std::unordered_map<uintptr_t, std::unique_ptr<VulkanSurface>>
      pending_surfaces_;
  size_t trace_surfaces_created_ = 0;
  size_t trace_surfaces_reused_ = 0;

  std::unique_ptr<flow::SceneUpdateContext::SurfaceProducerSurface>
  GetCachedOrCreateSurface(const SkISize& size);

  std::unique_ptr<VulkanSurface> CreateSurface(const SkISize& size);

  void RecycleSurface(uintptr_t surface_key);

  void TraceStats();

  FML_DISALLOW_COPY_AND_ASSIGN(VulkanSurfacePool);
};

}  // namespace flutter
