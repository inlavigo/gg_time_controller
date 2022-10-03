// @license
// Copyright (c) 2019 - 2022 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

// .............................................................................
import 'dart:async';

import 'package:gg_typedefs/gg_typedefs.dart';
import 'package:gg_value/gg_value.dart';

import 'gg_periodic_timer.dart';

// .............................................................................
/// Different states of the time controller
enum TransportState {
  playing,
  paused,
  stopped,
  jumpingForward,
  jumpingBackward,
  animatingForward,
  animatingBackward,
}

// .............................................................................
typedef OnTimeStamp = Function(GgSeconds);

// .............................................................................
extension GgDurationExtension on Duration {
  GgSeconds get secondsD => inMicroseconds / 1000000.0;
}

// .............................................................................
extension SecondsToDuration on GgSeconds {
  Duration get toDuration =>
      Duration(microseconds: (this * 1000 * 1000).toInt());
}

// .............................................................................
/// Delivers time stamps. Can be started, paused, stopped. Jumping as well
/// animating to a given time is possible.
class GgTimeController {
  // ...........................................................................
  GgTimeController({
    required this.onTimeStamp,
    this.frameRate = defaultFrameRate,
    GgPeriodicTimer? timer,
    Stopwatch? stopwatch,
  }) : frameDuration = 1.0 / frameRate {
    _init();
    _initTimer(timer);
    _initStopwatch(stopwatch);
  }

  /// The default animation duration used by [animateTo]
  static const GgSeconds defaultAnimationDuration = defaultFrameDuration * 24;

  /// The default frame rate on which time stamps are delivered
  static const defaultFrameRate = 1.0 / defaultFrameDuration;

  /// The default duration between two delivered time stamps
  static const GgSeconds defaultFrameDuration = 0.010;

  /// This function will periodically called with updated timestamps
  final OnTimeStamp onTimeStamp;

  /// Returns the transport state as stream
  GgValueStream<TransportState> get state => _state.stream;

  /// How often are time stamps emitted?
  final double frameRate;

  /// How long does it take between two emits?
  final GgSeconds frameDuration;

  /// Returns the current time in seconds.
  GgSeconds get time => _time;

  /// Starts playing
  void play() {
    if (_state.value != TransportState.playing) {
      _state.value = TransportState.playing;
      _timer.start();
      _stopwatch.start();
      _updateStopwatchOffset(_lastTime);
    }
  }

  /// Pauses playing
  void pause() {
    if (_state.value != TransportState.paused) {
      _state.value = TransportState.paused;
      _timer.stop();
      if (_lastTime != _clockTime) {
        _lastTime = _clockTime;
        _timerFired();
      }
    }
  }

  /// Stops playing. Time is set back to 0.
  void stop() {
    if (_state.value != TransportState.stopped) {
      _state.value = TransportState.stopped;
    }
    _stopwatch.stop();
    _timer.stop();
    _stopwatch.reset();
    _lastTime = 0.0;
    _updateStopwatchOffset(0.0);
    _timerFired();
  }

  /// Jump to a given time
  void jumpTo({required GgSeconds time}) {
    if (time == _clockTime) {
      return;
    }

    final stateBefore = _state.value;
    _state.value = _jumpState(time);

    _state.value = time == 0.0 ? stateBefore : TransportState.paused;
    _lastTime = time;
    _updateStopwatchOffset(time);
    _timerFired();
  }

  /// Animate to a given time in a given duration.
  Future<void> animateTo({
    required GgSeconds targetTime,
    GgSeconds animationDuration = defaultAnimationDuration,
  }) async {
    _animationTargetTime = targetTime;
    _animationStartTime = _clockTime;
    _animationDuration = animationDuration;

    // If an animation is already in progress, we are done here.
    if (_isAnimating != null) {
      return _isAnimating!.future;
    }

    _isAnimating = Completer();

    // Remember state before animation
    final stateBefore = _state.value;

    // Start timer, otherwise no progress
    final timerWasRunning = _timer.isRunning;
    _timer.start();

    // We need to start the stopwatch. Otherwise we cannot calc time progress.
    final stopwatchWasRunning = _stopwatch.isRunning;
    _stopwatch.start();

    // Switch the state
    _state.value = _animateState(targetTime);

    // Wait until animation is done
    await _isAnimating!.future;
    _isAnimating = null;

    // Update stopwatch offset
    _updateStopwatchOffset(targetTime);

    // Restore the state before animation
    if (!timerWasRunning) {
      _timer.stop();
    }

    if (!stopwatchWasRunning) {
      _stopwatch.stop();
    }

    // Switch to paused, if state was stopped before and time is not 0
    if (stateBefore == TransportState.stopped && _lastTime != 0.0) {
      _state.value = TransportState.paused;
    } else {
      _state.value = stateBefore;
    }
  }

