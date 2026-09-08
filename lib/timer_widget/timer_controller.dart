import 'dart:async';
import 'package:flutter/foundation.dart';
import 'timer_models.dart';
import 'timer_error_handler.dart';

class TimerController extends ChangeNotifier {
  TimerStateData _stateData;
  TimerConfiguration _configuration;
  Timer? _timer;
  DateTime? _startTime;
  DateTime? _pausedTime;
  Duration _accumulatedTime = Duration.zero;
  int _lapCounter = 0;
  bool _isDisposed = false;

  TimerController({
    TimerConfiguration? configuration,
  })  : _configuration = configuration ?? const TimerConfiguration(),
        _stateData = TimerStateData(
          state: TimerState.idle,
          currentTime: configuration?.initialDuration ?? Duration.zero,
          initialTime: configuration?.initialDuration,
          mode: configuration?.mode ?? TimerMode.countdown,
        ) {
    _validateInitialConfiguration();
    if (_configuration.autoStart) {
      start();
    }
  }

  TimerStateData get stateData => _stateData;
  TimerConfiguration get configuration => _configuration;
  bool get isDisposed => _isDisposed;

  void _validateInitialConfiguration() {
    TimerErrorHandler.safeExecute(() {
      TimerErrorHandler.validateConfiguration(
        initialDuration: _configuration.initialDuration,
        maxDuration: _configuration.maxDuration,
        allowNegative: _configuration.allowNegative,
      );
    }, operationName: 'initial configuration validation');
  }

  void updateConfiguration(TimerConfiguration newConfiguration) {
    TimerErrorHandler.safeExecute(() {
      if (_stateData.state != TimerState.idle) {
        if (kDebugMode) {
          print('Configuration can only be updated when the timer is idle.');
        }
        return;
      }

      TimerErrorHandler.validateConfiguration(
        initialDuration: newConfiguration.initialDuration,
        maxDuration: newConfiguration.maxDuration,
        allowNegative: newConfiguration.allowNegative,
      );
      
      _configuration = newConfiguration;
      
      _stateData = _stateData.copyWith(
        currentTime: newConfiguration.initialDuration ?? Duration.zero,
        initialTime: newConfiguration.initialDuration,
        mode: newConfiguration.mode,
        progress: _calculateProgress(newConfiguration.initialDuration ?? Duration.zero),
      );
      _notifyListeners();
    }, operationName: 'configuration update');
  }

  void start() {
    TimerErrorHandler.safeExecute(() {
      TimerErrorHandler.validateStateTransition(_stateData.state, TimerState.running);
      
      if (_stateData.state == TimerState.idle && 
          _configuration.mode == TimerMode.countdown &&
          (_configuration.initialDuration == null || _configuration.initialDuration == Duration.zero)) {
        throw TimerValidationException(
          'Cannot start countdown timer without initial duration',
          'initialDuration'
        );
      }

      _startTime = DateTime.now();
      _pausedTime = null;
      _accumulatedTime = Duration.zero;

      if (_stateData.state == TimerState.completed) {
        _stateData = _stateData.copyWith(
          state: TimerState.running,
          currentTime: _configuration.initialDuration ?? Duration.zero,
        );
      } else {
        _stateData = _stateData.copyWith(state: TimerState.running);
      }

      _startTimer();
      _notifyListeners();
    }, operationName: 'start timer');
  }

  void pause() {
    TimerErrorHandler.safeExecute(() {
      TimerErrorHandler.validateStateTransition(_stateData.state, TimerState.paused);
      
      _timer?.cancel();
      _pausedTime = DateTime.now();
      _stateData = _stateData.copyWith(state: TimerState.paused);
      _notifyListeners();
    }, operationName: 'pause timer');
  }

  void resume() {
    TimerErrorHandler.safeExecute(() {
      TimerErrorHandler.validateStateTransition(_stateData.state, TimerState.running);
      
      if (_pausedTime != null && _startTime != null) {
        _accumulatedTime += _pausedTime!.difference(_startTime!);
      }
      _startTime = DateTime.now();
      _pausedTime = null;
      _stateData = _stateData.copyWith(state: TimerState.running);

      _startTimer();
      _notifyListeners();
    }, operationName: 'resume timer');
  }

