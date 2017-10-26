// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';

import 'context_model.dart';

class _Timezone {
  final String name;
  final String utcRelation;
  final int offsetMinutes;
  const _Timezone({this.name, this.utcRelation, this.offsetMinutes});
}

const List<_Timezone> _kTimeZones = const <_Timezone>[
  const _Timezone(utcRelation: 'UTC-12:00', offsetMinutes: -12 * 60),
  const _Timezone(utcRelation: 'UTC-11:00', offsetMinutes: -11 * 60),
  const _Timezone(utcRelation: 'UTC-10:00', offsetMinutes: -10 * 60),
  const _Timezone(utcRelation: 'UTC-09:30', offsetMinutes: -9 * 60 - 30),
  const _Timezone(utcRelation: 'UTC-09:00', offsetMinutes: -9 * 60),
  const _Timezone(utcRelation: 'UTC-08:00', offsetMinutes: -8 * 60),
  const _Timezone(utcRelation: 'UTC-07:00', offsetMinutes: -7 * 60),
  const _Timezone(utcRelation: 'UTC-06:00', offsetMinutes: -6 * 60),
  const _Timezone(utcRelation: 'UTC-05:00', offsetMinutes: -5 * 60),
  const _Timezone(utcRelation: 'UTC-04:00', offsetMinutes: -4 * 60),
  const _Timezone(utcRelation: 'UTC-03:30', offsetMinutes: -3 * 60 - 30),
  const _Timezone(utcRelation: 'UTC-03:00', offsetMinutes: -3 * 60),
  const _Timezone(utcRelation: 'UTC-02:00', offsetMinutes: -2 * 60),
  const _Timezone(utcRelation: 'UTC-01:00', offsetMinutes: -1 * 60),
  const _Timezone(utcRelation: 'UTC±00:00', offsetMinutes: 0 * 60),
  const _Timezone(utcRelation: 'UTC+01:00', offsetMinutes: 1 * 60),
  const _Timezone(utcRelation: 'UTC+02:00', offsetMinutes: 2 * 60),
  const _Timezone(utcRelation: 'UTC+03:00', offsetMinutes: 3 * 60),
  const _Timezone(utcRelation: 'UTC+03:30', offsetMinutes: 3 * 60 + 30),
  const _Timezone(utcRelation: 'UTC+04:00', offsetMinutes: 4 * 60),
  const _Timezone(utcRelation: 'UTC+04:30', offsetMinutes: 4 * 60 + 30),
  const _Timezone(utcRelation: 'UTC+05:00', offsetMinutes: 5 * 60),
  const _Timezone(utcRelation: 'UTC+05:30', offsetMinutes: 5 * 60 + 30),
  const _Timezone(utcRelation: 'UTC+05:45', offsetMinutes: 5 * 60 + 45),
  const _Timezone(utcRelation: 'UTC+06:00', offsetMinutes: 6 * 60),
  const _Timezone(utcRelation: 'UTC+06:30', offsetMinutes: 6 * 60 + 30),
  const _Timezone(utcRelation: 'UTC+07:00', offsetMinutes: 7 * 60),
  const _Timezone(utcRelation: 'UTC+08:00', offsetMinutes: 8 * 60),
  const _Timezone(utcRelation: 'UTC+08:30', offsetMinutes: 8 * 60 + 30),
  const _Timezone(utcRelation: 'UTC+08:45', offsetMinutes: 8 * 60 + 45),
  const _Timezone(utcRelation: 'UTC+09:00', offsetMinutes: 9 * 60),
  const _Timezone(utcRelation: 'UTC+09:30', offsetMinutes: 9 * 60 + 30),
  const _Timezone(utcRelation: 'UTC+10:00', offsetMinutes: 10 * 60),
  const _Timezone(utcRelation: 'UTC+10:30', offsetMinutes: 10 * 60 + 30),
  const _Timezone(utcRelation: 'UTC+11:00', offsetMinutes: 11 * 60),
  const _Timezone(utcRelation: 'UTC+12:00', offsetMinutes: 12 * 60),
  const _Timezone(utcRelation: 'UTC+12:45', offsetMinutes: 12 * 60 + 45),
  const _Timezone(utcRelation: 'UTC+13:00', offsetMinutes: 13 * 60),
  const _Timezone(utcRelation: 'UTC+14:00', offsetMinutes: 14 * 60),
];

/// Allows the selection of timezone.
class TimezonePicker extends StatelessWidget {
  @override
  Widget build(BuildContext context) => new ScopedModelDescendant<ContextModel>(
        builder: (
          BuildContext context,
          Widget child,
          ContextModel contextModel,
        ) =>
            new Stack(
              children: <Widget>[
                new Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (PointerDownEvent pointerDownEvent) {
                    contextModel.isTimezonePickerShowing = false;
                  },
                ),
                new Center(
                  child: new Material(
                    color: Colors.white,
                    borderRadius: new BorderRadius.circular(8.0),
                    elevation: 899.0,
                    child: new FractionallySizedBox(
                      heightFactor: 0.7,
                      widthFactor: 0.7,
                      child: new Container(
                        padding: const EdgeInsets.all(16.0),
                        child: new ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: _kTimeZones.length,
                          itemBuilder: (BuildContext context, int index) =>
                              new Material(
                                color: contextModel.timezoneOffsetMinutes ==
                                        _kTimeZones[index].offsetMinutes
                                    ? Colors.grey[500]
                                    : Colors.transparent,
                                child: new InkWell(
                                  onTap: () {
                                    contextModel.timezoneOffsetMinutes =
                                        _kTimeZones[index].offsetMinutes;
                                    new Timer(
                                      const Duration(milliseconds: 300),
                                      () {
                                        contextModel.isTimezonePickerShowing =
                                            false;
                                      },
                                    );
                                  },
                                  child: new Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: new Text(
                                      '${_kTimeZones[index].utcRelation}',
                                      style: new TextStyle(color: Colors.black),
                                    ),
                                  ),
                                ),
                              ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
      );
}