  /// Call this method if the time controller is not needed ynamore
  void dispose() {
    for (final d in _dispose.reversed) {
      d();
    }
  }

  // ######################
  // Private
  // ######################

  // ...........................................................................
  final List<Function()> _dispose = [];
  GgSeconds _lastTime = 0.0;
  GgSeconds get _clockTime {
    return _stopwatch.elapsed.secondsD - _stopwatchOffset;
  }

  // ...........................................................................
  GgSeconds get _time {
    switch (state.value) {
      case TransportState.playing:
        return _clockTime;
      case TransportState.animatingForward:
      case TransportState.animatingBackward:
        return _animatedTime;
      default:
        return _lastTime;
    }
  }

  late GgPeriodicTimer _timer;
  GgSeconds _stopwatchOffset = 0.0;

  late Stopwatch _stopwatch;

  // ...........................................................................
  void _init() {
    _dispose.add(() {});
    _initState();
  }

  // ...........................................................................
  void _timerFired() {
    _animate();
    _lastTime = state.value == TransportState.playing ? _clockTime : _lastTime;

    onTimeStamp(_lastTime);
  }

  // ...........................................................................
  void _initTimer(GgPeriodicTimer? timer) {
    if (timer == null) {
      _timer = timer ??
          GgPeriodicTimer(
            onTimerFired: _timerFired,
            interval:
                Duration(microseconds: (frameDuration * 1000 * 1000).toInt()),
          );
      _dispose.add(_timer.dispose);
    }
  }

  // ...........................................................................
  void _initStopwatch(Stopwatch? stopwatch) {
    _stopwatch = stopwatch ?? Stopwatch();
  }

  // ...........................................................................
  final _state = GgValue(seed: TransportState.stopped, spam: true);
  void _initState() {
    _dispose.add(() {
      _state.value = TransportState.stopped;
      _state.dispose();
    });
  }

  // ...........................................................................
  TransportState _jumpState(GgSeconds newTime) => newTime > _clockTime
      ? TransportState.jumpingForward
      : TransportState.jumpingBackward;

  // ...........................................................................
  TransportState _animateState(GgSeconds newTime) => newTime > _clockTime
      ? TransportState.animatingForward
      : TransportState.animatingBackward;

  // ...........................................................................
  GgSeconds _animationTargetTime = 0;
  GgSeconds _animationDuration = 0;
  GgSeconds _animationStartTime = 0;
  Completer? _isAnimating;

  // ...........................................................................
  GgSeconds get _animatedTime {
    final animatingForward = state.value == TransportState.animatingForward;
    final duration = animatingForward
        ? _animationTargetTime - _animationStartTime
        : _animationStartTime - _animationTargetTime;

    // Calc progress
    final timeProgress = _clockTime - _animationStartTime;
    GgMicroseconds progress = timeProgress / _animationDuration;

    if (!animatingForward) {
      progress *= -1;
    }

    // Result
    final result = _animationStartTime + duration * progress;

    return result;
  }

  // ........................................................ ...................
  void _animate() {
    if (_isAnimating == null) {
      return;
    }

    // Animation finished?
    final clockTime = _clockTime;
    final isReady = (clockTime - _animationStartTime) >= _animationDuration;

    if (isReady) {
      _isAnimating!.complete(null);
      _isAnimating = null;
      _lastTime = _animationTargetTime;
      _updateStopwatchOffset(_lastTime);
      _animationTargetTime = 0;

      return;
    }

    // Calc progress
    _lastTime = _animatedTime;
  }

  // ...........................................................................
  void _updateStopwatchOffset(GgSeconds expectedTime) {
    _stopwatchOffset = _stopwatch.elapsed.secondsD - expectedTime;
  }
}

// #############################################################################
GgTimeController exampleTimeController({
  OnTimeStamp? onTimeStamp,
  Stopwatch? stopwatch,
}) =>
    GgTimeController(
      onTimeStamp: onTimeStamp ?? (_) {}, // coverage:ignore-line
      stopwatch: stopwatch,
    );
