// @license
// Copyright (c) 2019 - 2022 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:fake_async/fake_async.dart';
import 'package:gg_time_controller/src/gg_time_controller.dart';
import 'package:gg_typedefs/gg_typedefs.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  late GgTimeController timeController;
  late GgTransportState state;
  late List<GgTransportState> states;
  late GgSeconds timeStamp;
  late List<GgSeconds> timestamps;
  late FakeAsync fake;
  late Stopwatch stopwatch;
  const frameDuration = GgTimeController.defaultFrameDuration;
  const targetTime = GgTimeController.defaultFrameDuration * 100;
  const animationDuration = GgTimeController.defaultAnimationDuration;

  // ...........................................................................
  void init(FakeAsync fk) {
    stopwatch = fk.getClock(DateTime(0)).stopwatch();
    timestamps = [];

    timeController = exampleTimeController(
      onTimeStamp: (p0) {
        timeStamp = p0;
        timestamps.add(p0);
      },
      stopwatch: stopwatch,
    );
    fake = fk;
    fake.flushMicrotasks();

    state = timeController.state.value;
    timeStamp = 0.0;

    // Listen to state
    states = <GgTransportState>[];
    timeController.state.listen((event) {
      state = event;
      states.add(event);
    });
  }

  // ...........................................................................
  void dispose(FakeAsync fake) {
    timeController.dispose();
    fake.flushMicrotasks();
    fake.flushTimers();
  }

  // ...........................................................................
  void expectState(GgTransportState expected) {
    fake.flushMicrotasks();
    expect(state, expected);
    states.clear();
  }

  // ...........................................................................
  void expectStates(Iterable<GgTransportState> expected) {
    fake.flushMicrotasks();
    expect(states, expected);
    states.clear();
  }

  // ...........................................................................
  void expectTimeStamp(GgSeconds expected) {
    fake.flushMicrotasks();
    expect(timeStamp, closeTo(expected, 0.1));
    expect(timeController.time, closeTo(expected, 0.1));
    expect(timeController.timeStream.value, closeTo(expected, 0.1));
    states.clear();
  }

  // ...........................................................................
  void elapseOneFrame() {
    fake.elapse(frameDuration.ggDuration);
  }

  // ...........................................................................
  void elapse(GgSeconds duration) {
    fake.elapse(Duration(microseconds: (duration * 1000.0 * 1000.0).toInt()));
  }

  group('TimeController', () {
    // #########################################################################
    group('exampleTimeController()', () {
      test('should work as expected', () {
        expect(exampleTimeController(), isNotNull);
      });
    });

    // .........................................................................
    group('play, pause, stop', () {
      test('should deliver state changes as well the right time stamps', () {
        fakeAsync((fake) {
          init(fake);

          // Initally state should be stopped and no time stamps be delivered
          expectState(GgTransportState.stopped);
          expectTimeStamp(0.0);

          // .............
          // Start playing.
          // On each frame, a timestamp should be delivered.
          timeController.play();
          expectState(GgTransportState.playing);
          var expectedTime = frameDuration;

          // Wait some frames
          elapseOneFrame();
          expectTimeStamp(expectedTime);

          elapseOneFrame();
          expectedTime += frameDuration;
          expectTimeStamp(expectedTime);

          elapseOneFrame();
          expectedTime += frameDuration;
          expectTimeStamp(expectedTime);

          // .............
          // Pause playing, a half frame after last delivery
          elapse(frameDuration * 0.5);
          expectedTime += frameDuration * 0.5;

          timeController.pause();
          expectState(GgTransportState.paused);

          // The current time should be delivered from now
          elapseOneFrame();
          expectTimeStamp(expectedTime);

          elapseOneFrame();
          expectTimeStamp(expectedTime);

          // ..........
          // Play again
          timeController.play();
          elapseOneFrame();
          expectedTime += frameDuration;
          expectTimeStamp(expectedTime);

          // ...........
          // Pause again
          timeController.pause();
          expectTimeStamp(expectedTime);

          // ..........................................................
          // Jumping forward should first set state to "jumpingForward"
          // and then back to the previous state which is "paused".
          timeController.jumpTo(time: targetTime);
          expectedTime = targetTime;

          expectStates([
            GgTransportState.jumpingForward,
            GgTransportState.paused,
          ]);

          expectTimeStamp(expectedTime);

          // ............................................................
          // Jumping backward should first set state to "jumpingBackward"
          // and then back to the previous state which is "paused".
          timeController.jumpTo(time: 0.0);
          expectStates([
            GgTransportState.jumpingBackward,
            GgTransportState.paused,
          ]);
          expectedTime = 0.0;
          expectTimeStamp(expectedTime);

          // ..........................................................
          // Jumping forward should switch state from stopped to paused
          // when state was stopped before.
          timeController.stop();
          timeController.jumpTo(time: targetTime);
          expectedTime = targetTime;

          expectStates([
            GgTransportState.stopped,
            GgTransportState.jumpingForward,
            GgTransportState.paused,
          ]);

          expectTimeStamp(expectedTime);

          // .............................................
          // Stop playing should set the time back to zero
          timeController.stop();
          fake.flushMicrotasks();
          expect(state, GgTransportState.stopped);
          expectedTime = 0.0;
          expectTimeStamp(expectedTime);

          dispose(fake);
        });
      });
    });

    // #########################################################################
    group('animateTo(time, duration)', () {
      test('animating forward', () {
        fakeAsync((fake) {
          init(fake);

          // Initially we should be at the beginning
          timeController.pause();
          var expectedTime = 0.0;
          expectTimeStamp(expectedTime);

          // .................
          // Animating forward
          timeController.animateTo(
            targetTime: targetTime,
            animationDuration: animationDuration,
          );

          // should set the state to "animatingForward"
          expectState(GgTransportState.animatingForward);

          // The right animation frames should be delivered
          var animationIncrement = animationDuration * 0.25;
          var timeIncrement = targetTime * 0.25;

          elapse(animationIncrement);
          expectedTime += timeIncrement;
          expectTimeStamp(expectedTime); // 1/4

          elapse(animationIncrement);
          expectedTime += timeIncrement;
          expectTimeStamp(expectedTime); // 2/4

          elapse(animationIncrement);
          expectedTime += timeIncrement;
          expectTimeStamp(expectedTime); // 3/4

          elapse(animationIncrement);
          expectedTime += timeIncrement;
          expectTimeStamp(expectedTime); // 4/4

          // After animation the state goes back to paused.
          // Time does not go forward anymore.
          elapse(animationIncrement);
          expectedTime += 0.0;
          expectState(GgTransportState.paused);
          expectTimeStamp(expectedTime); // 4/4

          dispose(fake);
        });
      });

      // .......................................................................
      test('animate backward', () {
        fakeAsync((fake) {
          init(fake);

          // ...............................
          // Initially we are at target time
          var expectedTime = targetTime;
          timeController.pause();
          timeController.jumpTo(time: targetTime);
          fake.flushMicrotasks();
          expectTimeStamp(expectedTime);

          // ..................
          // Animating backward

          // Animate back to zero
          timeController.animateTo(
            targetTime: 0.0,
            animationDuration: animationDuration,
          );

          // should first set state to "animatingBackward"
          expectState(GgTransportState.animatingBackward);

          // The right animation frames should be delivered
          var animationIncrement = animationDuration * 0.25;
          var timeIncrement = -targetTime * 0.25;

          elapse(animationIncrement);
          expectedTime += timeIncrement;
          expectTimeStamp(expectedTime); // 1/4

          elapse(animationIncrement);
          expectedTime += timeIncrement;
          expectTimeStamp(expectedTime); // 2/4

          elapse(animationIncrement);
          expectedTime += timeIncrement;
          expectTimeStamp(expectedTime); // 3/4

          elapse(animationIncrement);
          expectedTime += timeIncrement;
          expectTimeStamp(expectedTime); // 4/4

          // After animation the state goes back to paused.
          // Time does not go forward anymore.
          elapse(animationIncrement);
          expectedTime += 0.0;
          expectState(GgTransportState.paused);
          expectTimeStamp(expectedTime); // 4/4

          dispose(fake);
        });
      });

      test('changing an animation inbetween', () {
        fakeAsync((fake) {
          init(fake);

          // Initially we should be at the beginning
          timeController.pause();
          var expectedTime = 0.0;
          expectTimeStamp(expectedTime);

          // .................
          // Animating forward
          const animationDuration = GgTimeController.defaultAnimationDuration;
          timeController.animateTo(
            targetTime: targetTime,
            animationDuration: animationDuration,
          );

          // should set the state to "animatingForward"
          expectState(GgTransportState.animatingForward);

          // The right animation frames should be delivered
          var animationIncrement = animationDuration * 0.25;
          var timeIncrement = targetTime * 0.25;

          elapse(animationIncrement);
          expectedTime += timeIncrement;
          expectTimeStamp(expectedTime); // 1/4

          elapse(animationIncrement);
          expectedTime += timeIncrement;
          expectTimeStamp(expectedTime); // 2/4

          // ..............................
          // While the animation is running,
          // we decide to animate to a different time

          // Animation increment will change
          const changedTargetTime = targetTime * 100;
          animationIncrement = animationDuration * 0.25;
          timeIncrement = (changedTargetTime - timeController.time) * 0.25;

          // Start animation
          timestamps = [];
          timeController.animateTo(targetTime: changedTargetTime);
          fake.elapse(animationDuration.ggDuration);

          // Check if the right frames are emitted
          final expectedTimestamps = [
            4.281666666666671,
            8.44333333333334,
            12.604999999999999,
            16.766666666666673,
            20.928333333333338,
            25.09,
            29.25166666666667,
            33.41333333333334,
            37.574999999999996,
            41.736666666666665,
            45.89833333333334,
            50.059999999999995,
            54.22166666666667,
            58.38333333333333,
            62.54500000000001,
            66.70666666666669,
            70.86833333333333,
            75.03,
            79.19166666666668,
            83.35333333333334,
            87.51500000000001,
            91.67666666666669,
            95.83833333333332,
            100.0,
          ];

          expect(timestamps.length, expectedTimestamps.length);
          for (int i = 0; i < timestamps.length; i++) {
            expect(timestamps[i], closeTo(expectedTimestamps[i], 0.0001));
          }

          dispose(fake);
        });
      });

      test('should switch from stop state to paused state', () {
        fakeAsync((fake) {
          init(fake);

          // Animation is stopped
          timeController.stop();
          expectState(GgTransportState.stopped);

          // Animate
          timeController.animateTo(
            targetTime: targetTime,
            animationDuration: animationDuration,
          );
          expectState(GgTransportState.animatingForward);

          // Wait until animation is finished
          elapse(animationDuration);

          // After animation state should switched to paused
          expectState(GgTransportState.paused);

          dispose(fake);
        });
      });

      test('should continue normally after end of animation', () {
        fakeAsync((fake) {
          init(fake);

          // Animation is started
          timeController.play();
          expectState(GgTransportState.playing);

          // Animate
          timeController.animateTo(
            targetTime: targetTime,
            animationDuration: animationDuration,
          );
          expectState(GgTransportState.animatingForward);

          // Wait until animation is finished
          elapse(animationDuration);

          // After animation state should switched to paused
          expectState(GgTransportState.playing);

          final timeBefore = timeController.time;
          elapseOneFrame();

          expectTimeStamp(timeBefore + frameDuration);

          dispose(fake);
        });
      });

      test('should work with a non fake stop watch', () {
        fakeAsync((fake) {
          init(fake);

          // Listen to time stamps
          final receivedTimestamps = <GgSeconds>[];

          timeController = GgTimeController(
            onTimeStamp: (p0) => receivedTimestamps.add(p0),
            stopwatch: stopwatch,
          );

          // Start playing
          timeController.play();
          expect(timeController.state.value, GgTransportState.playing);

          // Wait for ten frames
          fake.elapse(GgTimeController.defaultFrameDuration.ggDuration * 10);

          // Check result
          expect(receivedTimestamps.length, 10);
          expect(receivedTimestamps[0].ggDuration.inMilliseconds, 10);
          expect(receivedTimestamps[1].ggDuration.inMilliseconds, 20);
          expect(receivedTimestamps[2].ggDuration.inMilliseconds, 30);

          timeController.dispose();

          dispose(fake);
        });
      });
    });
  });
}
