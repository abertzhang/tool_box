// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tide_record.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetTideRecordCollection on Isar {
  IsarCollection<TideRecord> get tideRecords => this.collection();
}

const TideRecordSchema = CollectionSchema(
  name: r'TideRecord',
  id: -4267439602782219576,
  properties: {
    r'coords': PropertySchema(id: 0, name: r'coords', type: IsarType.string),
    r'createdAt': PropertySchema(
      id: 1,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'height': PropertySchema(id: 2, name: r'height', type: IsarType.double),
    r'isRising': PropertySchema(id: 3, name: r'isRising', type: IsarType.bool),
    r'location': PropertySchema(
      id: 4,
      name: r'location',
      type: IsarType.string,
    ),
    r'recordDate': PropertySchema(
      id: 5,
      name: r'recordDate',
      type: IsarType.string,
    ),
    r'tideType': PropertySchema(
      id: 6,
      name: r'tideType',
      type: IsarType.string,
    ),
  },

  estimateSize: _tideRecordEstimateSize,
  serialize: _tideRecordSerialize,
  deserialize: _tideRecordDeserialize,
  deserializeProp: _tideRecordDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},

  getId: _tideRecordGetId,
  getLinks: _tideRecordGetLinks,
  attach: _tideRecordAttach,
  version: '3.3.2',
);

int _tideRecordEstimateSize(
  TideRecord object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.coords.length * 3;
  bytesCount += 3 + object.location.length * 3;
  bytesCount += 3 + object.recordDate.length * 3;
  bytesCount += 3 + object.tideType.length * 3;
  return bytesCount;
}

void _tideRecordSerialize(
  TideRecord object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.coords);
  writer.writeDateTime(offsets[1], object.createdAt);
  writer.writeDouble(offsets[2], object.height);
  writer.writeBool(offsets[3], object.isRising);
  writer.writeString(offsets[4], object.location);
  writer.writeString(offsets[5], object.recordDate);
  writer.writeString(offsets[6], object.tideType);
}

TideRecord _tideRecordDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = TideRecord(
    coords: reader.readString(offsets[0]),
    createdAt: reader.readDateTime(offsets[1]),
    height: reader.readDouble(offsets[2]),
    isRising: reader.readBool(offsets[3]),
    location: reader.readString(offsets[4]),
    recordDate: reader.readString(offsets[5]),
    tideType: reader.readString(offsets[6]),
  );
  object.id = id;
  return object;
}

P _tideRecordDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readDateTime(offset)) as P;
    case 2:
      return (reader.readDouble(offset)) as P;
    case 3:
      return (reader.readBool(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _tideRecordGetId(TideRecord object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _tideRecordGetLinks(TideRecord object) {
  return [];
}

void _tideRecordAttach(IsarCollection<dynamic> col, Id id, TideRecord object) {
  object.id = id;
}

extension TideRecordQueryWhereSort
    on QueryBuilder<TideRecord, TideRecord, QWhere> {
  QueryBuilder<TideRecord, TideRecord, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension TideRecordQueryWhere
    on QueryBuilder<TideRecord, TideRecord, QWhereClause> {
  QueryBuilder<TideRecord, TideRecord, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterWhereClause> idNotEqualTo(Id id) {
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

  QueryBuilder<TideRecord, TideRecord, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterWhereClause> idBetween(
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

extension TideRecordQueryFilter
    on QueryBuilder<TideRecord, TideRecord, QFilterCondition> {
  QueryBuilder<TideRecord, TideRecord, QAfterFilterCondition> coordsEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'coords',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterFilterCondition> coordsGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'coords',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterFilterCondition> coordsLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'coords',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterFilterCondition> coordsBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'coords',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterFilterCondition> coordsStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'coords',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterFilterCondition> coordsEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'coords',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterFilterCondition> coordsContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'coords',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterFilterCondition> coordsMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'coords',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterFilterCondition> coordsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'coords', value: ''),
      );
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterFilterCondition>
  coordsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'coords', value: ''),
      );
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterFilterCondition> createdAtEqualTo(
    DateTime value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'createdAt', value: value),
      );
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterFilterCondition>
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

  QueryBuilder<TideRecord, TideRecord, QAfterFilterCondition> createdAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
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

  QueryBuilder<TideRecord, TideRecord, QAfterFilterCondition> createdAtBetween(
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

  QueryBuilder<TideRecord, TideRecord, QAfterFilterCondition> heightEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'height',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterFilterCondition> heightGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'height',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterFilterCondition> heightLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'height',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterFilterCondition> heightBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'height',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterFilterCondition> idEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
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

  QueryBuilder<TideRecord, TideRecord, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<TideRecord, TideRecord, QAfterFilterCondition> idBetween(
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

  QueryBuilder<TideRecord, TideRecord, QAfterFilterCondition> isRisingEqualTo(
    bool value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isRising', value: value),
      );
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterFilterCondition> locationEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'location',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterFilterCondition>
  locationGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'location',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterFilterCondition> locationLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'location',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterFilterCondition> locationBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'location',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterFilterCondition>
  locationStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'location',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterFilterCondition> locationEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'location',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterFilterCondition> locationContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'location',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterFilterCondition> locationMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'location',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterFilterCondition>
  locationIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'location', value: ''),
      );
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterFilterCondition>
  locationIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'location', value: ''),
      );
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterFilterCondition> recordDateEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'recordDate',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterFilterCondition>
  recordDateGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'recordDate',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterFilterCondition>
  recordDateLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'recordDate',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterFilterCondition> recordDateBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'recordDate',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterFilterCondition>
  recordDateStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'recordDate',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterFilterCondition>
  recordDateEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'recordDate',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterFilterCondition>
  recordDateContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'recordDate',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterFilterCondition> recordDateMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'recordDate',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterFilterCondition>
  recordDateIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'recordDate', value: ''),
      );
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterFilterCondition>
  recordDateIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'recordDate', value: ''),
      );
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterFilterCondition> tideTypeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'tideType',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterFilterCondition>
  tideTypeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'tideType',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterFilterCondition> tideTypeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'tideType',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterFilterCondition> tideTypeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'tideType',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterFilterCondition>
  tideTypeStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'tideType',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterFilterCondition> tideTypeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'tideType',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterFilterCondition> tideTypeContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'tideType',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterFilterCondition> tideTypeMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'tideType',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterFilterCondition>
  tideTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'tideType', value: ''),
      );
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterFilterCondition>
  tideTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'tideType', value: ''),
      );
    });
  }
}

