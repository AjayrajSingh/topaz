import 'package:flutter_test/flutter_test.dart';
import 'package:fuchsia_inspect/inspect.dart' as inspect;
import 'package:roach_ruin/roachGame.dart';
import 'package:mockito/mockito.dart';

class MockNode extends Mock implements inspect.Node {}

void main() {
  testWidgets('Title Widget Test', (WidgetTester tester) async {
    await tester.pumpWidget(RoachGame(inspectNode: mockNode));
    final appbarFinder = find.text('Welcome to Roach Ruin');
    expect(appbarFinder, findsOneWidget);
  });

  testWidgets('Button Widget Test', (WidgetTester tester) async {
    var mockNode = MockNode();
    await tester.pumpWidget(RoachGame(inspectNode: mockNode));
    RoachLogic roachLogic = RoachLogic();
    roachLogic.increaseCounter(1);
  });
}
