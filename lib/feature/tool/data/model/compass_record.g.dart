// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'compass_record.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetCompassRecordCollection on Isar {
  IsarCollection<CompassRecord> get compassRecords => this.collection();
}

const CompassRecordSchema = CollectionSchema(
  name: r'CompassRecord',
  id: 4942452934537186085,
  properties: {
    r'altitude': PropertySchema(
      id: 0,
      name: r'altitude',
      type: IsarType.double,
    ),
    r'cardinalAbbrev': PropertySchema(
      id: 1,
      name: r'cardinalAbbrev',
      type: IsarType.string,
    ),
    r'cardinalName': PropertySchema(
      id: 2,
      name: r'cardinalName',
      type: IsarType.string,
    ),
    r'createdAt': PropertySchema(
      id: 3,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'heading': PropertySchema(id: 4, name: r'heading', type: IsarType.double),
    r'latitude': PropertySchema(
      id: 5,
      name: r'latitude',
      type: IsarType.double,
    ),
    r'longitude': PropertySchema(
      id: 6,
      name: r'longitude',
      type: IsarType.double,
    ),
    r'name': PropertySchema(id: 7, name: r'name', type: IsarType.string),
  },

  estimateSize: _compassRecordEstimateSize,
  serialize: _compassRecordSerialize,
  deserialize: _compassRecordDeserialize,
  deserializeProp: _compassRecordDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},

  getId: _compassRecordGetId,
  getLinks: _compassRecordGetLinks,
  attach: _compassRecordAttach,
  version: '3.3.2',
);

int _compassRecordEstimateSize(
  CompassRecord object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.cardinalAbbrev.length * 3;
  bytesCount += 3 + object.cardinalName.length * 3;
  bytesCount += 3 + object.name.length * 3;
  return bytesCount;
}

void _compassRecordSerialize(
  CompassRecord object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDouble(offsets[0], object.altitude);
  writer.writeString(offsets[1], object.cardinalAbbrev);
  writer.writeString(offsets[2], object.cardinalName);
  writer.writeDateTime(offsets[3], object.createdAt);
  writer.writeDouble(offsets[4], object.heading);
  writer.writeDouble(offsets[5], object.latitude);
  writer.writeDouble(offsets[6], object.longitude);
  writer.writeString(offsets[7], object.name);
}

CompassRecord _compassRecordDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = CompassRecord(
    altitude: reader.readDoubleOrNull(offsets[0]),
    cardinalAbbrev: reader.readString(offsets[1]),
    cardinalName: reader.readString(offsets[2]),
    createdAt: reader.readDateTime(offsets[3]),
    heading: reader.readDouble(offsets[4]),
    latitude: reader.readDoubleOrNull(offsets[5]),
    longitude: reader.readDoubleOrNull(offsets[6]),
    name: reader.readString(offsets[7]),
  );
  object.id = id;
  return object;
}

