// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef TOPAZ_RUNTIME_DART_UTILS_VMSERVICE_OBJECT_H_
#define TOPAZ_RUNTIME_DART_UTILS_VMSERVICE_OBJECT_H_

#include "lib/component/cpp/exposed_object.h"

namespace fuchsia {
namespace dart {

class VMServiceObject : public component::ExposedObject {
 public:
  static constexpr const char* kDirName = "DartVM";
  static constexpr const char* kPortDirName = "vmservice-port";
  static constexpr const char* kPortDir = "/tmp/dart.services";

  VMServiceObject();

  static std::unique_ptr<VMServiceObject> Create(
      component::ObjectDir* object_dir);
};

}  // namespace dart
}  // namespace fuchsia

#endif  // TOPAZ_RUNTIME_UTILS_VMSERVICE_OBJECT_H_
