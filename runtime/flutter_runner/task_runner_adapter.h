// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#pragma once

#include "flutter/fml/task_runner.h"
#include "lib/fxl/tasks/task_runner.h"

namespace flutter {

fml::RefPtr<fml::TaskRunner> CreateFMLTaskRunner(
    fxl::RefPtr<fxl::TaskRunner> runner);

}  // namespace flutter
