// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef TOPAZ_AUTH_PROVIDERS_GOOGLE_SETTINGS_H_
#define TOPAZ_AUTH_PROVIDERS_GOOGLE_SETTINGS_H_

namespace google_auth_provider {

struct Settings {
  // Set true to display authentication UI using the chromium.web interface, or
  // false to use to the fuchsia.webview interface.
  bool use_chromium = false;
};

}  // namespace google_auth_provider

#endif  // TOPAZ_AUTH_PROVIDERS_GOOGLE_SETTINGS_H_
