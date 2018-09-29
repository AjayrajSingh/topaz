// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#pragma once

#include <lib/async/cpp/wait.h>
#include <zx/event.h>
#include <zx/vmo.h>

#include <array>
#include <memory>

#include "flutter/flow/scene_update_context.h"
#include "flutter/fml/macros.h"
#include "flutter/vulkan/vulkan_command_buffer.h"
#include "flutter/vulkan/vulkan_handle.h"
#include "flutter/vulkan/vulkan_proc_table.h"
#include "flutter/vulkan/vulkan_provider.h"
#include "lib/ui/scenic/cpp/resources.h"
#include "third_party/skia/include/core/SkSurface.h"

namespace flutter {

// A |VkImage| and its relevant metadata.
struct VulkanImage {
  VulkanImage() = default;
  VulkanImage(VulkanImage&&) = default;
  VulkanImage& operator=(VulkanImage&&) = default;

  VkImageCreateInfo vk_image_create_info;
  VkMemoryRequirements vk_memory_requirements;
  vulkan::VulkanHandle<VkImage> vk_image;

  FML_DISALLOW_COPY_AND_ASSIGN(VulkanImage);
};

// Create a new |VulkanImage| of size |size|, stored in
// |out_vulkan_image|.  Returns whether creation of the |VkImage| was
// successful.
bool CreateVulkanImage(vulkan::VulkanProvider& vulkan_provider,
                       const SkISize& size, VulkanImage* out_vulkan_image);

class VulkanSurface final
    : public flow::SceneUpdateContext::SurfaceProducerSurface {
 public:
  VulkanSurface(vulkan::VulkanProvider& vulkan_provider,
                sk_sp<GrContext> context, scenic::Session* session,
                const SkISize& size);

  ~VulkanSurface() override;

  // |flow::SceneUpdateContext::SurfaceProducerSurface|
  size_t AdvanceAndGetAge() override;

  // |flow::SceneUpdateContext::SurfaceProducerSurface|
  bool FlushSessionAcquireAndReleaseEvents() override;

  // |flow::SceneUpdateContext::SurfaceProducerSurface|
  bool IsValid() const override;

  // |flow::SceneUpdateContext::SurfaceProducerSurface|
  SkISize GetSize() const override;

  // Note: It is safe for the caller to collect the surface in the
  // |on_writes_committed| callback.
  void SignalWritesFinished(
      std::function<void(void)> on_writes_committed) override;

  // |flow::SceneUpdateContext::SurfaceProducerSurface|
  scenic::Image* GetImage() override;

  // |flow::SceneUpdateContext::SurfaceProducerSurface|
  sk_sp<SkSurface> GetSkiaSurface() const override;

  const vulkan::VulkanHandle<VkImage>& GetVkImage() {
    return vulkan_image_.vk_image;
  }

  const vulkan::VulkanHandle<VkSemaphore>& GetAcquireVkSemaphore() {
    return acquire_semaphore_;
  }

  vulkan::VulkanCommandBuffer* GetCommandBuffer(
      const vulkan::VulkanHandle<VkCommandPool>& pool) {
    if (!command_buffer_)
      command_buffer_ = std::make_unique<vulkan::VulkanCommandBuffer>(
          vulkan_provider_.vk(), vulkan_provider_.vk_device(), pool);
    return command_buffer_.get();
  }

  const vulkan::VulkanHandle<VkFence>& GetCommandBufferFence() {
    return command_buffer_fence_;
  }

  size_t GetAllocationSize() const { return vk_memory_info_.allocationSize; }

  size_t GetImageMemoryRequirementsSize() const {
    return vulkan_image_.vk_memory_requirements.size;
  }

  bool IsOversized() const {
    return GetAllocationSize() > GetImageMemoryRequirementsSize();
  }

  bool HasStableSizeHistory() const {
    return std::equal(size_history_.begin() + 1, size_history_.end(),
                      size_history_.begin());
  }

  // Bind |vulkan_image| to |vk_memory_| and create a new skia surface,
  // replacing the previous |vk_image_|.  |vulkan_image| MUST require less
  // than or equal the amount of memory contained in |vk_memory_|. Returns
  // whether the swap was successful.  The |VulkanSurface| will become invalid
  // if the swap was not successful.
  bool BindToImage(sk_sp<GrContext> context, VulkanImage vulkan_image);

 private:
  static constexpr int kSizeHistorySize = 4;

  void OnHandleReady(async_dispatcher_t* dispatcher, async::WaitBase* wait,
                     zx_status_t status, const zx_packet_signal_t* signal);

  bool AllocateDeviceMemory(sk_sp<GrContext> context, const SkISize& size,
                            zx::vmo& exported_vmo);

  bool SetupSkiaSurface(sk_sp<GrContext> context, const SkISize& size,
                        SkColorType color_type,
                        const VkImageCreateInfo& image_create_info,
                        const VkMemoryRequirements& memory_reqs);

  bool CreateFences();

  bool PushSessionImageSetupOps(scenic::Session* session);

  void Reset();

  vulkan::VulkanHandle<VkSemaphore> SemaphoreFromEvent(
      const zx::event& event) const;

  vulkan::VulkanProvider& vulkan_provider_;
  scenic::Session* session_;
  VulkanImage vulkan_image_;
  vulkan::VulkanHandle<VkDeviceMemory> vk_memory_;
  VkMemoryAllocateInfo vk_memory_info_;
  vulkan::VulkanHandle<VkFence> command_buffer_fence_;
  sk_sp<SkSurface> sk_surface_;
  // TODO: Don't heap allocate this once SCN-268 is resolved.
  std::unique_ptr<scenic::Memory> scenic_memory_;
  std::unique_ptr<scenic::Image> session_image_;
  zx::event acquire_event_;
  vulkan::VulkanHandle<VkSemaphore> acquire_semaphore_;
  std::unique_ptr<vulkan::VulkanCommandBuffer> command_buffer_;
  zx::event release_event_;
  async::WaitMethod<VulkanSurface, &VulkanSurface::OnHandleReady> wait_;
  std::function<void()> pending_on_writes_committed_;
  std::array<SkISize, kSizeHistorySize> size_history_;
  int size_history_index_ = 0;
  size_t age_ = 0;
  bool valid_ = false;

  FML_DISALLOW_COPY_AND_ASSIGN(VulkanSurface);
};

}  // namespace flutter
