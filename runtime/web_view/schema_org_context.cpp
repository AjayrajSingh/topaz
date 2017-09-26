// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "topaz/runtime/web_view/schema_org_context.h"

#include "lib/fxl/logging.h"
#include "peridot/lib/rapidjson/rapidjson.h"

#include "WebView.h"

namespace {

constexpr char script[] = R"(
(function() {
  var entities = [];
  function addJsonLd(item) {
    // prefix @type with @context for context engine compatibility
    if (!item["@type"]) {
      return;
    }
    if (!item["@context"]) {
      return;
    }
    item["@type"] = item["@context"] + "/" + item["@type"];
    entities.push(item);
  }
  for (var script of document.querySelectorAll("script[type='application/ld+json']")) {
    var value;
    try {
      value = JSON.parse(script.textContent);
    } catch(e) {
      continue;
    }
    if (value instanceof Array) {
      for (item of value) {
        addJsonLd(item);
      }
    } else {
      addJsonLd(value);
    }
  }
  return JSON.stringify(entities);
})()
)";

}  // namespace

std::vector<std::string> ExtractSchemaOrgContext(WebView& web_view) {
  std::vector<std::string> values;

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
