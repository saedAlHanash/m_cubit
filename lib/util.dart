import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:m_cubit/util.dart';

import 'abstraction.dart';

extension SplitByLength on String {
  String get fileExtension {
    if (!contains('.')) return '';
    return split('.').last.toLowerCase();
  }

  String maxLength(int l) {
    if (length > l) return substring(0, l);
    return this;
  }

  String get getKey {
    var digest2 = hashCode.toString();
    return digest2.maxLength(10);
  }

  List<String> splitByLength1(int length, {bool ignoreEmpty = false}) {
    List<String> pieces = [];

    for (int i = 0; i < this.length; i += length) {
      int offset = i + length;
      String piece = substring(i, offset >= this.length ? this.length : offset);

      if (ignoreEmpty) {
        piece = piece.replaceAll(RegExp(r'\s+'), '');
      }

      pieces.add(piece);
    }
    return pieces;
  }

  String get logLongMessage {
    var r = [];
    var res = '';
    if (length > 800) {
      r = splitByLength1(800);
      for (var e in r) {
        res += '$e\n';
      }
    } else {
      res = this;
    }
    return res;
  }

  bool get canSendToSearch {
    if (isEmpty) false;

    return split(' ').last.length > 2;
  }

  int get numberOnly {
    final regex = RegExp(r'\d+');

    final numbers = regex.allMatches(this).map((match) => match.group(0)).join();

    try {
      return int.parse(numbers);
    } on Exception {
      return 0;
    }
  }

  bool get isZero => (num.tryParse(this) ?? 0) == 0;

  String get removeDuplicates => split(' ').toSet().join(' ');

  num get tryParseOrZero => num.tryParse(this) ?? 0.0;

  num tryParseOr(num n) => num.tryParse(this) ?? n;

  int get tryParseOrZeroInt => int.tryParse(this) ?? 0;

  num? get tryParseOrNull => num.tryParse(this);

  int? get tryParseOrNullInt => int.tryParse(this);

  bool get tryParseBoolOrFalse => this == '1' || toLowerCase() == 'true';