extension TideRecordQueryObject
    on QueryBuilder<TideRecord, TideRecord, QFilterCondition> {}

extension TideRecordQueryLinks
    on QueryBuilder<TideRecord, TideRecord, QFilterCondition> {}

extension TideRecordQuerySortBy
    on QueryBuilder<TideRecord, TideRecord, QSortBy> {
  QueryBuilder<TideRecord, TideRecord, QAfterSortBy> sortByCoords() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'coords', Sort.asc);
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterSortBy> sortByCoordsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'coords', Sort.desc);
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterSortBy> sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterSortBy> sortByHeight() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'height', Sort.asc);
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterSortBy> sortByHeightDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'height', Sort.desc);
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterSortBy> sortByIsRising() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isRising', Sort.asc);
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterSortBy> sortByIsRisingDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isRising', Sort.desc);
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterSortBy> sortByLocation() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'location', Sort.asc);
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterSortBy> sortByLocationDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'location', Sort.desc);
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterSortBy> sortByRecordDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recordDate', Sort.asc);
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterSortBy> sortByRecordDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recordDate', Sort.desc);
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterSortBy> sortByTideType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tideType', Sort.asc);
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterSortBy> sortByTideTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tideType', Sort.desc);
    });
  }
}

extension TideRecordQuerySortThenBy
    on QueryBuilder<TideRecord, TideRecord, QSortThenBy> {
  QueryBuilder<TideRecord, TideRecord, QAfterSortBy> thenByCoords() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'coords', Sort.asc);
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterSortBy> thenByCoordsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'coords', Sort.desc);
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterSortBy> thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterSortBy> thenByHeight() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'height', Sort.asc);
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterSortBy> thenByHeightDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'height', Sort.desc);
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterSortBy> thenByIsRising() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isRising', Sort.asc);
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterSortBy> thenByIsRisingDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isRising', Sort.desc);
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterSortBy> thenByLocation() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'location', Sort.asc);
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterSortBy> thenByLocationDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'location', Sort.desc);
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterSortBy> thenByRecordDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recordDate', Sort.asc);
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterSortBy> thenByRecordDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recordDate', Sort.desc);
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterSortBy> thenByTideType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tideType', Sort.asc);
    });
  }

  QueryBuilder<TideRecord, TideRecord, QAfterSortBy> thenByTideTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tideType', Sort.desc);
    });
  }
}

extension TideRecordQueryWhereDistinct
    on QueryBuilder<TideRecord, TideRecord, QDistinct> {
  QueryBuilder<TideRecord, TideRecord, QDistinct> distinctByCoords({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'coords', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TideRecord, TideRecord, QDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<TideRecord, TideRecord, QDistinct> distinctByHeight() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'height');
    });
  }

  QueryBuilder<TideRecord, TideRecord, QDistinct> distinctByIsRising() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isRising');
    });
  }

  QueryBuilder<TideRecord, TideRecord, QDistinct> distinctByLocation({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'location', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TideRecord, TideRecord, QDistinct> distinctByRecordDate({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'recordDate', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TideRecord, TideRecord, QDistinct> distinctByTideType({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'tideType', caseSensitive: caseSensitive);
    });
  }
}

extension TideRecordQueryProperty
    on QueryBuilder<TideRecord, TideRecord, QQueryProperty> {
  QueryBuilder<TideRecord, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<TideRecord, String, QQueryOperations> coordsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'coords');
    });
  }

  QueryBuilder<TideRecord, DateTime, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<TideRecord, double, QQueryOperations> heightProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'height');
    });
  }

  QueryBuilder<TideRecord, bool, QQueryOperations> isRisingProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isRising');
    });
  }

  QueryBuilder<TideRecord, String, QQueryOperations> locationProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'location');
    });
  }

  QueryBuilder<TideRecord, String, QQueryOperations> recordDateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'recordDate');
    });
  }

  QueryBuilder<TideRecord, String, QQueryOperations> tideTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'tideType');
    });
  }
}
