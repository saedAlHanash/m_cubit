import 'package:flutter_test/flutter_test.dart';
import 'package:m_cubit/m_cubit.dart';

void main() {
  group('TimerErrorHandler Tests', () {
    group('validateDuration', () {
      test('should accept valid durations', () {
        expect(() => TimerErrorHandler.validateDuration(const Duration(seconds: 1)), returnsNormally);
        expect(() => TimerErrorHandler.validateDuration(const Duration(minutes: 5)), returnsNormally);
        expect(() => TimerErrorHandler.validateDuration(const Duration(hours: 1)), returnsNormally);
      });

      test('should reject null duration', () {
        expect(() => TimerErrorHandler.validateDuration(null), 
               throwsA(isA<TimerValidationException>()
                 .having((e) => e.message, 'message', contains('cannot be null'))
                 .having((e) => e.field, 'field', 'duration')));
      });

      test('should reject zero duration when not allowed', () {
        expect(() => TimerErrorHandler.validateDuration(Duration.zero), 
               throwsA(isA<TimerValidationException>()
                 .having((e) => e.message, 'message', contains('cannot be zero'))));
      });

      test('should accept zero duration when allowed', () {
        expect(() => TimerErrorHandler.validateDuration(Duration.zero, allowZero: true), returnsNormally);
      });

      test('should reject negative duration', () {
        expect(() => TimerErrorHandler.validateDuration(const Duration(seconds: -1)), 
               throwsA(isA<TimerValidationException>()
                 .having((e) => e.message, 'message', contains('cannot be negative'))));
      });

      test('should reject duration exceeding 365 days', () {
        expect(() => TimerErrorHandler.validateDuration(const Duration(days: 366)), 
               throwsA(isA<TimerValidationException>()
                 .having((e) => e.message, 'message', contains('cannot exceed 365 days'))));
      });
    });

    group('validateConfiguration', () {
      test('should accept valid configuration', () {
        expect(() => TimerErrorHandler.validateConfiguration(
          initialDuration: const Duration(seconds: 10),
          maxDuration: const Duration(minutes: 1),
        ), returnsNormally);
      });

      test('should reject when initial duration exceeds max duration', () {
        expect(() => TimerErrorHandler.validateConfiguration(
          initialDuration: const Duration(minutes: 2),
          maxDuration: const Duration(minutes: 1),
        ), throwsA(isA<TimerValidationException>()
          .having((e) => e.message, 'message', contains('cannot exceed maximum duration'))));
      });

      test('should accept null durations', () {
        expect(() => TimerErrorHandler.validateConfiguration(
          initialDuration: null,
          maxDuration: null,
        ), returnsNormally);
      });
    });

    group('validateStateTransition', () {
      test('should allow valid transitions', () {
        expect(() => TimerErrorHandler.validateStateTransition(TimerState.idle, TimerState.running), returnsNormally);
        expect(() => TimerErrorHandler.validateStateTransition(TimerState.running, TimerState.paused), returnsNormally);
        expect(() => TimerErrorHandler.validateStateTransition(TimerState.paused, TimerState.running), returnsNormally);
        expect(() => TimerErrorHandler.validateStateTransition(TimerState.running, TimerState.completed), returnsNormally);
        expect(() => TimerErrorHandler.validateStateTransition(TimerState.completed, TimerState.idle), returnsNormally);
      });

      test('should reject invalid transitions', () {
        expect(() => TimerErrorHandler.validateStateTransition(TimerState.idle, TimerState.paused), 
               throwsA(isA<TimerValidationException>()
                 .having((e) => e.message, 'message', contains('Invalid state transition'))));
        
        expect(() => TimerErrorHandler.validateStateTransition(TimerState.paused, TimerState.completed), 
               throwsA(isA<TimerValidationException>()
                 .having((e) => e.message, 'message', contains('Invalid state transition'))));
      });
    });

    group('safeExecute', () {
      test('should execute successful operation', () {
        bool executed = false;
        
        TimerErrorHandler.safeExecute(() {
          executed = true;
        });
        
        expect(executed, isTrue);
      });

      test('should rethrow exceptions', () {
        expect(() => TimerErrorHandler.safeExecute(() {
          throw Exception('Test exception');
        }), throwsException);
      });
    });

    group('safeExecuteWithReturn', () {
      test('should return result for successful operation', () {
        final result = TimerErrorHandler.safeExecuteWithReturn(() => 42);
        
        expect(result, 42);
      });

      test('should rethrow exceptions', () {
        expect(() => TimerErrorHandler.safeExecuteWithReturn(() {
          throw Exception('Test exception');
        }), throwsException);
      });
    });
  });
}