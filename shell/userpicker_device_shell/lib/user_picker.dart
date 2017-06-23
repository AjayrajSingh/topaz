// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:apps.modular.services.auth.account/account.fidl.dart';
import 'package:apps.modular.services.device/user_provider.fidl.dart';
import 'package:flutter/material.dart';
import 'package:lib.widgets/widgets.dart';

import 'user_picker_device_shell_model.dart';

const String _kGuestUserName = 'Guest';
const String _kDefaultServerName = 'ledger.fuchsia.com';
const Color _kFuchsiaColor = const Color(0xFFFF0080);
const double _kButtonContentWidth = 220.0;
const double _kButtonContentHeight = 80.0;
const double _kUserCardHeight = 188.0;

/// Called when the user wants to login as [accountId] using [userProvider].
typedef void OnLoginRequest(String accountId, UserProvider userProvider);

/// See [UserPicker.onUserDragStarted].
typedef void OnUserDragStarted(Account account);

/// See [UserPicker.onUserDragCanceled].
typedef void OnUserDragCanceled(Account account);

/// Provides a UI for picking a user.
class UserPicker extends StatelessWidget {
  /// Called when the user want's to log in.
  final OnLoginRequest onLoginRequest;

  /// Indicates if the user is currently logging in.
  final bool loggingIn;

  /// Called when a user starts being dragged.
  final OnUserDragStarted onUserDragStarted;

  /// Called when a user cancels its drag.
  final OnUserDragCanceled onUserDragCanceled;

  /// Constructor.
  UserPicker({
    this.onLoginRequest,
    this.loggingIn,
    this.onUserDragStarted,
    this.onUserDragCanceled,
  });

  Widget _buildUserCard({Account account, VoidCallback onTap}) => new Material(
        color: Colors.black.withAlpha(0),
        child: new InkWell(
          highlightColor: Colors.transparent,
          onTap: () => onTap(),
          borderRadius: new BorderRadius.all(new Radius.circular(8.0)),
          child: new Container(
            margin: const EdgeInsets.all(16.0),
            padding: const EdgeInsets.all(16.0),
            child: new Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                new Container(
                  padding: const EdgeInsets.all(2.0),
                  decoration: new BoxDecoration(
                    borderRadius: new BorderRadius.all(
                      new Radius.circular(40.0),
                    ),
                    color: Colors.white,
                  ),
                  child: new Alphatar.fromNameAndUrl(
                    name: account.displayName,
                    avatarUrl: _getImageUrl(account),
                    size: 80.0,
                  ),
                ),
                new Container(
                  margin: const EdgeInsets.only(top: 16.0),
                  padding: const EdgeInsets.all(4.0),
                  decoration: new BoxDecoration(
                    borderRadius:
                        new BorderRadius.all(new Radius.circular(4.0)),
                    color: Colors.black.withAlpha(240),
                  ),
                  child: new Text(
                    account.displayName.toUpperCase(),
                    style: new TextStyle(
                      color: Colors.grey[300],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  String _getImageUrl(Account account) {
    if (account.imageUrl == null) {
      return null;
    }
    Uri uri = Uri.parse(account.imageUrl);
    if (uri.queryParameters['sz'] != null) {
      Map<String, dynamic> queryParameters = new Map<String, dynamic>.from(
        uri.queryParameters,
      );
      queryParameters['sz'] = '160';
      uri = uri.replace(queryParameters: queryParameters);
    }
    return uri.toString();
  }

  Widget _buildUserEntry({
    Account account,
    VoidCallback onTap,
    bool removable: true,
  }) {
    Widget userCard = _buildUserCard(account: account, onTap: onTap);

    if (!removable) {
      return userCard;
    }

    return new LongPressDraggable<Account>(
      child: userCard,
      feedback: userCard,
      data: account,
      childWhenDragging: new Opacity(opacity: 0.0, child: userCard),
      feedbackOffset: Offset.zero,
      dragAnchor: DragAnchor.child,
      maxSimultaneousDrags: 1,
      onDragStarted: () => onUserDragStarted?.call(account),
      onDraggableCanceled: (_, __) => onUserDragCanceled?.call(account),
    );
  }

  Widget _buildUserList(UserPickerDeviceShellModel model) {
    List<Widget> children = <Widget>[];
    // Default entry.
    children.add(
      _buildUserEntry(
        account: new Account()..displayName = _kGuestUserName,
        onTap: () => _loginUser(null, model),
        removable: false,
      ),
    );
    children.addAll(
      model.accounts.map(
        (Account account) => _buildUserEntry(
              account: account,
              onTap: () => _loginUser(account.id, model),
            ),
      ),
    );

    return new Container(
      height: _kUserCardHeight,
      child: new ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        shrinkWrap: true,
        children: children,
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      new ScopedModelDescendant<UserPickerDeviceShellModel>(builder: (
        BuildContext context,
        Widget child,
        UserPickerDeviceShellModel model,
      ) {
        if (model.accounts != null && !loggingIn && model.showingNetworkInfo) {
          return new Stack(
            fit: StackFit.passthrough,
            children: <Widget>[
              new Center(child: _buildUserList(model)),
            ],
          );
        } else {
          return new Container(
            width: 64.0,
            height: 64.0,
            child: new FuchsiaSpinner(),
          );
        }
      });

  void _loginUser(String accountId, UserPickerDeviceShellModel model) =>
      onLoginRequest?.call(accountId, model.userProvider);
}
