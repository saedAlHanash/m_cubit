import 'package:intl/intl.dart';

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

extension DateString on String {
  int get dayIndex {
    const dayPatterns = {
      0: ['أحد', 'احد', 'sun', 'sunday'],
      1: ['اثنين', 'إثنين', 'mon', 'monday', 'monady', 'mondy'],
      2: ['ثلاثاء', 'ثلاثا', 'ثلاثة', 'tue', 'tuesday', 'tuseday', 'tusday'],
      3: ['أربعاء', 'اربعاء', 'اربعا', 'wed', 'wednesday', 'wensday', 'wednsday'],
      4: ['خميس', 'thu', 'thursday', 'thrusday', 'thursady'],
      5: ['جمعة', 'جمعه', 'fri', 'friday', 'fridy'],
      6: ['سبت', 'sat', 'saturday', 'satday', 'saturady'],
    };

    final input = trim().toLowerCase();
    try {
      return dayPatterns.entries.firstWhere((e) => e.value.any((pattern) => input.contains(pattern))).key;
    } catch (_) {
      return 0;
    }
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

  String get formatDateD => DateFormat('dd', 'en').format(this);

  String get formatDateToRequest => DateFormat('yyyy-MM-dd', 'en').format(this);

  String get formatTime => DateFormat('hh:mm a', 'en').format(this);

  String get formatTime24 => DateFormat('hh:mm', 'en').format(this);

  String get dayName => DateFormat('EEEE').format(this);

  String get monthName => DateFormat('MMMM').format(this);
  String get monthNameAr {
    const months = [
      'كانون الثاني',
      'شباط',
      'آذار',
      'نيسان',
      'أيار',
      'حزيران',
      'تموز',
      'آب',
      'أيلول',
      'تشرين الأول',
      'تشرين الثاني',
      'كانون الأول',
    ];
    return months[month - 1];
  }

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

  String get formatDateApi => DateFormat('yyyy-MM-dd', 'en').format(this);

  /// تحويل اليوم الحالي لنظام يبدأ من الأحد (0 = الأحد .. 6 = السبت)
  int get arabicWeekdayIndex => weekday % 7;


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
