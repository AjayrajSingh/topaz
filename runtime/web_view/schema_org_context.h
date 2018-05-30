// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#pragma once

#include <string>
#include <vector>

#include <fuchsia/modular/cpp/fidl.h>

class WebView;

class SchemaOrgContext {
 public:
  SchemaOrgContext(WebView& web_view);

  void set_context_writer(fuchsia::modular::ContextWriterPtr context_writer) {
    context_writer_ = std::move(context_writer);
  }
  void set_component_context(
      fuchsia::modular::ComponentContextPtr component_context) {
    component_context_ = std::move(component_context);
  }

 private:
  void PageLoaded();
  void EntitiesChanged();

  WebView& web_view_;
  std::string script_ = "";

  fuchsia::modular::ComponentContextPtr component_context_;
  fuchsia::modular::ContextWriterPtr context_writer_;
  std::vector<fuchsia::modular::ContextValueWriterPtr> context_values_;
};
