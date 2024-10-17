import 'abstraction.dart';

enum FilterOrderBy {
  desc,
  asc,
}

enum FilterOperation {
  equals('Equals'),
  notEqual('NotEqual'),
  contains('Contains'),
  startsWith('StartsWith'),
  endsWith('EndsWith'),
  lessThan('LessThan'),
  lessThanEqual('LessThanEqual'),
  greaterThan('GreaterThan'),
  greaterThanEqual('GreaterThanEqual');

  const FilterOperation(this.realName);

  final String realName;

  static FilterOperation byName(String s) {
    switch (s) {
      case 'Equals':
        return FilterOperation.equals;
      case 'NotEqual':
        return FilterOperation.notEqual;
      case 'Contains':
        return FilterOperation.contains;
      case 'StartsWith':
        return FilterOperation.startsWith;
      case 'EndsWith':
        return FilterOperation.endsWith;
      case 'LessThan':
        return FilterOperation.lessThan;
      case 'LessThanEqual':
        return FilterOperation.lessThanEqual;
      case 'GreaterThan':
        return FilterOperation.greaterThan;
      case 'GreaterThanEqual':
        return FilterOperation.greaterThanEqual;
      default:
        return FilterOperation.equals;
    }
  }
}

enum NeedUpdateEnum { no, withLoading, noLoading }

extension McubitStringH on String {
  String maxLength(int l) {
    if (length > l) return substring(0, l);
    return this;
  }

  String get getKey {
    // var bytes = utf8.encode(this);
    // var digest = md5.convert(bytes);
    // var digest1 = sha1.convert(bytes);
    var digest2 = hashCode.toString();

    return '$digest2'.maxLength(10);
  }
}

extension StringHelper on String? {
  bool get isBlank {
    if (this == null) return true;
    if (this == 'null') return true;
    return this!.trim().isEmpty;
  }
}

extension NeedUpdateEnumH on NeedUpdateEnum {
  bool get loading => this == NeedUpdateEnum.withLoading;

  bool get haveData => this == NeedUpdateEnum.no || this == NeedUpdateEnum.noLoading;

  CubitStatuses get getState {
    switch (this) {
      case NeedUpdateEnum.no:
        return CubitStatuses.done;
      case NeedUpdateEnum.withLoading:
        return CubitStatuses.loading;
      case NeedUpdateEnum.noLoading:
        return CubitStatuses.noLoading;
    }
  }
}