  void reset() {
    TimerErrorHandler.safeExecute(() {
      _timer?.cancel();
      _startTime = null;
      _pausedTime = null;
      _accumulatedTime = Duration.zero;
      _lapCounter = 0;

      _stateData = _stateData.copyWith(
        state: TimerState.idle,
        currentTime: _configuration.initialDuration ?? Duration.zero,
        lapTimes: [],
        progress: _calculateProgress(_configuration.initialDuration ?? Duration.zero),
      );
      _notifyListeners();
    }, operationName: 'reset timer');
  }

  void recordLap() {
    TimerErrorHandler.safeExecute(() {
      if (_stateData.state != TimerState.running) {
        throw TimerValidationException(
          'Can only record laps while timer is running',
          'state'
        );
      }

      if (_stateData.mode != TimerMode.stopwatch) {
        throw TimerValidationException(
          'Lap recording is only available in stopwatch mode',
          'mode'
        );
      }

      _lapCounter++;
      final lapTime = LapTime(
        lapNumber: _lapCounter,
        time: _stateData.currentTime,
        totalTime: _stateData.currentTime,
      );

      final updatedLaps = List<LapTime>.from(_stateData.lapTimes)..add(lapTime);
      _stateData = _stateData.copyWith(lapTimes: updatedLaps);
      _notifyListeners();
    }, operationName: 'record lap');
  }

  void setDuration(Duration duration) {
    TimerErrorHandler.safeExecute(() {
      TimerErrorHandler.validateDuration(duration, allowZero: true);
      
      if (_stateData.state != TimerState.idle) {
        throw TimerValidationException(
          'Can only set duration when timer is idle',
          'state'
        );
      }

      _configuration = _configuration.copyWith(initialDuration: duration);
      _stateData = _stateData.copyWith(
        currentTime: duration,
        initialTime: duration,
        progress: _calculateProgress(duration),
      );
      _notifyListeners();
    }, operationName: 'set duration');
  }

  void _startTimer() {
    _timer?.cancel();
    
    const frameDuration = Duration(milliseconds: 16); // ~60 FPS
    _timer = Timer.periodic(frameDuration, (timer) {
      _updateTimer();
    });
  }

  void _updateTimer() {
    if (_isDisposed || _startTime == null) return;

    final now = DateTime.now();
    final elapsed = now.difference(_startTime!) + _accumulatedTime;

    Duration newTime;
    double? progress;

    try {
      if (_configuration.mode == TimerMode.countdown) {
        final initialTime = _configuration.initialDuration ?? Duration.zero;
        newTime = initialTime - elapsed;
        
        if (newTime <= Duration.zero) {
          newTime = Duration.zero;
          progress = 0.0;
          _onTimerComplete();
          return;
        } else {
          progress = _calculateProgress(newTime);
        }
      } else {
        // Stopwatch mode
        newTime = elapsed;
        progress = null;
      }

      _configuration.onTick?.call(newTime);
      _stateData = _stateData.copyWith(
        currentTime: newTime,
        progress: progress,
      );
      _notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Timer update error: $e');
      }
      _timer?.cancel();
    }
  }

  void _onTimerComplete() {
    _timer?.cancel();
    _stateData = _stateData.copyWith(
      state: TimerState.completed,
      currentTime: Duration.zero,
      progress: 0.0,
    );
    _configuration.onComplete?.call();
    _notifyListeners();
  }

  double _calculateProgress(Duration remainingTime) {
    final initialTime = _configuration.initialDuration ?? Duration.zero;
    if (initialTime == Duration.zero) return 0.0;
    
    final progress = remainingTime.inMilliseconds / initialTime.inMilliseconds;
    return progress.clamp(0.0, 1.0);
  }

  void _notifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _timer?.cancel();
    super.dispose();
  }
}