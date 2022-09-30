// @license
// Copyright (c) 2019 - 2022 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

typedef Seconds = double;
typedef MilliSeconds = double;
typedef MicroSeconds = double;

extension SecondsToDuration on Seconds {
  Duration get duration => Duration(microseconds: (this * 1000 * 1000).toInt());
}
