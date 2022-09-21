// @license
// Copyright (c) 2019 - 2022 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

// .............................................................................
import 'dart:async';

/// A periodic timer that can be started, stopped and started again
class GgPeriodicTimer {
  GgPeriodicTimer({
    required this.onTimerFired,
    required this.interval,
  });

  /// The callback called when timer fires
  final void Function() onTimerFired;

  /// The interval the timer fires
  final Duration interval;

  /// Start the timer
  void start() {
    _timer ??= Timer.periodic(interval, (_) => onTimerFired());
  }

  /// Stop the timer
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Returns true if timer is running
  bool get isRunning => _timer != null;

  /// Dispose the timer
  void dispose() {
    stop();
  }

  // ######################
  // Private
  // ######################

  Timer? _timer;
}