P _compassRecordDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDoubleOrNull(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readDateTime(offset)) as P;
    case 4:
      return (reader.readDouble(offset)) as P;
    case 5:
      return (reader.readDoubleOrNull(offset)) as P;
    case 6:
      return (reader.readDoubleOrNull(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _compassRecordGetId(CompassRecord object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _compassRecordGetLinks(CompassRecord object) {
  return [];
}

void _compassRecordAttach(
  IsarCollection<dynamic> col,
  Id id,
  CompassRecord object,
) {
  object.id = id;
}

extension CompassRecordQueryWhereSort
    on QueryBuilder<CompassRecord, CompassRecord, QWhere> {
  QueryBuilder<CompassRecord, CompassRecord, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension CompassRecordQueryWhere
    on QueryBuilder<CompassRecord, CompassRecord, QWhereClause> {
  QueryBuilder<CompassRecord, CompassRecord, QAfterWhereClause> idEqualTo(
    Id id,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterWhereClause> idNotEqualTo(
    Id id,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension CompassRecordQueryFilter
    on QueryBuilder<CompassRecord, CompassRecord, QFilterCondition> {
  QueryBuilder<CompassRecord, CompassRecord, QAfterFilterCondition>
  altitudeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'altitude'),
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterFilterCondition>
  altitudeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'altitude'),
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterFilterCondition>
  altitudeEqualTo(double? value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'altitude',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterFilterCondition>
  altitudeGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'altitude',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterFilterCondition>
  altitudeLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'altitude',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterFilterCondition>
  altitudeBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'altitude',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterFilterCondition>
  cardinalAbbrevEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'cardinalAbbrev',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterFilterCondition>
  cardinalAbbrevGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'cardinalAbbrev',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterFilterCondition>
  cardinalAbbrevLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'cardinalAbbrev',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterFilterCondition>
  cardinalAbbrevBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'cardinalAbbrev',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterFilterCondition>
  cardinalAbbrevStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'cardinalAbbrev',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterFilterCondition>
  cardinalAbbrevEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'cardinalAbbrev',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterFilterCondition>
  cardinalAbbrevContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'cardinalAbbrev',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterFilterCondition>
  cardinalAbbrevMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'cardinalAbbrev',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterFilterCondition>
  cardinalAbbrevIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'cardinalAbbrev', value: ''),
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterFilterCondition>
  cardinalAbbrevIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'cardinalAbbrev', value: ''),
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterFilterCondition>
  cardinalNameEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'cardinalName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterFilterCondition>
  cardinalNameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'cardinalName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterFilterCondition>
  cardinalNameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'cardinalName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterFilterCondition>
  cardinalNameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'cardinalName',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterFilterCondition>
  cardinalNameStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'cardinalName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterFilterCondition>
  cardinalNameEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'cardinalName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterFilterCondition>
  cardinalNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'cardinalName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterFilterCondition>
  cardinalNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'cardinalName',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterFilterCondition>
  cardinalNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'cardinalName', value: ''),
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterFilterCondition>
  cardinalNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'cardinalName', value: ''),
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterFilterCondition>
  createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'createdAt', value: value),
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterFilterCondition>
  createdAtGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'createdAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterFilterCondition>
  createdAtLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'createdAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterFilterCondition>
  createdAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'createdAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterFilterCondition>
  headingEqualTo(double value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'heading',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterFilterCondition>
  headingGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'heading',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterFilterCondition>
  headingLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'heading',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterFilterCondition>
  headingBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'heading',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterFilterCondition> idEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterFilterCondition>
  idGreaterThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterFilterCondition>
  latitudeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'latitude'),
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterFilterCondition>
  latitudeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'latitude'),
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterFilterCondition>
  latitudeEqualTo(double? value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'latitude',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterFilterCondition>
  latitudeGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'latitude',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterFilterCondition>
  latitudeLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'latitude',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterFilterCondition>
  latitudeBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'latitude',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterFilterCondition>
  longitudeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'longitude'),
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterFilterCondition>
  longitudeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'longitude'),
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterFilterCondition>
  longitudeEqualTo(double? value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'longitude',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterFilterCondition>
  longitudeGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'longitude',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterFilterCondition>
  longitudeLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'longitude',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterFilterCondition>
  longitudeBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'longitude',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterFilterCondition> nameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterFilterCondition>
  nameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterFilterCondition>
  nameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterFilterCondition> nameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'name',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterFilterCondition>
  nameStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterFilterCondition>
  nameEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterFilterCondition>
  nameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterFilterCondition> nameMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'name',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterFilterCondition>
  nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'name', value: ''),
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterFilterCondition>
  nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'name', value: ''),
      );
    });
  }
}

extension CompassRecordQueryObject
    on QueryBuilder<CompassRecord, CompassRecord, QFilterCondition> {}

extension CompassRecordQueryLinks
    on QueryBuilder<CompassRecord, CompassRecord, QFilterCondition> {}

