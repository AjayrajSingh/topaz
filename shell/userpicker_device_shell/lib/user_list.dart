// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.auth.fidl.account/account.fidl.dart';
import 'package:flutter/material.dart';
import 'package:lib.widgets/widgets.dart';

import 'user_picker_device_shell_model.dart';

const double _kUserAvatarSizeLarge = 56.0;
const double _kUserAvatarSizeSmall = 48.0;
const double _kButtonWidthLarge = 128.0;
const double _kButtonWidthSmall = 116.0;
const double _kButtonFontSizeLarge = 16.0;
const double _kButtonFontSizeSmall = 14.0;

final BorderRadius _kButtonBorderRadiusPhone =
    new BorderRadius.circular(_kUserAvatarSizeSmall / 2.0);
final BorderRadius _kButtonBorderRadiusLarge =
    new BorderRadius.circular(_kUserAvatarSizeLarge / 2.0);
final Color _kButtonBackgroundColor = Colors.white.withAlpha(100);

/// Shows the list of users and allows the user to add new users
class UserList extends StatelessWidget {
  Widget _buildUserCircle({
    Account account,
    VoidCallback onTap,
    bool isSmall,
  }) {
    double size = isSmall ? _kUserAvatarSizeSmall : _kUserAvatarSizeLarge;
    return new GestureDetector(
      onTap: () => onTap?.call(),
      child: new Container(
        height: size,
        width: size,
        margin: const EdgeInsets.only(left: 16.0),
        child: new Alphatar.fromNameAndUrl(
          name: account.displayName,
          avatarUrl: _getImageUrl(account),
          size: size,
        ),
      ),
    );
  }

  Widget _buildIconButton({
    VoidCallback onTap,
    bool isSmall,
    IconData icon,
  }) {
    double size = isSmall ? _kUserAvatarSizeSmall : _kUserAvatarSizeLarge;
    return _buildUserActionButton(
      onTap: () => onTap?.call(),
      width: size,
      isSmall: isSmall,
      child: new Center(
        child: new Icon(
          icon,
          color: Colors.white,
          size: size / 2.0,
        ),
      ),
    );
  }

  Widget _buildUserActionButton({
    Widget child,
    VoidCallback onTap,
    bool isSmall,
    double width,
  }) {
    return new GestureDetector(
      onTap: () => onTap?.call(),
      child: new Container(
        height: (isSmall ? _kUserAvatarSizeSmall : _kUserAvatarSizeLarge),
        width: width ?? (isSmall ? _kButtonWidthSmall : _kButtonWidthLarge),
        alignment: FractionalOffset.center,
        margin: const EdgeInsets.only(left: 16.0),
        decoration: new BoxDecoration(
          borderRadius:
              isSmall ? _kButtonBorderRadiusPhone : _kButtonBorderRadiusLarge,
          border: new Border.all(
            color: Colors.white,
            width: 1.0,
          ),
        ),
        child: child,
      ),
    );
  }

  Widget _buildExpandedUserActions({
    UserPickerDeviceShellModel model,
    bool isSmall,
  }) {
    double fontSize = isSmall ? _kButtonFontSizeSmall : _kButtonFontSizeLarge;
    return new Row(
      children: <Widget>[
        _buildIconButton(
          onTap: () => model.hideUserActions(),
          isSmall: isSmall,
          icon: Icons.close,
        ),
        _buildUserActionButton(
          child: new Text(
            'LOGIN',
            style: new TextStyle(
              fontSize: fontSize,
              color: Colors.white,
            ),
          ),
          onTap: () {
            model
              ..createAndLoginUser()
              ..hideUserActions();
          },
          isSmall: isSmall,
        ),
        _buildUserActionButton(
          child: new Text(
            'GUEST',
            style: new TextStyle(
              fontSize: fontSize,
              color: Colors.white,
            ),
          ),
          onTap: () {
            model
              ..login(null)
              ..hideUserActions();
          },
          isSmall: isSmall,
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
    bool isSmall,
    UserPickerDeviceShellModel model,
  }) {
    Widget userCard = _buildUserCircle(
      account: account,
      onTap: onTap,
      isSmall: isSmall,
    );

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
      onDragStarted: () => model.addDraggedUser(account),
      onDraggableCanceled: (_, __) => model.removeDraggedUser(account),
    );
  }

  Widget _buildUserList(UserPickerDeviceShellModel model) {
    return new LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        List<Widget> children = <Widget>[];

        bool isSmall =
            constraints.maxWidth < 600.0 || constraints.maxHeight < 600.0;

        if (model.showingUserActions) {
          children.add(_buildExpandedUserActions(
            model: model,
            isSmall: isSmall,
          ));
        } else {
          children.add(_buildIconButton(
            onTap: model.showUserActions,
            isSmall: isSmall,
            icon: Icons.add,
          ));
        }

        children.addAll(
          model.accounts.map(
            (Account account) => _buildUserEntry(
                  account: account,
                  onTap: () {
                    model
                      ..login(account.id)
                      ..hideUserActions();
                  },
                  isSmall: isSmall,
                  model: model,
                ),
          ),
        );

        return new Container(
          height:
              (isSmall ? _kUserAvatarSizeSmall : _kUserAvatarSizeLarge) + 24.0,
          child: new AnimatedOpacity(
            duration: new Duration(milliseconds: 250),
            opacity: model.showingRemoveUserTarget ? 0.0 : 1.0,
            child: new ListView(
              controller: model.userPickerScrollController,
              padding: const EdgeInsets.only(
                bottom: 24.0,
                right: 24.0,
              ),
              scrollDirection: Axis.horizontal,
              reverse: true,
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
        if (model.showingLoadingSpinner) {
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
        } else {
          return new Stack(
            fit: StackFit.passthrough,
            children: <Widget>[
              _buildUserList(model),
            ],
          );
        }
      });
}
