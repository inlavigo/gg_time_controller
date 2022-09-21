// @license
// Copyright (c) 2019 - 2022 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

// .............................................................................
/// Callback called with a timestamp
typedef OnTimeStamp = Function(GgTimeStamp);

// .............................................................................
/// A time stamp delivered by the time controller.
class GgTimeStamp {
  const GgTimeStamp({required this.time});
  final Duration time;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is GgTimeStamp && time == other.time;

  @override
  int get hashCode => time.hashCode;

  @override
  String toString() {
    return time.inMicroseconds.toString();
  }
}
