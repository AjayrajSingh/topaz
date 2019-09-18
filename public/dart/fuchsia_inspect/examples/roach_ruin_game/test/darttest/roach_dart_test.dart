import 'package:test/test.dart';
import 'package:fuchsia_inspect/inspect.dart' as inspect;
import 'package:roach_ruin/roachLogic.dart';
import 'package:mockito/mockito.dart';

class MockNode extends Mock implements inspect.Node {}

void main() {
  test('Counter increments', () async {
    int counter = 0;
    RoachLogic roachLogic = RoachLogic();
    counter = roachLogic.increaseCounter(counter);
    expect(counter, 1);
  });

  test('Change hammer boolean', () async {
    bool hammer = true;
    RoachLogic roachLogic = RoachLogic();
    hammer = roachLogic.changeHammer(hamIsUp: hammer);
    expect(hammer, false);
  });

  test('Hammer Up path is correct', () async {
    RoachLogic roachLogic = RoachLogic();
    String hammerUpImage = roachLogic.hammerUpright();
    expect(hammerUpImage, roachLogic.hamU);
  });

  test('Hammer Down path is correct', () async {
    RoachLogic roachLogic = RoachLogic();
    String hammerDownImage = roachLogic.hammerDown();
    expect(hammerDownImage, roachLogic.hamD);
  });

  test('Roach Alive path is correct', () async {
    RoachLogic roachLogic = RoachLogic();
    String roachLive = roachLogic.roachLiving();
    expect(roachLive, roachLogic.roachLive);
  });

  test('Roach Dead path is correct', () async {
    RoachLogic roachLogic = RoachLogic();
    String roachDead = roachLogic.roachNotLiving();
    expect(roachDead, roachLogic.roachDead);
  });
}
