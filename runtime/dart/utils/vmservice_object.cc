// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "topaz/runtime/dart/utils/vmservice_object.h"

#include <errno.h>
#include <zircon/status.h>

#include "lib/component/cpp/exposed_object.h"
#include "lib/fxl/files/directory.h"
#include "lib/fxl/files/file.h"

namespace fuchsia {
namespace dart {

VMServiceObject::VMServiceObject() : ExposedObject(kDirName) {
  // This code exposes the contents of /${kPortDir} in the hub for the
  // dart_runner at /hub/.../out/objects/${kDirName}/${kPortDirName}.
  object_dir().set_children_callback(component::ObjectPath{kPortDirName},
      [](component::Object::ObjectVector* out_children){
    // List /tmp/dart.services if it exists, and push its contents as
    // component::Objects onto out_children.
    std::vector<std::string> files;
    if (!files::ReadDirContents(kPortDir, &files)) {
      FXL_LOG(ERROR) << "Failed to read Dart VM Service port directory '"
                     << kPortDir << "':"
                     << strerror(errno);
      return;
    }
    for (const auto& file : files) {
      if ((file == ".") || (file == "..")) {
        continue;
      }
      out_children->push_back(component::ObjectDir::Make(file).object());
    }
  });
}

std::unique_ptr<VMServiceObject> VMServiceObject::Create(
    component::ObjectDir* object_dir) {
  auto vmservice = std::make_unique<VMServiceObject>();
  vmservice->set_parent(*object_dir);
  return vmservice;
}

}  // namespace dart
}  // namespace fuchsia