extension CompassRecordQuerySortBy
    on QueryBuilder<CompassRecord, CompassRecord, QSortBy> {
  QueryBuilder<CompassRecord, CompassRecord, QAfterSortBy> sortByAltitude() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'altitude', Sort.asc);
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterSortBy>
  sortByAltitudeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'altitude', Sort.desc);
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterSortBy>
  sortByCardinalAbbrev() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cardinalAbbrev', Sort.asc);
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterSortBy>
  sortByCardinalAbbrevDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cardinalAbbrev', Sort.desc);
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterSortBy>
  sortByCardinalName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cardinalName', Sort.asc);
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterSortBy>
  sortByCardinalNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cardinalName', Sort.desc);
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterSortBy>
  sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterSortBy> sortByHeading() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'heading', Sort.asc);
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterSortBy> sortByHeadingDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'heading', Sort.desc);
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterSortBy> sortByLatitude() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'latitude', Sort.asc);
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterSortBy>
  sortByLatitudeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'latitude', Sort.desc);
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterSortBy> sortByLongitude() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'longitude', Sort.asc);
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterSortBy>
  sortByLongitudeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'longitude', Sort.desc);
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterSortBy> sortByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterSortBy> sortByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }
}

extension CompassRecordQuerySortThenBy
    on QueryBuilder<CompassRecord, CompassRecord, QSortThenBy> {
  QueryBuilder<CompassRecord, CompassRecord, QAfterSortBy> thenByAltitude() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'altitude', Sort.asc);
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterSortBy>
  thenByAltitudeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'altitude', Sort.desc);
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterSortBy>
  thenByCardinalAbbrev() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cardinalAbbrev', Sort.asc);
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterSortBy>
  thenByCardinalAbbrevDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cardinalAbbrev', Sort.desc);
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterSortBy>
  thenByCardinalName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cardinalName', Sort.asc);
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterSortBy>
  thenByCardinalNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cardinalName', Sort.desc);
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterSortBy>
  thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterSortBy> thenByHeading() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'heading', Sort.asc);
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterSortBy> thenByHeadingDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'heading', Sort.desc);
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterSortBy> thenByLatitude() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'latitude', Sort.asc);
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterSortBy>
  thenByLatitudeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'latitude', Sort.desc);
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterSortBy> thenByLongitude() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'longitude', Sort.asc);
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterSortBy>
  thenByLongitudeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'longitude', Sort.desc);
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterSortBy> thenByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QAfterSortBy> thenByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }
}

extension CompassRecordQueryWhereDistinct
    on QueryBuilder<CompassRecord, CompassRecord, QDistinct> {
  QueryBuilder<CompassRecord, CompassRecord, QDistinct> distinctByAltitude() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'altitude');
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QDistinct>
  distinctByCardinalAbbrev({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'cardinalAbbrev',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QDistinct> distinctByCardinalName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cardinalName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QDistinct> distinctByHeading() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'heading');
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QDistinct> distinctByLatitude() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'latitude');
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QDistinct> distinctByLongitude() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'longitude');
    });
  }

  QueryBuilder<CompassRecord, CompassRecord, QDistinct> distinctByName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'name', caseSensitive: caseSensitive);
    });
  }
}

extension CompassRecordQueryProperty
    on QueryBuilder<CompassRecord, CompassRecord, QQueryProperty> {
  QueryBuilder<CompassRecord, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<CompassRecord, double?, QQueryOperations> altitudeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'altitude');
    });
  }

  QueryBuilder<CompassRecord, String, QQueryOperations>
  cardinalAbbrevProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cardinalAbbrev');
    });
  }

  QueryBuilder<CompassRecord, String, QQueryOperations> cardinalNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cardinalName');
    });
  }

  QueryBuilder<CompassRecord, DateTime, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<CompassRecord, double, QQueryOperations> headingProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'heading');
    });
  }

  QueryBuilder<CompassRecord, double?, QQueryOperations> latitudeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'latitude');
    });
  }

  QueryBuilder<CompassRecord, double?, QQueryOperations> longitudeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'longitude');
    });
  }

  QueryBuilder<CompassRecord, String, QQueryOperations> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'name');
    });
  }
}
