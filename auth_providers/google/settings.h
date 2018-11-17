// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef TOPAZ_AUTH_PROVIDERS_GOOGLE_SETTINGS_H_
#define TOPAZ_AUTH_PROVIDERS_GOOGLE_SETTINGS_H_

namespace google_auth_provider {

struct Settings {
  // Set true to display authentication UI using the chromium.web interface, or
  // false to use to the fuchsia.webview interface.
#if defined(DEFAULT_USE_CHROMIUM)
  bool use_chromium = true;
#else
  bool use_chromium = false;
#endif
  // Set true to request the "GLIF" UI style. The default of false will request
  // the legacy "RedCarpet" UI style.
  bool use_glif = false;
  // Set true to connect to a dedicated authentication endpoint for Fuchsia
  // instead of the standard OAuth endpoint.
  bool use_dedicated_endpoint = false;
};

}  // namespace google_auth_provider

#endif  // TOPAZ_AUTH_PROVIDERS_GOOGLE_SETTINGS_H_
