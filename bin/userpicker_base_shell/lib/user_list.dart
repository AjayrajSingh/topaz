// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_modular_auth/fidl.dart';
import 'package:flutter/material.dart';
import 'package:lib.widgets/model.dart';
import 'package:lib.widgets/widgets.dart';

import 'user_picker_base_shell_model.dart';

const double _kUserAvatarSizeLarge = 56.0;
const double _kUserAvatarSizeSmall = 48.0;
const double _kButtonWidthLarge = 128.0;
const double _kButtonWidthSmall = 116.0;
const double _kButtonFontSizeLarge = 16.0;
const double _kButtonFontSizeSmall = 14.0;

const TextStyle _kTextStyle = const TextStyle(
  color: Colors.white,
  fontSize: 10.0,
  letterSpacing: 1.0,
  fontWeight: FontWeight.w300,
);

final BorderRadius _kButtonBorderRadiusPhone =
    new BorderRadius.circular(_kUserAvatarSizeSmall / 2.0);
final BorderRadius _kButtonBorderRadiusLarge =
    new BorderRadius.circular(_kUserAvatarSizeLarge / 2.0);

/// Shows the list of users and allows the user to add new users
class UserList extends StatelessWidget {
  /// True if login should be disabled.
  final bool loginDisabled;

  /// Constructor.
  const UserList({this.loginDisabled = false});

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
    bool isDisabled = false,
  }) {
    return new GestureDetector(
      onTap: isDisabled ? null : () => onTap?.call(),
      child: new Container(
        height: isSmall ? _kUserAvatarSizeSmall : _kUserAvatarSizeLarge,
        width: width ?? (isSmall ? _kButtonWidthSmall : _kButtonWidthLarge),
        alignment: FractionalOffset.center,
        margin: const EdgeInsets.only(left: 16.0),
        decoration: new BoxDecoration(
          borderRadius:
              isSmall ? _kButtonBorderRadiusPhone : _kButtonBorderRadiusLarge,
          border: new Border.all(
            color: isDisabled ? Colors.grey : Colors.white,
            width: 1.0,
          ),
        ),
        child: child,
      ),
    );
  }

  Widget _buildExpandedUserActions({
    UserPickerBaseShellModel model,
    bool isSmall,
  }) {
    double fontSize = isSmall ? _kButtonFontSizeSmall : _kButtonFontSizeLarge;

    if (loginDisabled) {
      return new Row(
        children: <Widget>[
          _buildUserActionButton(
            child: new Text(
              'RESET',
              style: new TextStyle(
                fontSize: fontSize,
                color: Colors.white,
              ),
            ),
            onTap: model.resetTapped,
            isSmall: isSmall,
          ),
          _buildUserActionButton(
            child: new Text(
              'WIFI',
              style: new TextStyle(
                fontSize: fontSize,
                color: Colors.white,
              ),
            ),
            onTap: model.wifiTapped,
            isSmall: isSmall,
          ),
          _buildUserActionButton(
            child: new Text(
              'LOGIN DISABLED => No UserShell configured',
              style: new TextStyle(
                fontSize: fontSize,
                color: Colors.white,
              ),
            ),
            onTap: () {},
            isSmall: isSmall,
            isDisabled: true,
          ),
        ],
      );
    }
    return new Row(
      children: <Widget>[
        _buildIconButton(
          onTap: () => model.hideUserActions(),
          isSmall: isSmall,
          icon: Icons.close,
        ),
        _buildUserActionButton(
          child: new Text(
            'RESET',
            style: new TextStyle(
              fontSize: fontSize,
              color: Colors.white,
            ),
          ),
          onTap: model.resetTapped,
          isSmall: isSmall,
        ),
        _buildUserActionButton(
          child: new Text(
            'WIFI',
            style: new TextStyle(
              fontSize: fontSize,
              color: Colors.white,
            ),
          ),
          onTap: model.wifiTapped,
          isSmall: isSmall,
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
    bool removable = true,
    bool isSmall,
    UserPickerBaseShellModel model,
  }) {
    Widget userCard = _buildUserCircle(
      account: account,
      onTap: onTap,
      isSmall: isSmall,
    );

    if (!removable) {
      return userCard;
    }

    Widget userImage = new LongPressDraggable<Account>(
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

    if (model.showingUserActions) {
      return new Padding(
        padding: const EdgeInsets.only(left: 16.0),
        child: new Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            new Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: new Text(
                account.displayName,
                textAlign: TextAlign.center,
                maxLines: 1,
                style: _kTextStyle,
              ),
            ),
            userImage,
          ],
        ),
      );
    } else {
      return new Padding(
        padding: const EdgeInsets.only(left: 16.0),
        child: userImage,
      );
    }
  }

  Widget _buildUserList(UserPickerBaseShellModel model) {
    return new LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        List<Widget> children = <Widget>[];

        bool isSmall =
            constraints.maxWidth < 600.0 || constraints.maxHeight < 600.0;

        if (model.showingUserActions) {
          children.add(
            new Align(
              alignment: FractionalOffset.bottomCenter,
              child: _buildExpandedUserActions(
                model: model,
                isSmall: isSmall,
              ),
            ),
          );
        } else {
          children.add(
            new Align(
              alignment: FractionalOffset.bottomCenter,
              child: _buildIconButton(
                onTap: model.showUserActions,
                isSmall: isSmall,
                icon: Icons.add,
              ),
            ),
          );
        }

        children.addAll(
          model.accounts.map(
            (Account account) => new Align(
                  alignment: FractionalOffset.bottomCenter,
                  child: _buildUserEntry(
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
          ),
        );

        return new Container(
          height: (isSmall ? _kUserAvatarSizeSmall : _kUserAvatarSizeLarge) +
              24.0 +
              (model.showingUserActions ? 24.0 : 0.0),
          child: new AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: model.showingRemoveUserTarget ? 0.0 : 1.0,
            child: new ListView(
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
      new ScopedModelDescendant<UserPickerBaseShellModel>(builder: (
        BuildContext context,
        Widget child,
        UserPickerBaseShellModel model,
      ) {
        if (model.showingLoadingSpinner) {
          return new Stack(
            fit: StackFit.passthrough,
            children: <Widget>[
              new Center(
                child: new Container(
                  width: 64.0,
                  height: 64.0,
                  child: const FuchsiaSpinner(),
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
