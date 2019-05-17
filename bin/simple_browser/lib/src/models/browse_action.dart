// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart';

// Base class for actions handled by the application's BLOC
class BrowseAction {
  final BrowseActionType op;
  const BrowseAction(this.op);
}

// Operations allowed for browsing
enum BrowseActionType { goForward, goBack, navigateTo }

// Instructs to go to the next page.
class GoForwardAction extends BrowseAction {
  const GoForwardAction() : super(BrowseActionType.goForward);
}

// Instructs to go to the previous page.
class GoBackAction extends BrowseAction {
  const GoBackAction() : super(BrowseActionType.goBack);
}

// Instructs to navigate to some url.
class NavigateToAction extends BrowseAction {
  final String url;
  NavigateToAction({@required this.url}) : super(BrowseActionType.navigateTo);
}