  Color get toColor => Color(int.parse('0xff${replaceFirst('#', '')}'));

  Color get idToSafeColor {
    if (trim().isEmpty) return Colors.black;

    return HSLColor.fromAHSL(1.0, trim().hashCode.abs() % 360, 0.6, 0.6).toColor();
  }

  bool get isUrl {
    final uri = Uri.tryParse(this);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  String get numToEn {
    return replaceAll('٠', '0')
        .replaceAll('١', '1')
        .replaceAll('٢', '2')
        .replaceAll('٣', '3')
        .replaceAll('٤', '4')
        .replaceAll('٥', '5')
        .replaceAll('٦', '6')
        .replaceAll('٧', '7')
        .replaceAll('٨', '8')
        .replaceAll('٩', '9');
  }

  String get capitalizeFirst => isEmpty ? this : this[0].toUpperCase() + substring(1);

  String get decimalNumbersOnly {
    final matches = RegExp(r'\d+([.,]\d+)?').allMatches(this);
    return matches.map((m) => m.group(0)).join(' ');
  }

  String get toSnakeCase {
    final regex = RegExp(r'(?<=[a-z])[A-Z]');
    return replaceAllMapped(regex, (match) => '_${match.group(0)}').toLowerCase();
  }

  String get toSplitsSpaceCase {
    final regex = RegExp(r'(?<=[a-z])[A-Z]');
    return replaceAllMapped(regex, (match) => '_${match.group(0)}').toLowerCase().replaceAll('_', ' ');
  }

  String get toPascalCase {
    final words = split('_');
    return words.map((word) => word[0].toUpperCase() + word.substring(1)).join();
  }

  String get toCamelCase {
    final words = split('_');
    if (words.isEmpty) return '';
    final capitalized = words.map((word) => word[0].toUpperCase() + word.substring(1)).join();
    return capitalized[0].toLowerCase() + capitalized.substring(1);
  }

  Color get colorFromId {
    final hash = hashCode;
    final hue = (hash % 360).toDouble(); // 0 → 360
    const saturation = 0.6; // تشبع متوسط
    const lightness = 0.5; // سطوع متوسط

    return HSLColor.fromAHSL(1.0, hue, saturation, lightness).toColor();
  }

  Color get gradeColor {
    final upperCaseGrade = toUpperCase();
    if (upperCaseGrade.contains('A')) {
      return Colors.green;
    } else if (upperCaseGrade.contains('B')) {
      return Colors.blue;
    } else if (upperCaseGrade.contains('C')) {
      return Colors.yellow;
    } else if (upperCaseGrade.contains('D')) {
      return Colors.orange;
    } else if (upperCaseGrade.contains('F')) {
      return Colors.red;
    } else {
      // Return a default color or throw an error for unknown grades
      return Colors.grey; // Or throw ArgumentError('Invalid grade: $this');
    }
  }
}

extension StringHelper on String? {
  bool get isBlank {
    return this == null || this!.trim().isEmpty || this!.toLowerCase() == 'null';
  }
}

extension MaxIntNulable on num? {
  bool get isBlankNumber {
    if (this == null) return true;
    return (this!) <= 0;
  }
}

extension HelperJson on Map<String, dynamic> {
  num getAsNum(String key) {
    if (this[key] == null) return -1;
    return num.tryParse((this[key]).toString()) ?? -1;
  }
}

extension FormatDuration on Duration {
  String get format {
    var includeDays = false;

    final h = inHours.remainder(24);
    final m = inMinutes.remainder(60);
    final s = inSeconds.remainder(60);

    final buffer = StringBuffer();

    // if (includeDays && d > 0) buffer.write('${d.toString().padLeft(2, '0')}:');
    if (includeDays || h > 0) buffer.write('${h.toString().padLeft(2, '0')}:');

    buffer
      ..write('${m.toString().padLeft(2, '0')}:')
      ..write(s.toString().padLeft(2, '0'));

    return buffer.toString();
  }
}

extension ApiStatusCode on int {
  bool get success => (this >= 200 && this <= 210);

  DateTime get fromMilliDateFixed => DateTime.fromMillisecondsSinceEpoch(this).toUtc().fixTimeZone;

  int get countDiv2 => (this ~/ 2 < this / 2) ? this ~/ 2 + 1 : this ~/ 2;
}

extension TextEditingControllerHelper on TextEditingController {
  void clear() {
    if (text.isNotEmpty) text = '';
  }
}

extension GlobalKeyH on GlobalKey {
  Size? get getSize {
    final renderBox = currentContext?.findRenderObject() as RenderBox?;
    final size = renderBox?.size;
    return size;
  }
}

extension DateUtcHelper on DateTime {
  int get hashDate => (day * 61) + (month * 83) + (year * 23);

  String get formatDateTime1 {
    return DateFormat('dd MMM yyyy  h:mm a', 'en').format(this);
  }

  DateTime get getUtc => DateTime.utc(year, month, day);

  /// Check if the date is today
  bool get isToday {
    final now = DateTime.now();
    return now.year == year && now.month == month && now.day == day;
  }

  /// Check if the date is tomorrow
  bool get isTomorrow {
    final tomorrow = DateTime.now().add(Duration(days: 1));
    return tomorrow.year == year && tomorrow.month == month && tomorrow.day == day;
  }

  /// Check if the date is yesterday
  bool get isYesterday {
    final yesterday = DateTime.now().subtract(Duration(days: 1));
    return yesterday.year == year && yesterday.month == month && yesterday.day == day;
  }

  String get formatDate => DateFormat('yyyy/MM/dd', 'en').format(this);

  String get formatDateMonthName => '$monthName $day';

  String get formatDateMD => DateFormat('dd/MM', 'en').format(this);

  String get formatDateDY => DateFormat('yyyy/MM', 'en').format(this);

  String get formatDateDYMName => '';

  String get formatDateD => DateFormat('dd', 'en').format(this);

  String get formatDateToRequest => DateFormat('yyyy-MM-dd', 'en').format(this);

  String get formatTime => DateFormat('hh:mm a', 'en').format(this);

  String get formatTime24 => DateFormat('hh:mm', 'en').format(this);

  String get dayName => DateFormat('EEEE').format(this);

  String get monthName => DateFormat('MMMM').format(this);

  String get formatDateTime => '$formatDate - $formatTime';

  String get formatDateTime24 => '$formatDate - $formatTime24';

  String get formatDateTimeVertical => '$formatDate\n$formatTime';

  DateTime addFromNow({int? year, int? month, int? day, int? hour, int? minute, int? second}) {
    return DateTime(
      this.year + (year ?? 0),
      this.month + (month ?? 0),
      this.day + (day ?? 0),
      this.hour + (hour ?? 0),
      this.minute + (minute ?? 0),
      this.second + (second ?? 0),
    );
  }

  FormatDateTime getFormat({DateTime? serverDate}) {
    final difference = this.difference(serverDate ?? DateTime.now());

    final months = difference.inDays.abs() ~/ 30;
    final days = difference.inDays.abs() % 360;
    final hours = difference.inHours.abs() % 24;
    final minutes = difference.inMinutes.abs() % 60;
    final seconds = difference.inSeconds.abs() % 60;
    return FormatDateTime(
      months: months,
      days: days,
      hours: hours,
      minutes: minutes,
      seconds: seconds,
    );
  }

  int get getWeekNumber {
    final DateTime firstJan = DateTime(year, 1, 1);
    // final int daysInYear = DateTime(year + 1, 1, 1).difference(firstJan).inDays;
    final int weekNumber = (difference(firstJan).inDays ~/ 7) + 1;
    // If the date is after the first Monday of the year, then it is in the current week.
    if (weekday >= 1) {
      return weekNumber;
    }
    // Otherwise, it is in the previous week.
    return weekNumber - 1;
  }

  DateTime get fixTimeZone => add(DateTime.now().timeZoneOffset);

  List<DateTime> getDateTimesBetween({
    required DateTime end,
    required Duration period,
  }) {
    var dateTimes = <DateTime>[];
    var current = add(period);
    while (current.isBefore(end)) {
      if (dateTimes.length > 24) {
        break;
      }
      dateTimes.add(current);
      current = current.add(period);
    }
    return dateTimes;
  }

  bool isSameDate(DateTime? date) {
    if (date == null) return false;
    return year == date.year && month == date.month && day == date.day;
  }

  String get formatDateName => DateFormat('dd/$monthName/yyyy').format(this);
}

extension FirstItem<E> on Iterable<E> {
  E? get firstItem => isEmpty ? null : first;
}

class FormatDateTime {
  final int months;
  final int days;
  final int hours;
  final int minutes;
  final int seconds;

  const FormatDateTime({
    required this.months,
    required this.days,
    required this.hours,
    required this.minutes,
    required this.seconds,
  });

  @override
  String toString() {
    return '$months\n'
        '$days\n'
        '$hours\n'
        '$minutes\n'
        '$seconds\n';
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
