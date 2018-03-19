// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "topaz/runtime/web_view/schema_org_context.h"

#include "lib/fxl/files/file.h"
#include "lib/fxl/logging.h"
#include "lib/url/gurl.h"
#include "peridot/lib/rapidjson/rapidjson.h"

#include "WebView.h"

namespace {

constexpr char script_path[] = "/system/data/js/extract_schema_org.js";

constexpr char get_json[] = "JSON.stringify(document['fuchsia:entities'])";

constexpr char type_field[] = "@type";
constexpr char context_field[] = "@context";

std::string ExtractTypeFromEntity(const rapidjson::Value& entity) {
  FXL_DCHECK(entity.IsObject());
  std::string context;
  if (entity.HasMember(context_field)) {
    const auto& context_json = entity[context_field];
    // TODO(ianloic): handle more complex @context.
    if (!context_json.IsString()) {
      FXL_LOG(WARNING) << "Expected " << context_field << " to be a string in: "
                       << modular::JsonValueToPrettyString(entity);
      return "";
    }
    context.assign(context_json.GetString(), context_json.GetStringLength());
  }

  if (!entity.HasMember(type_field)) {
    FXL_LOG(WARNING) << "Expected JSON-LD to have a " << type_field << ": "
                     << modular::JsonValueToPrettyString(entity);
    return "";
  }

  const auto& type_json = entity[type_field];
  // TODO(ianloic): can @type be an array?
  if (!type_json.IsString()) {
    FXL_LOG(WARNING) << "Expected " << type_field << " to be a string in: "
                     << modular::JsonValueToPrettyString(entity);
    return "";
  }

  std::string type(type_json.GetString(), type_json.GetStringLength());

  if (!context.size()) {
    return type;
  }

  url::GURL context_url(context);
  if (!context_url.is_valid()) {
    FXL_LOG(WARNING) << context_field << " not valid in: "
                     << modular::JsonValueToPrettyString(entity);
    return "";
  }

  url::GURL type_url = context_url.Resolve(type);
  if (!type_url.is_valid()) {
    FXL_LOG(WARNING) << "Couldn't resolve " << type_field << " relative to "
                     << context_field
                     << " in: " << modular::JsonValueToPrettyString(entity);
    return "";
  }

  return type_url.spec();
}

}  // namespace

SchemaOrgContext::SchemaOrgContext(WebView& web_view) : web_view_(web_view) {
  bool script_loaded = files::ReadFileToString(script_path, &script_);
  if (!script_loaded) {
    FXL_LOG(WARNING) << "Failed to load script: " << script_path;
    return;
  }
  web_view_.setDidFinishLoadDelegate([this] { PageLoaded(); });
}

void SchemaOrgContext::PageLoaded() {
  FXL_LOG(INFO) << "Page Loaded";
  web_view_.addCustomEventHandler("fuchsia-entities-changed",
                                  [this] { EntitiesChanged(); });
  web_view_.stringByEvaluatingJavaScriptFromString(script_);
}

void SchemaOrgContext::EntitiesChanged() {
  FXL_LOG(INFO) << "Entities Changed";
  // Remove any existing values.
  context_values_.clear();

  // Get new entity JSON from the web page.
  std::string json = web_view_.stringByEvaluatingJavaScriptFromString(get_json);
  modular::JsonDoc parsed;
  parsed.Parse(json);
  if (!parsed.IsArray()) {
    FXL_LOG(WARNING) << "Root JSON object not an array: " << json;
    return;
  }

  // Process the JSON into entities.
  for (auto i = parsed.Begin(); i != parsed.End(); ++i) {
    const auto& entity_json = *i;
    if (!entity_json.IsObject()) {
      FXL_LOG(WARNING) << "Expected JSON-LD object, got: "
                       << modular::JsonValueToPrettyString(entity_json);
      continue;
    }
    std::string type = ExtractTypeFromEntity(entity_json);
    FXL_LOG(INFO) << "entity type: " << type;
    if (type.size()) {
      f1dl::VectorPtr<modular::TypeToDataEntryPtr> type_to_data_array;
      modular::TypeToDataEntryPtr entry = modular::TypeToDataEntry::New();
      entry->type = type;
      entry->data = modular::JsonValueToPrettyString(*i);
      type_to_data_array.push_back(std::move(entry));
      component_context_->CreateEntityWithData(
          std::move(type_to_data_array),
          [this](const std::string& entity_reference) {
            maxwell::ContextValueWriterPtr value;
            context_writer_->CreateValue(value.NewRequest(),
                                         maxwell::ContextValueType::ENTITY);
            value->Set(entity_reference, nullptr /* metadata */);
            // TODO: there's a potential race here if EntitiesChanged is
            // called while there are outstanding CreateEntityWithData
            // callbacks.
            context_values_.push_back(std::move(value));
          });
    }
  }
}
