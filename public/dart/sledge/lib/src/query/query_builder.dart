import '../schema/schema.dart';
import 'field_value.dart';
import 'query.dart';
import 'query_field_comparison.dart';

/// Helper class to create Query instances.
class QueryBuilder {
  Schema _schema;
  final Map<String, QueryFieldComparison> _comparisons;

  /// Default constructor.
  /// [schema] specifies the type of Documents the Query built will operate on.
  QueryBuilder(this._schema) : _comparisons = <String, QueryFieldComparison>{};

  void _addFieldComparison(
      String fieldPath, dynamic value, ComparisonType comparison) {
    if (_comparisons.containsKey(fieldPath)) {
      throw ArgumentError(
          "Can't add multiple restrictions to the same field ($fieldPath).");
    }
    if (value is num) {
      _comparisons[fieldPath] =
          QueryFieldComparison(NumFieldValue(value), comparison);
      return;
    }
    throw ArgumentError(
        'The type `${value.runtimeType.toString()}` used on field `$fieldPath` is not supported in queries.');
  }

  /// Add a equality filter between [fieldPath] and [value].
  /// If [fieldPath] does not exist for this QueryBuilder's schema,
  /// an exception is thrown.
  /// If [value] can't be compared to the field at [fieldPath],
  /// an exception is thrown.
  void addEqual(String fieldPath, dynamic value) {
    _addFieldComparison(fieldPath, value, ComparisonType.equal);
  }

  /// Add a "greater than" filter between [fieldPath] and [value].
  /// If [fieldPath] does not exist for this QueryBuilder's schema,
  /// an exception is thrown.
  /// If [value] can't be compared to the field at [fieldPath],
  /// an exception is thrown.
  void addGreater(String fieldPath, dynamic value) {
    _addFieldComparison(fieldPath, value, ComparisonType.greater);
  }

  /// Add a "greater than or equal to" filter between [fieldPath] and [value].
  /// If [fieldPath] does not exist for this QueryBuilder's schema,
  /// an exception is thrown.
  /// If [value] can't be compared to the field at [fieldPath],
  /// an exception is thrown.
  void addGreaterOrEqual(String fieldPath, dynamic value) {
    _addFieldComparison(fieldPath, value, ComparisonType.greaterOrEqual);
  }

  /// Add a "less than" filter between [fieldPath] and [value].
  /// If [fieldPath] does not exist for this QueryBuilder's schema,
  /// an exception is thrown.
  /// If [value] can't be compared to the field at [fieldPath],
  /// an exception is thrown.
  void addLess(String fieldPath, dynamic value) {
    _addFieldComparison(fieldPath, value, ComparisonType.less);
  }

  /// Add a "less than or equal to" filter between [fieldPath] and [value].
  /// If [fieldPath] does not exist for this QueryBuilder's schema,
  /// an exception is thrown.
  /// If [value] can't be compared to the field at [fieldPath],
  /// an exception is thrown.
  void addLessOrEqual(String fieldPath, dynamic value) {
    _addFieldComparison(fieldPath, value, ComparisonType.lessOrEqual);
  }

  /// Returns a new Query possessing all the filters previously added to this.
  Query build() {
    return Query(_schema, comparisons: _comparisons);
  }
}
