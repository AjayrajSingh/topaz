import 'package:flutter/widgets.dart';

/// Widget that rebuilds part of the widget tree whenever
/// the [listenable] changes.
///
/// [builder] is called on [listenable] changing. [child] is not rebuilt,
/// but is passed to the [builder].
/// This has identical behavior to [AnimatedBuilder], but is clearer about
/// intent.
class ListeningBuilder extends AnimatedWidget {
  /// Constructs a new [ListeningBuilder].
  const ListeningBuilder({
    @required Listenable listenable,
    @required this.builder,
    Key key,
    this.child,
  })  : assert(builder != null),
        super(key: key, listenable: listenable);

  /// Called every time the listenable changes value.
  final TransitionBuilder builder;

  /// The child widget to pass to the [builder].
  ///
  /// If a [builder] callback's return value contains a subtree that does not
  /// depend on the listenable, it's more efficient to build that subtree once
  /// instead of rebuilding it on every change.
  ///
  /// If the pre-built subtree is passed as the [child] parameter, the
  /// [ListeningBuilder] will pass it back to the [builder] function so that it
  /// can be incorporated into the build.
  ///
  /// Using this pre-built child is entirely optional, but can improve
  /// performance significantly in some cases and is therefore a good practice.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return builder(context, child);
  }
}
