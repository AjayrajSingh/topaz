// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "topaz/runtime/web_view/schema_org_context.h"

#include "lib/fxl/files/file.h"
#include "lib/fxl/logging.h"
#include "peridot/lib/rapidjson/rapidjson.h"

#include "WebView.h"

namespace {

constexpr char script_path[] = "/system/data/js/extract_schema_org.js";
std::string script = "";
bool script_loaded = false;

}  // namespace

std::vector<std::string> ExtractSchemaOrgContext(WebView& web_view) {
  std::vector<std::string> values;

  if (!script_loaded) {
    script_loaded = files::ReadFileToString(script_path, &script);
    if (!script_loaded) {
      FXL_LOG(WARNING) << "Failed to load script: " << script_path;
      return values;
    }
  }

  std::string json = web_view.stringByEvaluatingJavaScriptFromString(script);
  modular::JsonDoc parsed;
  parsed.Parse(json);

  if (!parsed.IsArray()) {
    return values;
  }

  for (auto i = parsed.Begin(); i != parsed.End(); ++i) {
    values.push_back(modular::JsonValueToPrettyString(*i));
  }

  return values;
}
