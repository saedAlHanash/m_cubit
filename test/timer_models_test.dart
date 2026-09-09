import 'package:flutter_test/flutter_test.dart';
import 'package:m_cubit/m_cubit.dart';

void main() {
  group('TimerModels Tests', () {
    group('TimerConfiguration', () {
      test('should create with default values', () {
        const config = TimerConfiguration();
        
        expect(config.mode, TimerMode.countdown);
        expect(config.initialDuration, isNull);
        expect(config.autoStart, false);
        expect(config.allowNegative, false);
      });

      test('should create with custom values', () {
        const config = TimerConfiguration(
          mode: TimerMode.stopwatch,
          initialDuration: Duration(seconds: 30),
          autoStart: true,
          allowNegative: true,
        );
        
        expect(config.mode, TimerMode.stopwatch);
        expect(config.initialDuration, const Duration(seconds: 30));
        expect(config.autoStart, true);
        expect(config.allowNegative, true);
      });

      test('should copy with new values', () {
        const config = TimerConfiguration();
        final newConfig = config.copyWith(
          mode: TimerMode.stopwatch,
          autoStart: true,
        );
        
        expect(newConfig.mode, TimerMode.stopwatch);
        expect(newConfig.autoStart, true);
        expect(newConfig.initialDuration, isNull); // Should keep original value
      });

      test('should be equatable', () {
        const config1 = TimerConfiguration(
          mode: TimerMode.countdown,
          initialDuration: Duration(seconds: 10),
        );
        const config2 = TimerConfiguration(
          mode: TimerMode.countdown,
          initialDuration: Duration(seconds: 10),
        );
        const config3 = TimerConfiguration(
          mode: TimerMode.stopwatch,
          initialDuration: Duration(seconds: 10),
        );
        
        expect(config1, config2);
        expect(config1, isNot(config3));
      });
    });

    group('LapTime', () {
      test('should create with correct values', () {
        const lapTime = LapTime(
          lapNumber: 1,
          time: Duration(seconds: 10),
          totalTime: Duration(seconds: 10),
        );
        
        expect(lapTime.lapNumber, 1);
        expect(lapTime.time, const Duration(seconds: 10));
        expect(lapTime.totalTime, const Duration(seconds: 10));
      });

      test('should be equatable', () {
        const lapTime1 = LapTime(
          lapNumber: 1,
          time: Duration(seconds: 10),
          totalTime: Duration(seconds: 10),
        );
        const lapTime2 = LapTime(
          lapNumber: 1,
          time: Duration(seconds: 10),
          totalTime: Duration(seconds: 10),
        );
        const lapTime3 = LapTime(
          lapNumber: 2,
          time: Duration(seconds: 10),
          totalTime: Duration(seconds: 10),
        );
        
        expect(lapTime1, lapTime2);
        expect(lapTime1, isNot(lapTime3));
      });
    });

    group('TimerStateData', () {
      test('should create with default values', () {
        const stateData = TimerStateData(
          state: TimerState.idle,
          currentTime: Duration.zero,
          mode: TimerMode.countdown,
        );
        
        expect(stateData.state, TimerState.idle);
        expect(stateData.currentTime, Duration.zero);
        expect(stateData.initialTime, isNull);
        expect(stateData.lapTimes, isEmpty);
        expect(stateData.mode, TimerMode.countdown);
        expect(stateData.progress, isNull);
      });

      test('should format time correctly', () {
        final testCases = [
          (Duration.zero, '00.00'),
          (const Duration(seconds: 5, milliseconds: 500), '05.50'),
          (const Duration(minutes: 2, seconds: 30, milliseconds: 250), '02:30.25'),
          (const Duration(hours: 1, minutes: 30, seconds: 45), '01:30:45'),
        ];

        for (final (duration, expectedFormat) in testCases) {
          final stateData = TimerStateData(
            state: TimerState.idle,
            currentTime: duration,
            mode: TimerMode.countdown,
          );
          
          expect(stateData.formattedTime, expectedFormat);
        }
      });

      test('should copy with new values', () {
        const stateData = TimerStateData(
          state: TimerState.idle,
          currentTime: Duration.zero,
          mode: TimerMode.countdown,
        );
        
        final newStateData = stateData.copyWith(
          state: TimerState.running,
          currentTime: const Duration(seconds: 10),
        );
        
        expect(newStateData.state, TimerState.running);
        expect(newStateData.currentTime, const Duration(seconds: 10));
        expect(newStateData.mode, TimerMode.countdown); // Should keep original value
      });

      test('should be equatable', () {
        const stateData1 = TimerStateData(
          state: TimerState.idle,
          currentTime: Duration.zero,
          mode: TimerMode.countdown,
        );
        const stateData2 = TimerStateData(
          state: TimerState.idle,
          currentTime: Duration.zero,
          mode: TimerMode.countdown,
        );
        const stateData3 = TimerStateData(
          state: TimerState.running,
          currentTime: Duration.zero,
          mode: TimerMode.countdown,
        );
        
        expect(stateData1, stateData2);
        expect(stateData1, isNot(stateData3));
      });
    });
  });
}