// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef DART_PKG_ZIRCON_SDK_EXT_SYSTEM_H_
#define DART_PKG_ZIRCON_SDK_EXT_SYSTEM_H_

#include <zircon/syscalls.h>

#include "dart-pkg/zircon/sdk_ext/handle.h"
#include "third_party/tonic/dart_library_natives.h"
#include "third_party/tonic/dart_wrappable.h"
#include "third_party/tonic/typed_data/dart_byte_data.h"
#include "third_party/dart/runtime/include/dart_api.h"

namespace zircon {
namespace dart {

class System : public fxl::RefCountedThreadSafe<System>,
               public tonic::DartWrappable {
  DEFINE_WRAPPERTYPEINFO();
  FRIEND_REF_COUNTED_THREAD_SAFE(System);
  FRIEND_MAKE_REF_COUNTED(System);

 public:
  static Dart_Handle ChannelCreate(uint32_t options);
  static Dart_Handle ChannelFromFile(std::string path);
  static zx_status_t ChannelWrite(fxl::RefPtr<Handle> channel,
                                  const tonic::DartByteData& data,
                                  std::vector<Handle*> handles);
  // TODO(ianloic): Add ChannelRead
  static Dart_Handle ChannelQueryAndRead(fxl::RefPtr<Handle> channel);

  static Dart_Handle EventpairCreate(uint32_t options);

  static Dart_Handle SocketCreate(uint32_t options);
  static Dart_Handle SocketWrite(fxl::RefPtr<Handle> socket,
                                 const tonic::DartByteData& data,
                                 int options);
  static Dart_Handle SocketRead(fxl::RefPtr<Handle> socket, size_t size);

  static Dart_Handle VmoCreate(uint64_t size, uint32_t options);
  static Dart_Handle VmoFromFile(std::string path);
  static Dart_Handle VmoGetSize(fxl::RefPtr<Handle> vmo);
  static zx_status_t VmoSetSize(fxl::RefPtr<Handle> vmo, uint64_t size);
  static zx_status_t VmoWrite(fxl::RefPtr<Handle> vmo,
                              uint64_t offset,
                              const tonic::DartByteData& data);
  static Dart_Handle VmoRead(fxl::RefPtr<Handle> vmo,
                             uint64_t offset,
                             size_t size);

  static Dart_Handle VmoMap(fxl::RefPtr<Handle> vmo);

  static uint64_t ClockGet(uint32_t clock_id);

  static void RegisterNatives(tonic::DartLibraryNatives* natives);

  static zx_status_t ConnectToService(std::string path, fxl::RefPtr<Handle> channel);

 private:
  static void VmoMapFinalizer(void* isolate_callback_data,
                              Dart_WeakPersistentHandle handle,
                              void* peer);
};

}  // namespace dart
}  // namespace zircon

#endif  // DART_PKG_ZIRCON_SDK_EXT_SYSTEM_H_
