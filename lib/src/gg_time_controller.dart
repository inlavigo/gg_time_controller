// @license
// Copyright (c) 2019 - 2022 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

// .............................................................................
import 'dart:async';

import 'package:gg_value/gg_value.dart';

import 'gg_periodic_timer.dart';
import 'gg_time_stamp.dart';
import 'typedefs.dart';

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
/// Delivers time stamps. Can be started, paused, stopped. Jumping as well
/// animating to a given time is possible.
class GgTimeController {
  // ...........................................................................
  GgTimeController({
    required this.onTimeStamp,
    this.frameRate = defaultFrameRate,
    GgPeriodicTimer? timer,
    Stopwatch? stopWatch,
  }) : frameDuration = _calcFrameDuration(frameRate) {
    _init();
    _initTimer(timer);
    _initStopWatch(stopWatch);
  }

  /// The default animation duration used by [animateTo]
  static const defaultAnimationDuration = Duration(milliseconds: 120);

  /// The default frame rate on which time stamps are delivered
  static const defaultFrameRate = 60.0;

  /// The default duration between two delivered time stamps
  static Duration get defaultFrameDuration =>
      GgTimeController._calcFrameDuration(defaultFrameRate);

  /// This function will periodically called with updated timestamps
  final OnTimeStamp onTimeStamp;

  /// Returns the transport state as stream
  GgValueStream<TransportState> get state => _state.stream;

  /// How often are time stamps emitted?
  final double frameRate;

  /// How long does it take between two emits?
  final Duration frameDuration;

  /// Returns the current time in seconds.
  Duration get time => _time;

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
    _lastTime = Duration.zero;
    _updateStopwatchOffset(Duration.zero);
    _timerFired();
  }

  /// Jump to a given time
  void jumpTo({required Duration time}) {
    if (time == _clockTime) {
      return;
    }

    final stateBefore = _state.value;
    _state.value = _jumpState(time);

    _state.value = time == Duration.zero ? stateBefore : TransportState.paused;
    _lastTime = time;
    _updateStopwatchOffset(time);
    _timerFired();
  }

  /// Animate to a given time in a given duration.
  Future<void> animateTo({
    required Duration targetTime,
    Duration animationDuration = defaultAnimationDuration,
  }) async {
    _animationTargetTime = targetTime.inMicroseconds.toDouble();
    _animationStartTime = _clockTime.inMicroseconds.toDouble();
    _animationDuration = animationDuration.inMicroseconds.toDouble();

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

    // Switch to paused, if state was stopped before and time is not 0
    if (stateBefore == TransportState.stopped && _lastTime != Duration.zero) {
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
  Duration _lastTime = Duration.zero;
  Duration get _clockTime {
    return _stopwatch.elapsed - _stopwatchOffset;
  }

  // ...........................................................................
  Duration get _time {
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
  Duration _stopwatchOffset = Duration.zero;

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

    onTimeStamp(GgTimeStamp(time: _lastTime));
  }

  // ...........................................................................
  void _initTimer(GgPeriodicTimer? timer) {
    if (timer == null) {
      _timer = timer ??
          GgPeriodicTimer(
            onTimerFired: _timerFired,
            interval: frameDuration,
          );
      _dispose.add(_timer.dispose);
    }
  }

  // ...........................................................................
  void _initStopWatch(Stopwatch? stopwatch) {
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
  TransportState _jumpState(Duration newTime) => newTime > _clockTime
      ? TransportState.jumpingForward
      : TransportState.jumpingBackward;

  // ...........................................................................
  TransportState _animateState(Duration newTime) => newTime > _clockTime
      ? TransportState.animatingForward
      : TransportState.animatingBackward;

  // ...........................................................................
  MicroSeconds _animationTargetTime = 0;
  MicroSeconds _animationDuration = 0;
  MicroSeconds _animationStartTime = 0;
  Completer? _isAnimating;

  // ...........................................................................
  Duration get _animatedTime {
    final animatingForward = state.value == TransportState.animatingForward;
    final duration = animatingForward
        ? _animationTargetTime - _animationStartTime
        : _animationStartTime - _animationTargetTime;

    // Calc progress
    final timeProgress = _clockTime.inMicroseconds - _animationStartTime;
    MicroSeconds progress = timeProgress / _animationDuration;

    if (!animatingForward) {
      progress *= -1;
    }

    // Result
    final result = (_animationStartTime + duration * progress).toInt();

    return Duration(microseconds: result.toInt());
  }

  // ........................................................ ...................
  void _animate() {
    if (_isAnimating == null) {
      return;
    }

    // Animation finished?
    final clockTime = _clockTime.inMicroseconds;
    final isReady = (clockTime - _animationStartTime) >= _animationDuration;

    if (isReady) {
      _isAnimating!.complete(null);
      _isAnimating = null;
      _lastTime = Duration(microseconds: _animationTargetTime.toInt());
      _updateStopwatchOffset(_lastTime);
      _animationTargetTime = 0;

      return;
    }

    // Calc progress
    _lastTime = _animatedTime;
  }

  // ...........................................................................
  static Duration _calcFrameDuration(double frameRate) =>
      Duration(microseconds: ((1.0 / frameRate) * 1000 * 1000).toInt());

  // ...........................................................................
  void _updateStopwatchOffset(Duration expectedTime) {
    _stopwatchOffset = _stopwatch.elapsed - expectedTime;
  }
}

// #############################################################################
GgTimeController exampleTimeController({
  OnTimeStamp? onTimeStamp,
  Stopwatch? stopwatch,
}) =>
    GgTimeController(
      onTimeStamp: onTimeStamp ?? (_) {}, // coverage:ignore-line
      stopWatch: stopwatch,
    );
