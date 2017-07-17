// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:apps.modular.services.auth.account/account.fidl.dart';
import 'package:apps.modular.services.device/user_provider.fidl.dart';
import 'package:flutter/material.dart';
import 'package:lib.widgets/widgets.dart';

import 'user_picker_device_shell_model.dart';

const double _kUserAvatarSize = 64.0;
final BorderRadius _kButtonBorderRadius =
    new BorderRadius.circular(_kUserAvatarSize / 2.0);
final Color _kButtonBackgroundColor = Colors.white.withAlpha(100);

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

  /// Called when the add user button is pressed.
  final VoidCallback onAddUser;

  /// Flag for when user is being dragged
  final bool userDragged;

  /// Constructor.
  UserPicker({
    this.onLoginRequest,
    this.loggingIn,
    this.onUserDragStarted,
    this.onUserDragCanceled,
    this.onAddUser,
    this.userDragged,
  });

  Widget _buildUserCircle({
    Account account,
    VoidCallback onTap,
  }) {
    return new GestureDetector(
      onTap: () => onTap?.call(),
      child: new Container(
        height: _kUserAvatarSize,
        width: _kUserAvatarSize,
        margin: const EdgeInsets.only(right: 16.0),
        child: new Alphatar.fromNameAndUrl(
          name: account.displayName,
          avatarUrl: _getImageUrl(account),
          size: _kUserAvatarSize,
        ),
      ),
    );
  }

  Widget _buildNewUserButton({VoidCallback onTap}) {
    return new GestureDetector(
      onTap: () => onTap?.call(),
      child: new Container(
        height: _kUserAvatarSize,
        width: _kUserAvatarSize,
        decoration: new BoxDecoration(
          borderRadius: _kButtonBorderRadius,
          color: _kButtonBackgroundColor,
        ),
        child: new Center(
          child: new Icon(
            Icons.add,
            color: Colors.grey[300].withAlpha(200),
            size: _kUserAvatarSize / 2.0,
          ),
        ),
      ),
    );
  }

  Widget _buildUserActionButton({
    String text,
    VoidCallback onTap,
  }) {
    return new GestureDetector(
      onTap: () => onTap?.call(),
      child: new Container(
        height: _kUserAvatarSize,
        alignment: FractionalOffset.center,
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        margin: const EdgeInsets.only(right: 16.0),
        decoration: new BoxDecoration(
          borderRadius: _kButtonBorderRadius,
          color: _kButtonBackgroundColor,
        ),
        child: new Text(
          text,
          style: new TextStyle(
            fontSize: 16.0,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildUserActions(UserPickerDeviceShellModel model) {
    return new Row(
      children: <Widget>[
        _buildUserActionButton(
            text: 'NEW',
            onTap: () {
              onAddUser?.call();
              model.hideUserActions();
            }),
        _buildUserActionButton(
          text: 'GUEST',
          onTap: () {
            _loginUser(null, model);
            model.hideUserActions();
          },
        ),
      ],
    );
  }

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
    Widget userCard = _buildUserCircle(account: account, onTap: onTap);

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
    return new LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        List<Widget> children = <Widget>[];

        if (!model.showingUserActions || constraints.maxWidth > 600.0) {
          children.addAll(
            model.accounts.map(
              (Account account) => _buildUserEntry(
                    account: account,
                    onTap: () {
                      _loginUser(account.id, model);
                      model.hideUserActions();
                    },
                  ),
            ),
          );
        }

        if (model.showingUserActions) {
          children.add(_buildUserActions(model));
        } else {
          children.add(_buildNewUserButton(
            onTap: model.showUserActions,
          ));
        }

        return new Container(
          margin: const EdgeInsets.only(
            bottom: 16.0,
            left: 16.0,
          ),
          height: _kUserAvatarSize,
          child: new AnimatedOpacity(
            duration: new Duration(milliseconds: 250),
            opacity: userDragged ? 0.0 : 1.0,
            child: new ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              shrinkWrap: true,
              children: children,
            ),
          ),
        );
      },
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
              _buildUserList(model),
            ],
          );
        } else {
          return new Stack(
            fit: StackFit.passthrough,
            children: <Widget>[
              new Center(
                child: new Container(
                  width: 64.0,
                  height: 64.0,
                  child: new FuchsiaSpinner(),
                ),
              ),
            ],
          );
        }
      });

  void _loginUser(String accountId, UserPickerDeviceShellModel model) =>
      onLoginRequest?.call(accountId, model.userProvider);
}
