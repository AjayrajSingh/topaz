import 'package:lib.widgets/model.dart';

class ScoreBoardModel extends Model {
  int _xScore;
  int _oScore;

  ScoreBoardModel();

  void setScore(int xScore, int oScore) {
    _xScore = xScore;
    _oScore = oScore;
    notifyListeners();
  }

  String get xScore {
    return _xScore?.toString() ?? '';
  }

  String get oScore {
    return _oScore?.toString() ?? '';
  }
}
