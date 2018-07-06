// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#pragma once

#include "flutter/flow/scene_update_context.h"
#include "flutter/vulkan/vulkan_application.h"
#include "flutter/vulkan/vulkan_device.h"
#include "flutter/vulkan/vulkan_proc_table.h"
#include "flutter/vulkan/vulkan_provider.h"
#include "lib/fxl/macros.h"
#include "lib/ui/scenic/cpp/resources.h"
#include "lib/ui/scenic/cpp/session.h"
#include "topaz/lib/deprecated_loop/message_loop.h"
#include "vulkan_surface.h"
#include "vulkan_surface_pool.h"

namespace flutter {

class VulkanSurfaceProducer final
    : public flow::SceneUpdateContext::SurfaceProducer,
      public vulkan::VulkanProvider {
 public:
  VulkanSurfaceProducer(scenic::Session* scenic_session);

  ~VulkanSurfaceProducer();

  bool IsValid() const { return valid_; }

  // |flow::SceneUpdateContext::SurfaceProducer|
  std::unique_ptr<flow::SceneUpdateContext::SurfaceProducerSurface>
  ProduceSurface(const SkISize& size) override;

  // |flow::SceneUpdateContext::SurfaceProducer|
  void SubmitSurface(
      std::unique_ptr<flow::SceneUpdateContext::SurfaceProducerSurface> surface)
      override;

  void OnSurfacesPresented(
      std::vector<
          std::unique_ptr<flow::SceneUpdateContext::SurfaceProducerSurface>>
          surfaces);

 private:
  // VulkanProvider
  const vulkan::VulkanProcTable& vk() override { return *vk_.get(); }
  const vulkan::VulkanHandle<VkDevice>& vk_device() override {
    return logical_device_->GetHandle();
  }

  bool TransitionSurfacesToExternal(
      const std::vector<
          std::unique_ptr<flow::SceneUpdateContext::SurfaceProducerSurface>>&
          surfaces);

  // Note: the order here is very important. The proctable must be destroyed
  // last because it contains the function pointers for VkDestroyDevice and
  // VkDestroyInstance.
  fxl::RefPtr<vulkan::VulkanProcTable> vk_;
  std::unique_ptr<vulkan::VulkanApplication> application_;
  std::unique_ptr<vulkan::VulkanDevice> logical_device_;
  sk_sp<GrContext> context_;
  std::unique_ptr<VulkanSurfacePool> surface_pool_;
  bool valid_ = false;

  bool Initialize(scenic::Session* scenic_session);

  FXL_DISALLOW_COPY_AND_ASSIGN(VulkanSurfaceProducer);
};

}  // namespace flutter
