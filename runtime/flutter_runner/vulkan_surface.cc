// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "vulkan_surface.h"

#include <lib/async/default.h>

#include <algorithm>

#include "flutter/fml/trace_event.h"
#include "lib/fxl/logging.h"
#include "third_party/skia/include/core/SkCanvas.h"
#include "third_party/skia/include/gpu/GrBackendSemaphore.h"
#include "third_party/skia/include/gpu/GrBackendSurface.h"
#include "third_party/skia/include/gpu/GrContext.h"

namespace flutter {

namespace {

constexpr SkColorType kSkiaColorType = kBGRA_8888_SkColorType;

}  // namespace

bool CreateVulkanImage(vulkan::VulkanProvider& vulkan_provider,
                       const SkISize& size, VulkanImage* out_vulkan_image) {
  TRACE_DURATION("flutter", "CreateVulkanImage");

  FML_DCHECK(!size.isEmpty());
  FML_DCHECK(out_vulkan_image != nullptr);

  out_vulkan_image->vk_image_create_info = {
      .sType = VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO,
      .pNext = nullptr,
      .flags = VK_IMAGE_CREATE_MUTABLE_FORMAT_BIT,
      .imageType = VK_IMAGE_TYPE_2D,
      .format = VK_FORMAT_B8G8R8A8_UNORM,
      .extent = VkExtent3D{static_cast<uint32_t>(size.width()),
                           static_cast<uint32_t>(size.height()), 1},
      .mipLevels = 1,
      .arrayLayers = 1,
      .samples = VK_SAMPLE_COUNT_1_BIT,
      .tiling = VK_IMAGE_TILING_OPTIMAL,
      .usage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
      .sharingMode = VK_SHARING_MODE_EXCLUSIVE,
      .queueFamilyIndexCount = 0,
      .pQueueFamilyIndices = nullptr,
      .initialLayout = VK_IMAGE_LAYOUT_UNDEFINED,
  };

  {
    VkImage vk_image = VK_NULL_HANDLE;

    if (VK_CALL_LOG_ERROR(vulkan_provider.vk().CreateImage(
            vulkan_provider.vk_device(),
            &out_vulkan_image->vk_image_create_info, nullptr, &vk_image)) !=
        VK_SUCCESS) {
      return false;
    }

    out_vulkan_image->vk_image = {
        vk_image, [& vulkan_provider = vulkan_provider](VkImage image) {
          vulkan_provider.vk().DestroyImage(vulkan_provider.vk_device(), image,
                                            NULL);
        }};
  }

  vulkan_provider.vk().GetImageMemoryRequirements(
      vulkan_provider.vk_device(), out_vulkan_image->vk_image,
      &out_vulkan_image->vk_memory_requirements);

  return true;
}

VulkanSurface::VulkanSurface(vulkan::VulkanProvider& vulkan_provider,
                             sk_sp<GrContext> context, scenic::Session* session,
                             const SkISize& size)
    : vulkan_provider_(vulkan_provider), session_(session), wait_(this) {
  FML_DCHECK(session_);

  zx::vmo exported_vmo;
  if (!AllocateDeviceMemory(std::move(context), size, exported_vmo)) {
    FML_DLOG(INFO) << "Could not allocate device memory.";
    return;
  }

  uint64_t vmo_size;
  zx_status_t status = exported_vmo.get_size(&vmo_size);
  FML_DCHECK(status == ZX_OK);

  if (!CreateFences()) {
    FML_DLOG(INFO) << "Could not create signal fences.";
    return;
  }

  scenic_memory_ = std::make_unique<scenic::Memory>(
      session, std::move(exported_vmo), vmo_size,
      fuchsia::images::MemoryType::VK_DEVICE_MEMORY);
  if (!PushSessionImageSetupOps(session)) {
    FML_DLOG(INFO) << "Could not push session image setup ops.";
    return;
  }

  std::fill(size_history_.begin(), size_history_.end(), SkISize::MakeEmpty());

  wait_.set_object(release_event_.get());
  wait_.set_trigger(ZX_EVENT_SIGNALED);
  Reset();

  valid_ = true;
}

VulkanSurface::~VulkanSurface() {
  wait_.Cancel();
  wait_.set_object(ZX_HANDLE_INVALID);
}

bool VulkanSurface::IsValid() const { return valid_; }

SkISize VulkanSurface::GetSize() const {
  if (!valid_) {
    return SkISize::Make(0, 0);
  }

  return SkISize::Make(sk_surface_->width(), sk_surface_->height());
}

vulkan::VulkanHandle<VkSemaphore> VulkanSurface::SemaphoreFromEvent(
    const zx::event& event) const {
  VkResult result;
  VkSemaphore semaphore;

  zx::event semaphore_event;
  zx_status_t status = event.duplicate(ZX_RIGHT_SAME_RIGHTS, &semaphore_event);
  if (status != ZX_OK) {
    FML_DLOG(ERROR) << "failed to duplicate semaphore event";
    return vulkan::VulkanHandle<VkSemaphore>();
  }

  VkSemaphoreCreateInfo create_info = {
      .sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
      .pNext = nullptr,
      .flags = 0,
  };

  result = VK_CALL_LOG_ERROR(vulkan_provider_.vk().CreateSemaphore(
      vulkan_provider_.vk_device(), &create_info, nullptr, &semaphore));
  if (result != VK_SUCCESS) {
    return vulkan::VulkanHandle<VkSemaphore>();
  }

  VkImportSemaphoreFuchsiaHandleInfoKHR import_info = {
      .sType = VK_STRUCTURE_TYPE_IMPORT_SEMAPHORE_FUCHSIA_HANDLE_INFO_KHR,
      .pNext = nullptr,
      .semaphore = semaphore,
      .handleType = VK_EXTERNAL_SEMAPHORE_HANDLE_TYPE_FUCHSIA_FENCE_BIT_KHR,
      .handle = static_cast<uint32_t>(semaphore_event.release())};

  result =
      VK_CALL_LOG_ERROR(vulkan_provider_.vk().ImportSemaphoreFuchsiaHandleKHR(
          vulkan_provider_.vk_device(), &import_info));
  if (result != VK_SUCCESS) {
    return vulkan::VulkanHandle<VkSemaphore>();
  }

  return vulkan::VulkanHandle<VkSemaphore>(
      semaphore, [&vulkan_provider = vulkan_provider_](VkSemaphore semaphore) {
        vulkan_provider.vk().DestroySemaphore(vulkan_provider.vk_device(),
                                              semaphore, nullptr);
      });
}

bool VulkanSurface::CreateFences() {
  if (zx::event::create(0, &acquire_event_) != ZX_OK) {
    return false;
  }

  acquire_semaphore_ = SemaphoreFromEvent(acquire_event_);
  if (!acquire_semaphore_) {
    FML_DLOG(ERROR) << "failed to create acquire semaphore";
    return false;
  }

  if (zx::event::create(0, &release_event_) != ZX_OK) {
    return false;
  }

  command_buffer_fence_ = vulkan_provider_.CreateFence();

  return true;
}

bool VulkanSurface::AllocateDeviceMemory(sk_sp<GrContext> context,
                                         const SkISize& size,
                                         zx::vmo& exported_vmo) {
  if (size.isEmpty()) {
    return false;
  }

  VulkanImage vulkan_image;
  if (!CreateVulkanImage(vulkan_provider_, size, &vulkan_image)) {
    FML_DLOG(ERROR) << "Failed to create VkImage";
    return false;
  }

  vulkan_image_ = std::move(vulkan_image);
  const VkMemoryRequirements& memory_reqs =
      vulkan_image_.vk_memory_requirements;
  const VkImageCreateInfo& image_create_info =
      vulkan_image_.vk_image_create_info;

  uint32_t memory_type = 0;
  for (; memory_type < 32; memory_type++) {
    if ((memory_reqs.memoryTypeBits & (1 << memory_type))) {
      break;
    }
  }

  VkExportMemoryAllocateInfoKHR export_allocate_info = {
      .sType = VK_STRUCTURE_TYPE_EXPORT_MEMORY_ALLOCATE_INFO_KHR,
      .pNext = nullptr,
      .handleTypes = VK_EXTERNAL_MEMORY_HANDLE_TYPE_FUCHSIA_VMO_BIT_KHR};

  const VkMemoryAllocateInfo alloc_info = {
      .sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
      .pNext = &export_allocate_info,
      .allocationSize = memory_reqs.size,
      .memoryTypeIndex = memory_type,
  };

  {
    TRACE_DURATION("flutter", "vk().AllocateMemory", "allocation_size",
                   alloc_info.allocationSize);
    VkDeviceMemory vk_memory = VK_NULL_HANDLE;
    if (VK_CALL_LOG_ERROR(vulkan_provider_.vk().AllocateMemory(
            vulkan_provider_.vk_device(), &alloc_info, NULL, &vk_memory)) !=
        VK_SUCCESS) {
      return false;
    }

    vk_memory_ = {vk_memory, [& vulkan_provider =
                                  vulkan_provider_](VkDeviceMemory memory) {
                    vulkan_provider.vk().FreeMemory(vulkan_provider.vk_device(),
                                                    memory, NULL);
                  }};

    vk_memory_info_ = alloc_info;
  }

  // Bind image memory.
  if (VK_CALL_LOG_ERROR(vulkan_provider_.vk().BindImageMemory(
          vulkan_provider_.vk_device(), vulkan_image_.vk_image, vk_memory_,
          0)) != VK_SUCCESS) {
    return false;
  }

  {
    // Acquire the VMO for the device memory.
    uint32_t vmo_handle = 0;

    VkMemoryGetFuchsiaHandleInfoKHR get_handle_info = {
        VK_STRUCTURE_TYPE_MEMORY_GET_FUCHSIA_HANDLE_INFO_KHR, nullptr,
        vk_memory_, VK_EXTERNAL_MEMORY_HANDLE_TYPE_FUCHSIA_VMO_BIT_KHR};
    if (VK_CALL_LOG_ERROR(vulkan_provider_.vk().GetMemoryFuchsiaHandleKHR(
            vulkan_provider_.vk_device(), &get_handle_info, &vmo_handle)) !=
        VK_SUCCESS) {
      return false;
    }

    exported_vmo.reset(static_cast<zx_handle_t>(vmo_handle));
  }

  // Assert that the VMO size was sufficient.
  size_t vmo_size = 0;
  if (exported_vmo.get_size(&vmo_size) != ZX_OK ||
      vmo_size < memory_reqs.size) {
    return false;
  }

  return SetupSkiaSurface(std::move(context), size, kSkiaColorType,
                          image_create_info, memory_reqs);
}

bool VulkanSurface::SetupSkiaSurface(sk_sp<GrContext> context,
                                     const SkISize& size,
                                     SkColorType color_type,
                                     const VkImageCreateInfo& image_create_info,
                                     const VkMemoryRequirements& memory_reqs) {
  if (context == nullptr) {
    return false;
  }

  const GrVkImageInfo image_info = {
      vulkan_image_.vk_image,                // image
      {vk_memory_, 0, memory_reqs.size, 0},  // alloc
      image_create_info.tiling,              // tiling
      image_create_info.initialLayout,       // layout
      image_create_info.format,              // format
      image_create_info.mipLevels,           // level count
  };

  GrBackendRenderTarget sk_render_target(size.width(), size.height(), 0,
                                         image_info);

  SkSurfaceProps sk_surface_props(
      SkSurfaceProps::InitType::kLegacyFontHost_InitType);

  auto sk_surface =
      SkSurface::MakeFromBackendRenderTarget(context.get(),             //
                                             sk_render_target,          //
                                             kTopLeft_GrSurfaceOrigin,  //
                                             color_type,                //
                                             nullptr,                   //
                                             &sk_surface_props          //
      );

  if (!sk_surface || sk_surface->getCanvas() == nullptr) {
    return false;
  }
  sk_surface_ = std::move(sk_surface);

  return true;
}

bool VulkanSurface::PushSessionImageSetupOps(scenic::Session* session) {
  FML_DCHECK(scenic_memory_ != nullptr);

  if (sk_surface_ == nullptr) {
    return false;
  }

  fuchsia::images::ImageInfo image_info;
  image_info.width = sk_surface_->width();
  image_info.height = sk_surface_->height();
  image_info.stride = 4 * sk_surface_->width();
  image_info.pixel_format = fuchsia::images::PixelFormat::BGRA_8;
  image_info.color_space = fuchsia::images::ColorSpace::SRGB;
  image_info.tiling = fuchsia::images::Tiling::LINEAR;

  session_image_ = std::make_unique<scenic::Image>(
      *scenic_memory_, 0 /* memory offset */, std::move(image_info));

  return session_image_ != nullptr;
}

scenic::Image* VulkanSurface::GetImage() {
  if (!valid_) {
    return 0;
  }
  return session_image_.get();
}

sk_sp<SkSurface> VulkanSurface::GetSkiaSurface() const {
  return valid_ ? sk_surface_ : nullptr;
}

bool VulkanSurface::BindToImage(sk_sp<GrContext> context,
                                VulkanImage vulkan_image) {
  FML_DCHECK(vulkan_image.vk_memory_requirements.size <=
             vk_memory_info_.allocationSize);

  vulkan_image_ = std::move(vulkan_image);

  // Bind image memory.
  if (VK_CALL_LOG_ERROR(vulkan_provider_.vk().BindImageMemory(
          vulkan_provider_.vk_device(), vulkan_image_.vk_image, vk_memory_,
          0)) != VK_SUCCESS) {
    valid_ = false;
    return false;
  }

  const auto& extent = vulkan_image.vk_image_create_info.extent;
  auto size = SkISize::Make(extent.width, extent.height);

  if (!SetupSkiaSurface(std::move(context), size, kSkiaColorType,
                        vulkan_image.vk_image_create_info,
                        vulkan_image.vk_memory_requirements)) {
    FML_DLOG(ERROR) << "Failed to setup skia surface";
    valid_ = false;
    return false;
  }

  if (sk_surface_ == nullptr) {
    valid_ = false;
    return false;
  }

  if (!PushSessionImageSetupOps(session_)) {
    FML_DLOG(ERROR) << "Could not push session image setup ops.";
    valid_ = false;
    return false;
  }

  return true;
}

size_t VulkanSurface::AdvanceAndGetAge() {
  size_history_[size_history_index_] = GetSize();
  size_history_index_ = (size_history_index_ + 1) % kSizeHistorySize;
  age_++;
  return age_;
}

bool VulkanSurface::FlushSessionAcquireAndReleaseEvents() {
  zx::event acquire, release;

  if (acquire_event_.duplicate(ZX_RIGHT_SAME_RIGHTS, &acquire) != ZX_OK ||
      release_event_.duplicate(ZX_RIGHT_SAME_RIGHTS, &release) != ZX_OK) {
    return false;
  }

  session_->EnqueueAcquireFence(std::move(acquire));
  session_->EnqueueReleaseFence(std::move(release));
  age_ = 0;
  return true;
}

void VulkanSurface::SignalWritesFinished(
    std::function<void(void)> on_writes_committed) {
  FML_DCHECK(on_writes_committed);

  if (!valid_) {
    on_writes_committed();
    return;
  }

  FXL_CHECK(pending_on_writes_committed_ == nullptr)
      << "Attempted to signal a write on the surface when the previous write "
         "has not yet been acknowledged by the compositor.";

  pending_on_writes_committed_ = on_writes_committed;
}

void VulkanSurface::Reset() {
  if (acquire_event_.signal(ZX_EVENT_SIGNALED, 0u) != ZX_OK ||
      release_event_.signal(ZX_EVENT_SIGNALED, 0u) != ZX_OK) {
    valid_ = false;
    FML_DLOG(ERROR)
        << "Could not reset fences. The surface is no longer valid.";
  }

  VkFence fence = command_buffer_fence_;

  if (command_buffer_) {
    VK_CALL_LOG_ERROR(vulkan_provider_.vk().WaitForFences(
        vulkan_provider_.vk_device(), 1, &fence, VK_TRUE, UINT64_MAX));
    command_buffer_.reset();
  }

  VK_CALL_LOG_ERROR(vulkan_provider_.vk().ResetFences(
      vulkan_provider_.vk_device(), 1, &fence));

  // Need to make a new  acquire semaphore every frame or else validation layers
  // get confused about why no one is waiting on it in this VkInstance
  acquire_semaphore_.Reset();
  acquire_semaphore_ = SemaphoreFromEvent(acquire_event_);
  if (!acquire_semaphore_) {
    FML_DLOG(ERROR) << "failed to create acquire semaphore";
  }

  wait_.Begin(async_get_default_dispatcher());

  // It is safe for the caller to collect the surface in the callback.
  auto callback = pending_on_writes_committed_;
  pending_on_writes_committed_ = nullptr;
  if (callback) {
    callback();
  }
}

void VulkanSurface::OnHandleReady(async_dispatcher_t* dispatcher,
                                  async::WaitBase* wait, zx_status_t status,
                                  const zx_packet_signal_t* signal) {
  if (status != ZX_OK)
    return;
  FML_DCHECK(signal->observed & ZX_EVENT_SIGNALED);
  Reset();
}

}  // namespace flutter
