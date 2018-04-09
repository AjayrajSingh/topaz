// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef TOPAZ_AUTH_PROVIDERS_SPOTIFY_CONSTANTS_H_
#define TOPAZ_AUTH_PROVIDERS_SPOTIFY_CONSTANTS_H_

#include <initializer_list>

namespace spotify_auth_provider {

constexpr char kSpotifyOAuthAuthEndpoint[] =
    "https://accounts.spotify.com/authorize";
constexpr char kSpotifyOAuthTokenEndpoint[] =
    "https://accounts.spotify.com/api/token";
// Spotify doesn't provide a programmatic way to revoke access. Instead, users
// revoke access manually by visting this url.
constexpr char kSpotifyRevokeTokenEndpoint[] =
    "https://www.spotify.com/account/";
constexpr char kSpotifyPeopleGetEndpoint[] =
    "https://api.spotify.com/v1/me";
constexpr char kRedirectUri[] = "com.spotify.fuchsia.auth:/oauth2redirect";
constexpr char kWebViewUrl[] = "web_view";

// Default scopes
constexpr auto kScopes = {
    "user-read-private",
    "user-read-email",
    "user-read-birthdate",
    "playlist-read-private",
    "playlist-modify-private",
    "playlist-modify-public",
    "playlist-read-collaborative",
    "user-top-read",
    "user-read-recently-played"
};

} // namespace spotify_auth_provider

#endif // TOPAZ_AUTH_PROVIDERS_SPOTIFY_CONSTANTS_H_


