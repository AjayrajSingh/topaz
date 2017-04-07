// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#pragma once

#include "apps/maxwell/services/context/context_subscriber.fidl.h"
#include "lib/fidl/cpp/bindings/formatting.h"

namespace maxwell {

std::ostream& operator<<(std::ostream& os, const ContextUpdate& update);

std::ostream& operator<<(std::ostream& os, const ContextQuery& query);

}  // namespace maxwell
