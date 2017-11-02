// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Various Contact Entry Types

/// A Contacts Email Address
class EmailAddress {
  /// Email address, e.g. littlePuppyCoco@cute.org
  final String value;

  /// Optional label to give for the email, e.g. Work, Personal...
  final String label;

  /// Constructor
  EmailAddress({
    this.value,
    this.label,
  });

  @override
  String toString() {
    return '$value';
  }

  /// Helper function to encode a Contact model into a json string
  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = <String, dynamic>{};

    json['label'] = label;
    json['value'] = value;

    return json;
  }
}

/// An Contacts "Physical" Address
class Address {
  /// City, ex Mountain View
  final String city;

  /// Full street name, e.g. 1842 Shoreline
  final String street;

  /// Province or State, e.g. California, Chihuahua
  final String region;

  /// Post/zip code, e.g. 95129
  final String postalCode;

  /// Country, e.g. United States of America, China
  final String country;

  /// Country code for given country, e.g. CN
  // TODO(dayang): Create list of country codes
  // https://fuchsia.atlassian.net/browse/SO-45
  final String countryCode;

  /// Optional label to give for the address, e.g. Home, Work...
  final String label;

  /// Constructor
  Address({
    this.city,
    this.street,
    this.region,
    this.postalCode,
    this.country,
    this.countryCode,
    this.label,
  });

  @override
  String toString() {
    return '$street, $city, $region, $postalCode, $country, '
        '$countryCode';
  }

  /// Helper function to encode a Contact model into a json string
  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = <String, dynamic>{};

    json['city'] = city;
    json['street'] = street;
    json['region'] = region;
    json['postalCode'] = postalCode;
    json['country'] = country;
    json['countryCode'] = countryCode;
    json['label'] = label;

    return json;
  }
}

/// A Contacts Phone Number
class PhoneNumber {
  /// Phone number, e.g. 911, 1-408-111-2222
  final String number;

  /// Optional label to give for the phone entry, e.g. Cell, Home, Work...
  final String label;

  /// Constructor
  PhoneNumber({
    this.number,
    this.label,
  });

  @override
  String toString() {
    return '$label $number';
  }

  /// Helper function to encode a Contact model into a json string
  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = <String, dynamic>{};

    json['number'] = number;
    json['label'] = label;

    return json;
  }
}

/// Various common social network types
enum SocialNetworkType {
  /// Facebook
  /// www.facebook.com
  facebook,

  /// LinkedIn
  /// www.linkedin.com
  linkedin,

  /// Twitter
  /// www.twitter.com
  twitter,

  /// Other social networks
  other,
}

/// Social network account associated with given Contact
class SocialNetwork {
  /// Type of social network, e.g. Facebook, Twitter ...
  final SocialNetworkType type;

  /// User account of Social Network, ex @google
  // TODO(dayang): Validation/formatting/adaptation of common social media
  // accounts.
  // https://fuchsia.atlassian.net/browse/SO-45
  final String account;

  /// Constructor
  SocialNetwork({
    this.type,
    this.account,
  });

  @override
  String toString() {
    return '$account';
  }

  /// Helper function to encode a Contact model into a json string
  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = <String, dynamic>{};

    json['type'] = type.index;
    json['account'] = account;

    return json;
  }
}
