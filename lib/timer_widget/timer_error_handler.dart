import 'package:flutter/foundation.dart';
import 'timer_models.dart';

class TimerValidationException implements Exception {
  final String message;
  final String? field;
  
  TimerValidationException(this.message, [this.field]);
  
  @override
  String toString() {
    return field != null 
        ? 'TimerValidationException: $message (field: $field)'
        : 'TimerValidationException: $message';
  }
}

class TimerErrorHandler {
  static void validateDuration(Duration? duration, {bool allowZero = false}) {
    if (duration == null) {
      throw TimerValidationException('Duration cannot be null', 'duration');
    }
    
    if (!allowZero && duration == Duration.zero) {
      throw TimerValidationException('Duration cannot be zero', 'duration');
    }
    
    if (duration.inMilliseconds < 0) {
      throw TimerValidationException('Duration cannot be negative', 'duration');
    }
    
    if (duration.inDays > 365) {
      throw TimerValidationException('Duration cannot exceed 365 days', 'duration');
    }
  }
  
  static void validateConfiguration({
    required Duration? initialDuration,
    required Duration? maxDuration,
    bool allowNegative = false,
  }) {
    if (initialDuration != null) {
      validateDuration(initialDuration, allowZero: true);
    }
    
    if (maxDuration != null) {
      validateDuration(maxDuration, allowZero: false);
      
      if (initialDuration != null && initialDuration > maxDuration) {
        throw TimerValidationException(
          'Initial duration cannot exceed maximum duration', 
          'initialDuration'
        );
      }
    }
  }
  
  static void validateStateTransition(TimerState currentState, TimerState targetState) {
    final validTransitions = {
      TimerState.idle: [TimerState.running],
      TimerState.running: [TimerState.paused, TimerState.completed],
      TimerState.paused: [TimerState.running, TimerState.idle],
      TimerState.completed: [TimerState.idle, TimerState.running],
    };
    
    final allowedTransitions = validTransitions[currentState] ?? [];
    
    if (!allowedTransitions.contains(targetState)) {
      throw TimerValidationException(
        'Invalid state transition from $currentState to $targetState',
        'state'
      );
    }
  }
  
  static void safeExecute(VoidCallback operation, {String? operationName}) {
    try {
      operation();
    } catch (e) {
      if (kDebugMode) {
        print('Timer operation failed${operationName != null ? ' ($operationName)' : ''}: $e');
      }
      rethrow;
    }
  }
  
  static T safeExecuteWithReturn<T>(T Function() operation, {String? operationName}) {
    try {
      return operation();
    } catch (e) {
      if (kDebugMode) {
        print('Timer operation failed${operationName != null ? ' ($operationName)' : ''}: $e');
      }
      rethrow;
    }
  }
}