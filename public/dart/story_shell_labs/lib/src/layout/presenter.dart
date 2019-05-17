// Depends on the implementation of the Layout and the Presenter.
// Owned by the Presenter because multiple layouts can use the same
// Presenter.

import 'layout.dart';

/// Renders the layout. Can be used by multiple strategies that use the same
/// PresentationModel.
abstract class Presenter<T> {
  /// Called when a surface is removed.
  RemoveSurfaceCallback removeSurfaceCallback;

  /// Called when the focus changes.
  FocusChangeCallback changeFocusCallback;

  /// Constructor for a presenter.
  Presenter({
    this.removeSurfaceCallback,
    this.changeFocusCallback,
  });

  /// Notify the presenter of a layout change.
  void onLayoutChange(T layoutModer);

  /// Instructs to remove a surface.
  void removeSurface(Iterable<String> surfaces) =>
      removeSurfaceCallback(surfaces);

  /// Instructs to change the focus of a surface.
  void changeFocus(String surface, {bool focus = false}) =>
      changeFocusCallback(surface, focus);
}
