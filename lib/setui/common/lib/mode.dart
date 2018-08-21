/// Class used to control which features should be shown during the OOBE flow.
///
/// The Experiments framework cannot be used for this since it happens before
/// experiments can be set.
class SetUiMode {
  static SetUiMode _globalInstance;
  final bool _isDebug;

  factory SetUiMode() {
    return _globalInstance ??= SetUiMode._internal();
  }

  SetUiMode._internal() : _isDebug = _isAssert();

  // We currently rely in assert to see if we are in debug or
  // release mode. In future, we will use config files.
  static bool _isAssert() {
    bool isAssert = false;
    assert(isAssert = true);
    return isAssert;
  }

  Mode get mode => _isDebug ? Mode.debug : Mode.normal;
}

enum Mode {
  normal,
  debug,
}
