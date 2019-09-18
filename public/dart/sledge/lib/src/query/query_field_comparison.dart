// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../document/value.dart';
import 'field_value.dart';

/// The types of comparison possible in queries on the field of a document.
enum ComparisonType {
  /// Field must be less than a given value.
  less,

  /// Field must be less than or equal to a given value.
  lessOrEqual,

  /// Field must be equal to a given value.
  equal,

  /// Field must be greater than or equal to a given value.
  greaterOrEqual,

  /// Field must be greater than a given value.
  greater
}

/// Holds the information necessary to compare to a Value:
/// It holds a comparison type (<, <=, ==, >, >=), and a value (e.g. 42).
class QueryFieldComparison {
  final FieldValue _comparisonValue;
  final ComparisonType _comparisonType;

  /// Default constructor.
  QueryFieldComparison(this._comparisonValue, this._comparisonType);

  /// Returns how [value] compares to the value stored in [this].
  bool valueMatchesComparison(Value value) {
    int comparisonResult = _comparisonValue.compareTo(value);

    // the value in [_comparisonValue] is equal to [value].
    if (comparisonResult == 0) {
      return _comparisonType == ComparisonType.equal ||
          _comparisonType == ComparisonType.lessOrEqual ||
          _comparisonType == ComparisonType.greaterOrEqual;
    }
    // the value in [_comparisonValue] is greater than [value].
    if (comparisonResult > 0) {
      return _comparisonType == ComparisonType.lessOrEqual ||
          _comparisonType == ComparisonType.less;
    }
    // the value in [_comparisonValue] is less than [value].
    return _comparisonType == ComparisonType.greaterOrEqual ||
        _comparisonType == ComparisonType.greater;
  }

  /// Returns the value stored in [this].
  FieldValue get comparisonValue => _comparisonValue;

  /// Returns the type of comparison.
  ComparisonType get comparisonType => _comparisonType;
}
