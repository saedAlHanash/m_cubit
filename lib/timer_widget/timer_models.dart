import 'package:equatable/equatable.dart';

enum TimerMode { countdown, stopwatch }

enum TimerState { idle, running, paused, completed }

class TimerConfiguration extends Equatable {
  final TimerMode mode;
  final Duration? initialDuration;
  final Duration? maxDuration;
  final bool autoStart;
  final bool allowNegative;
  final Function()? onComplete;
  final Function(Duration)? onTick;

  const TimerConfiguration({
    this.mode = TimerMode.countdown,
    this.initialDuration,
    this.maxDuration,
    this.autoStart = false,
    this.allowNegative = false,
    this.onComplete,
    this.onTick,
  });

  TimerConfiguration copyWith({
    TimerMode? mode,
    Duration? initialDuration,
    Duration? maxDuration,
    bool? autoStart,
    bool? allowNegative,
    Function()? onComplete,
    Function(Duration)? onTick,
  }) {
    return TimerConfiguration(
      mode: mode ?? this.mode,
      initialDuration: initialDuration ?? this.initialDuration,
      maxDuration: maxDuration ?? this.maxDuration,
      autoStart: autoStart ?? this.autoStart,
      allowNegative: allowNegative ?? this.allowNegative,
      onComplete: onComplete ?? this.onComplete,
      onTick: onTick ?? this.onTick,
    );
  }

  @override
  List<Object?> get props => [
        mode,
        initialDuration,
        maxDuration,
        autoStart,
        allowNegative,
      ];
}

class LapTime extends Equatable {
  final int lapNumber;
  final Duration time;
  final Duration totalTime;

  const LapTime({
    required this.lapNumber,
    required this.time,
    required this.totalTime,
  });

  @override
  List<Object?> get props => [lapNumber, time, totalTime];
}

class TimerStateData extends Equatable {
  final TimerState state;
  final Duration currentTime;
  final Duration? initialTime;
  final List<LapTime> lapTimes;
  final TimerMode mode;
  final double? progress;

  const TimerStateData({
    required this.state,
    required this.currentTime,
    this.initialTime,
    this.lapTimes = const [],
    required this.mode,
    this.progress,
  });

  String get formattedTime {
    final hours = currentTime.inHours;
    final minutes = currentTime.inMinutes % 60;
    final seconds = currentTime.inSeconds % 60;
    final milliseconds = (currentTime.inMilliseconds % 1000) ~/ 10;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else if (minutes > 0) {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${milliseconds.toString().padLeft(2, '0')}';
    } else {
      return '${seconds.toString().padLeft(2, '0')}.${milliseconds.toString().padLeft(2, '0')}';
    }
  }

  TimerStateData copyWith({
    TimerState? state,
    Duration? currentTime,
    Duration? initialTime,
    List<LapTime>? lapTimes,
    TimerMode? mode,
    double? progress,
  }) {
    return TimerStateData(
      state: state ?? this.state,
      currentTime: currentTime ?? this.currentTime,
      initialTime: initialTime ?? this.initialTime,
      lapTimes: lapTimes ?? this.lapTimes,
      mode: mode ?? this.mode,
      progress: progress ?? this.progress,
    );
  }

  @override
  List<Object?> get props => [
        state,
        currentTime,
        initialTime,
        lapTimes,
        mode,
        progress,
      ];
}