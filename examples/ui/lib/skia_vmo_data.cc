// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "examples/ui/lib/skia_vmo_data.h"

#include <atomic>

#include <trace/event.h>
#include <zx/vmar.h>

#include "lib/fxl/logging.h"

static_assert(sizeof(size_t) == sizeof(uint64_t),
              "Fuchsia should always be 64-bit");

namespace mozart {
namespace {

std::atomic<int32_t> g_count;

void TraceCount(int32_t delta) {
  int32_t count = g_count.fetch_add(delta, std::memory_order_relaxed) + delta;
  TRACE_COUNTER("gfx", "SkDataVmo", 0u, "count", count);
}

void UnmapMemory(const void* buffer, void* context) {
  const uint64_t size = reinterpret_cast<uint64_t>(context);
  zx_status_t status =
      zx::vmar::root_self().unmap(reinterpret_cast<uintptr_t>(buffer), size);
  FXL_CHECK(status == ZX_OK);
  TraceCount(-1);
}

}  // namespace

sk_sp<SkData> MakeSkDataFromVMO(const fsl::SizedVmo& vmo) {
  uint64_t size = vmo.size();
  uintptr_t buffer = 0u;
  zx_status_t status = zx::vmar::root_self().map(0, vmo.vmo(), 0u, size,
                                                 ZX_VM_FLAG_PERM_READ, &buffer);
  if (status != ZX_OK)
    return nullptr;

  sk_sp<SkData> data =
      SkData::MakeWithProc(reinterpret_cast<void*>(buffer), size, &UnmapMemory,
                           reinterpret_cast<void*>(size));
  if (!data) {
    FXL_LOG(ERROR) << "Could not create SkData";
    status = zx::vmar::root_self().unmap(buffer, size);
    FXL_CHECK(status == ZX_OK);
    return nullptr;
  }

  TraceCount(1);
  return data;
}

}  // namespace mozart
