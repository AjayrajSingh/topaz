// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fixtures/fixtures.dart';

import 'artist.dart';
import 'event.dart';
import 'venue.dart';

/// Fixtures for Concerts
class MusicModelFixtures extends Fixtures {
  /// Generate an artist
  Artist artist() {
    return new Artist(name: 'Vampire Weekend', id: 288696);
  }

  /// Generate a venue
  Venue venue() {
    return new Venue(
      name: 'O2 Academy Brixton',
      description:
          'Brixton Academy is an award winning music venue situated in the heart of Brixton, South London. The venue has played host to many notable shows and reunions, welcoming a wide variety of artists, from Bob Dylan to Eminem, to the stage. It attracts over half a million visitors per year, accommodating over one hundred events.\n\nBuilt in 1929, the site started life as one of the four state of the art\n Astoria Theaters, screening a variety of motion pictures and shows. In 1972 the venue was transformed into a rock venue and re-branded as The Sundown Centre. With limited success the venue closed it’s doors in 1974 and was not re-opened as a music venue again until 1983, when it became The Brixton Academy.\n\nFeaturing a beautiful Art Deco interior, the venue is now known as the 02 Academy Brixton, and hosts a diverse range of club nights and live performances, as well as seated events. The venue has an upstairs balcony as well as the main floor downstairs. There is disabled access and facilities, a bar and a cloakroom. Club night events are for over 18s, for live music under 14s must be accompanied by an adult.',
      website: 'http://www.brixton-academy.co.uk/',
      metroArea: new MetroArea(
        name: 'London',
        country: 'UK',
        id: 24426,
      ),
      city: new City(
        name: 'London',
        country: 'UK',
        id: 24426,
      ),
      street: '211 Stockwell Road',
      zip: 'SW9 9SL',
      phoneNumber: '020 7771 3000',
      id: 17522,
    );
  }

  /// Generate an event
  Event event() {
    return new Event(
      name:
          'Vampire Weekend with Fan Death at O2 Academy Brixton (February 16, 2010)',
      type: 'Concert',
      startTime: DateTime.parse('2010-02-16T19:30:00+0000'),
      venue: venue(),
      performances: <Performance>[
        new Performance(
          billing: 'headline',
          billingIndex: 1,
          name: 'Vampire Weekend',
          artist: artist(),
          id: 5380281,
        ),
        new Performance(
          billing: 'support',
          billingIndex: 2,
          name: 'Fan Death',
          artist: new Artist(
            name: 'Fan Death',
            id: 2357033,
          ),
          id: 7863371,
        )
      ],
      id: 3037536,
    );
  }
}
