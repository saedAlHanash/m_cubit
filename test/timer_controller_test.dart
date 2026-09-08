import 'package:flutter_test/flutter_test.dart';
import 'package:m_cubit/m_cubit.dart';

void main() {
  group('TimerController Tests', () {
    late TimerController controller;

    setUp(() {
      controller = TimerController();
    });

    tearDown(() {
      controller.dispose();
    });

    group('Basic Functionality', () {
      test('should initialize with correct default state', () {
        expect(controller.stateData.state, TimerState.idle);
        expect(controller.stateData.currentTime, Duration.zero);
        expect(controller.stateData.mode, TimerMode.countdown);
      });

      test('should start timer and change state to running', () {
        controller.setDuration(const Duration(seconds: 10));
        controller.start();
        
        expect(controller.stateData.state, TimerState.running);
      });

      test('should pause timer and change state to paused', () {
        controller.setDuration(const Duration(seconds: 10));
        controller.start();
        controller.pause();
        
        expect(controller.stateData.state, TimerState.paused);
      });

      test('should resume timer and change state to running', () {
        controller.setDuration(const Duration(seconds: 10));
        controller.start();
        controller.pause();
        controller.resume();
        
        expect(controller.stateData.state, TimerState.running);
      });

      test('should reset timer to idle state', () {
        controller.setDuration(const Duration(seconds: 10));
        controller.start();
        controller.reset();
        
        expect(controller.stateData.state, TimerState.idle);
        expect(controller.stateData.currentTime, const Duration(seconds: 10));
      });
    });

    group('Countdown Timer', () {
      test('should countdown correctly', () async {
        controller.setDuration(const Duration(seconds: 2));
        controller.start();
        
        await Future.delayed(const Duration(seconds: 1));
        
        expect(controller.stateData.currentTime.inSeconds, lessThan(2));
        expect(controller.stateData.currentTime.inSeconds, greaterThan(0));
      });

      test('should complete countdown and trigger callback', () async {
        bool callbackTriggered = false;
        
        final controllerWithCallback = TimerController(
          configuration: TimerConfiguration(
            mode: TimerMode.countdown,
            initialDuration: const Duration(milliseconds: 100),
            onComplete: () => callbackTriggered = true,
          ),
        );
        
        controllerWithCallback.start();
        
        await Future.delayed(const Duration(milliseconds: 200));
        
        expect(controllerWithCallback.stateData.state, TimerState.completed);
        expect(callbackTriggered, isTrue);
        
        controllerWithCallback.dispose();
      });

      test('should calculate progress correctly', () {
        controller.setDuration(const Duration(seconds: 10));
        controller.start();
        
        expect(controller.stateData.progress, 1.0);
      });
    });

    group('Stopwatch Timer', () {
      late TimerController stopwatchController;

      setUp(() {
        stopwatchController = TimerController(
          configuration: const TimerConfiguration(
            mode: TimerMode.stopwatch,
          ),
        );
      });

      tearDown(() {
        stopwatchController.dispose();
      });

      test('should count up correctly', () async {
        stopwatchController.start();
        
        await Future.delayed(const Duration(milliseconds: 1100));
        
        expect(stopwatchController.stateData.currentTime.inMilliseconds, greaterThan(1000));
      });

      test('should record lap times', () {
        stopwatchController.start();
        stopwatchController.recordLap();
        
        expect(stopwatchController.stateData.lapTimes.length, 1);
        expect(stopwatchController.stateData.lapTimes[0].lapNumber, 1);
      });

      test('should not have progress in stopwatch mode', () {
        expect(stopwatchController.stateData.progress, isNull);
      });
    });

    group('Error Handling', () {
      test('should throw exception when starting countdown without duration', () {
        expect(() => controller.start(), throwsA(isA<TimerValidationException>()));
      });

      test('should throw exception when recording lap in countdown mode', () {
        controller.setDuration(const Duration(seconds: 10));
        controller.start();
        
        expect(() => controller.recordLap(), throwsA(isA<TimerValidationException>()));
      });

      test('should throw exception when setting duration while running', () {
        controller.setDuration(const Duration(seconds: 10));
        controller.start();
        
        expect(() => controller.setDuration(const Duration(seconds: 5)), 
               throwsA(isA<TimerValidationException>()));
      });

      test('should throw exception for invalid state transitions', () {
        // Idle to paused is invalid
        expect(() => controller.pause(), throwsA(isA<TimerValidationException>()));

        // Paused to paused is invalid
        controller.setDuration(const Duration(seconds: 10));
        controller.start();
        controller.pause();
        expect(() => controller.pause(), throwsA(isA<TimerValidationException>()));
      });
    });

    group('Configuration', () {
      test('should update configuration when idle', () {
        final newConfig = TimerConfiguration(
          mode: TimerMode.stopwatch,
          initialDuration: const Duration(seconds: 30),
        );
        
        controller.updateConfiguration(newConfig);
        
        expect(controller.configuration.mode, TimerMode.stopwatch);
        expect(controller.stateData.currentTime, const Duration(seconds: 30));
      });

      test('should not update configuration when running', () {
        controller.setDuration(const Duration(seconds: 10));
        controller.start();
        
        final originalConfig = controller.configuration;
        
        final newConfig = TimerConfiguration(
          mode: TimerMode.stopwatch,
          initialDuration: const Duration(seconds: 30),
        );
        
        controller.updateConfiguration(newConfig);
        
        expect(controller.configuration, originalConfig);
      });
    });

    group('Time Formatting', () {
      test('should format time correctly for different durations', () {
        final testCases = [
          (Duration.zero, '00.00'),
          (const Duration(seconds: 5), '05.00'),
          (const Duration(minutes: 2, seconds: 30), '02:30.00'),
          (const Duration(hours: 1, minutes: 30, seconds: 45), '01:30:45'),
        ];

        for (final (duration, expectedFormat) in testCases) {
          final controller = TimerController(
            configuration: TimerConfiguration(initialDuration: duration),
          );
          
          expect(controller.stateData.formattedTime, expectedFormat);
          controller.dispose();
        }
      });
    });
  });
}