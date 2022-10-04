// @license
// Copyright (c) 2019 - 2022 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

// .............................................................................
import 'dart:async';
import 'package:meta/meta.dart';

// .............................................................................
/// A periodic timer that can be started, stopped and started again
class GgPeriodicTimer {
  GgPeriodicTimer();

  /// All listeners
  final listeners = <void Function()>[];

  /// Add a listener that is informed when the timer fires
  void addListener(void Function() listener) {
    assert(!listeners.contains(listener));
    listeners.add(listener);
  }

  /// Remove a listener added before
  void removeListener(void Function() listener) {
    assert(listeners.contains(listener));
    listeners.remove(listener);
  }

  /// Returns true if timer is running
  bool get isRunning => _isRunning;

  /// Call this method regularly to make the timer fire
  void fire() {
    if (isRunning) {
      for (final listener in listeners) {
        listener();
      }
    }
  }

  /// Start the timer
  @mustCallSuper
  void start() {
    _isRunning = true;
  }

  /// Stop the timer
  /// @mustCallSuper
  void stop() {
    _isRunning = false;
  }

  /// Dispose the timer
  /// @mustCallSuper
  void dispose() {
    stop();
    listeners.clear();
  }

  // ######################
  // Private
  // ######################
  bool _isRunning = false;
}

// #############################################################################
/// A periodic timer that can be started, stopped and started again
class GgAutoPeriodicTimer extends GgPeriodicTimer {
  GgAutoPeriodicTimer({
    required this.interval,
  });

  /// The interval the timer fires
  final Duration interval;

  /// Start the timer
  @override
  void start() {
    _timer ??= Timer.periodic(interval, (_) => fire());
    super.start();
  }

  /// Stop the timer
  @override
  void stop() {
    _timer?.cancel();
    _timer = null;
    super.stop();
  }

  /// Returns true if timer is running
  @override
  bool get isRunning {
    return _timer != null;
  }

  // ######################
  // Private
  // ######################

  Timer? _timer;
}
