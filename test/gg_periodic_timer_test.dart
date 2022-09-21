// @license
// Copyright (c) 2019 - 2022 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:fake_async/fake_async.dart';
import 'package:gg_time_controller/src/gg_periodic_timer.dart';
import 'package:test/test.dart';

void main() {
  late GgPeriodicTimer periodicTimer;
  int counter = 0;
  const frameDuration = Duration(milliseconds: 120);
  late FakeAsync fake;
  var expectedCounter = 0;

  void init(FakeAsync fk) {
    expectedCounter = 0;
    fake = fk;
    counter = 0;

    periodicTimer = GgPeriodicTimer(
      interval: frameDuration,
      onTimerFired: () => counter++,
    );
    fake.flushMicrotasks();
  }

  void dispose(FakeAsync fake) {
    fake.flushMicrotasks();
  }

  void testFiringTenTimes() {
    counter = 0;
    fake.elapse(frameDuration * 10);
    expectedCounter = 10;
    expect(counter, expectedCounter);
  }

  void testNotFiringTenTimes() {
    counter = 0;
    fake.elapse(frameDuration * 10);
    expectedCounter = 0;
    expect(counter, expectedCounter);
  }

  group('PeriodicTimer', () {
    // #########################################################################
    group('start, stop, dispose', () {
      test('should start, stop calling timeFired', () {
        fakeAsync((fake) {
          init(fake);
          expect(periodicTimer, isNotNull);

          // Initially timerFired is not called
          expect(counter, expectedCounter);

          // Timer is not yet started.
          // Timer will not be fired.
          fake.elapse(const Duration(seconds: 10));
          expect(counter, expectedCounter);

          // Start the timer
          periodicTimer.start();

          // Wait a half frame => timer has not yet fired
          fake.elapse(frameDuration * 0.5);
          expect(counter, expectedCounter);

          // Wait another half frame => timer has fired
          fake.elapse(frameDuration * 0.5);
          expectedCounter++;
          expect(counter, expectedCounter);

          // Wait another ten freams => timer has fired ten times
          testFiringTenTimes();

          // Stop the timer again
          periodicTimer.stop();

          // Timer should not fire anymore
          testNotFiringTenTimes();

          // Start timer again
          periodicTimer.start();

          // Wait another ten freams => timer has fired ten times
          testFiringTenTimes();

          // Dispose the timer
          periodicTimer.dispose();

          // Timer should not fire anymore
          testNotFiringTenTimes();

          dispose(fake);
        });
      });
    });
  });
}
