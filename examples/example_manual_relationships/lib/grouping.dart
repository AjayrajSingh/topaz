import 'package:flutter/widgets.dart';

/// White box grouping
class Grouping extends StatelessWidget {
  /// The children in this grouping
  final List<Widget> children;

  /// Construct Grouping
  const Grouping({this.children});

  @override
  Widget build(BuildContext context) {
    return new Container(
      color: const Color(0xFFFFFFFF),
      margin: const EdgeInsets.all(10.0),
      padding: const EdgeInsets.all(10.0),
      child: new Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: children,
      ),
    );
  }
}
