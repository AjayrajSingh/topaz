// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.widgets/model.dart';
import 'package:meta/meta.dart';

import 'modular/module_model.dart';

/// Root Widget of the Eddystone Advertiser module.
class EddystoneScreen extends StatefulWidget {
  final EddystoneModuleModel moduleModel;

  EddystoneScreen({Key key, @required this.moduleModel}) : super(key: key);

  @override
  _EddystoneState createState() => new _EddystoneState();
}

typedef void RemoveCallback();

class AdvertisedListItem extends StatelessWidget {
  AdvertisedListItem({String url, this.onRemove})
      : url = url,
        super(key: new ObjectKey(url));

  final String url;
  final RemoveCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return new ListTile(
        title: new Text(url),
        trailing:
            new RaisedButton(child: new Text('STOP'), onPressed: onRemove));
  }
}

class _EddystoneState extends State<EddystoneScreen> {
  //final List<String> _advertisedUrls = [];

  final GlobalKey<FormState> _formKey = new GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return new ScopedModelDescendant<EddystoneModuleModel>(builder: (
      BuildContext context,
      Widget child,
      EddystoneModuleModel moduleModel,
    ) {
      Builder b = new Builder(builder: (BuildContext context) {
        Widget advertisingForm = new Form(
            key: _formKey,
            autovalidate: true,
            child: new Container(
                padding: const EdgeInsets.all(36.0),
                child: new Column(children: <Widget>[
                  new Row(children: <Widget>[
                    new Expanded(
                        flex: 1,
                        child: new TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Advertise URL',
                              hintText:
                                  'A URL to advertise in an Eddystone-URL beacon',
                            ),
                            validator: moduleModel.validateEddystoneUrl,
                            onSaved: (String newValue) {
                              if (moduleModel.advertisedUrls
                                  .contains(newValue)) {
                                return;
                              }
                              moduleModel.startAdvertising(newValue).catchError(
                                  (error) => Scaffold.of(context).showSnackBar(
                                      new SnackBar(
                                          content: new Text(error),
                                          backgroundColor:
                                              const Color(0xFFFFC0EB),
                                          duration:
                                              const Duration(seconds: 15))));
                            })),
                    new RaisedButton(
                        child: new Text('Advertise'),
                        onPressed: () {
                          _formKey.currentState.save();
                          _formKey.currentState.reset();
                        }),
                  ]),
                ])));
        List<Widget> widgets = [advertisingForm, new Text("Advertised URLs")];
        widgets.addAll(moduleModel.advertisedUrls.map((String url) {
          return new AdvertisedListItem(
              url: url,
              onRemove: () {
                moduleModel.stopAdvertising(url);
              });
        }));
        return new Column(children: widgets);
      });
      return new Scaffold(
          appBar: new AppBar(
            title: new Text('Eddystone Beacon'),
          ),
          body: b);
    });
  }
}
