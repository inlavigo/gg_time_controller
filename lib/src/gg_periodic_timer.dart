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
abstract class GgPeriodicTimer {
  GgPeriodicTimer({
    required this.onTimerFired,
  });

  /// The callback called when timer fires
  final void Function() onTimerFired;

  /// Returns true if timer is running
  bool get isRunning => _isRunning;

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
  }

  // ######################
  // Private
  // ######################
  bool _isRunning = false;
}

// .............................................................................
/// A periodic timer that needs to be triggered from the outside
class GgManualPeriodicTimer extends GgPeriodicTimer {
  GgManualPeriodicTimer({
    required super.onTimerFired,
  });

  /// Call this method regularly to make the timer fire
  void fire() {
    if (isRunning) {
      super.onTimerFired();
    }
  }
}

// #############################################################################
/// A periodic timer that can be started, stopped and started again
class GgAutoPeriodicTimer extends GgPeriodicTimer {
  GgAutoPeriodicTimer({
    required super.onTimerFired,
    required this.interval,
  });

  /// The interval the timer fires
  final Duration interval;

  /// Start the timer
  @override
  void start() {
    _timer ??= Timer.periodic(interval, (_) => onTimerFired());
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
