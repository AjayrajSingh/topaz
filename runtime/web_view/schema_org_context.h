// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#pragma once

#include <vector>
#include <string>

class WebView;

std::vector<std::string> ExtractSchemaOrgContext(WebView& web_view);
