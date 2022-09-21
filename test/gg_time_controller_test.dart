// @license
// Copyright (c) 2019 - 2022 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:fake_async/fake_async.dart';
import 'package:gg_time_controller/src/gg_time_controller.dart';
import 'package:gg_time_controller/src/gg_time_stamp.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';
import 'package:mocktail/mocktail.dart';

class FakeStopwatch extends Mock implements Stopwatch {}

void main() {
  late GgTimeController timeController;
  late TransportState state;
  late List<TransportState> states;
  late GgTimeStamp timeStamp;
  const targetTime = Duration(milliseconds: 120);
  late FakeAsync fake;
  late Stopwatch stopwatch;
  late Duration elapsedDuration;
  final frameDuration = GgTimeController.defaultFrameDuration;
  const animationDuration = GgTimeController.defaultAnimationDuration;

  // ...........................................................................
  void initElapsed() {
    elapsedDuration = Duration.zero;
    when(() => stopwatch.reset()).thenAnswer((invocation) {
      elapsedDuration = Duration.zero;
    });
    when(() => stopwatch.elapsed).thenAnswer((invocation) => elapsedDuration);
  }

  // ...........................................................................
  void init(FakeAsync fk) {
    stopwatch = FakeStopwatch();
    initElapsed();

    timeController = exampleTimeController(
      onTimeStamp: (p0) => timeStamp = p0,
      stopwatch: stopwatch,
    );
    fake = fk;
    fake.flushMicrotasks();

    state = timeController.state.value;
    timeStamp = const GgTimeStamp(time: Duration.zero);

    // Listen to state
    states = <TransportState>[];
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
  void expectState(TransportState expected) {
    fake.flushMicrotasks();
    expect(state, expected);
    states.clear();
  }

  // ...........................................................................
  void expectStates(Iterable<TransportState> expected) {
    fake.flushMicrotasks();
    expect(states, expected);
    states.clear();
  }

  // ...........................................................................
  void expectTimeStamp(Duration expected) {
    fake.flushMicrotasks();
    expect(timeStamp, GgTimeStamp(time: expected));
    expect(timeController.time, expected);
    states.clear();
  }

  // ...........................................................................
  void elapseOneFrame() {
    elapsedDuration += frameDuration;
    fake.elapse(frameDuration);
  }

  // ...........................................................................
  void elapse(Duration duration) {
    elapsedDuration += duration;
    fake.elapse(duration);
  }

  group('TimeController', () {
    // #########################################################################
    group('exampleTimeController()', () {
      test('should work as expected', () {
        expect(exampleTimeController(), isNotNull);
      });
    });

    // ...........................................................................
    group('play, pause, stop', () {
      test('should deliver state changes as well the right time stamps', () {
        fakeAsync((fake) {
          init(fake);

          // Initally state should be stopped and no time stamps be delivered
          expectState(TransportState.stopped);
          expectTimeStamp(Duration.zero);

          // .............
          // Start playing.
          // On each frame, a timestamp should be delivered.
          timeController.play();
          expectState(TransportState.playing);
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
          expectState(TransportState.paused);

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
            TransportState.jumpingForward,
            TransportState.paused,
          ]);

          expectTimeStamp(expectedTime);

          // ............................................................
          // Jumping backward should first set state to "jumpingBackward"
          // and then back to the previous state which is "paused".
          timeController.jumpTo(time: Duration.zero);
          expectStates([
            TransportState.jumpingBackward,
            TransportState.paused,
          ]);
          expectedTime = Duration.zero;
          expectTimeStamp(expectedTime);

          // ..........................................................
          // Jumping forward should switch state from stopped to paused
          // when state was stopped before.
          timeController.stop();
          timeController.jumpTo(time: targetTime);
          expectedTime = targetTime;

          expectStates([
            TransportState.stopped,
            TransportState.jumpingForward,
            TransportState.paused,
          ]);

          expectTimeStamp(expectedTime);

          // .............................................
          // Stop playing should set the time back to zero
          timeController.stop();
          fake.flushMicrotasks();
          expect(state, TransportState.stopped);
          expectedTime = Duration.zero;
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
          var expectedTime = Duration.zero;
          expectTimeStamp(expectedTime);

          // .................
          // Animating forward
          timeController.animateTo(
              targetTime: targetTime, animationDuration: animationDuration);

          // should set the state to "animatingForward"
          expectState(TransportState.animatingForward);

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
          expectedTime += Duration.zero;
          expectState(TransportState.paused);
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
            targetTime: Duration.zero,
            animationDuration: animationDuration,
          );

          // should first set state to "animatingBackward"
          expectState(TransportState.animatingBackward);

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
          expectedTime += Duration.zero;
          expectState(TransportState.paused);
          expectTimeStamp(expectedTime); // 4/4

          dispose(fake);
        });
      });

      test('changing an animation inbetween', () {
        fakeAsync((fake) {
          init(fake);

          // Initially we should be at the beginning
          timeController.pause();
          var expectedTime = Duration.zero;
          expectTimeStamp(expectedTime);

          // .................
          // Animating forward
          const animationDuration = GgTimeController.defaultAnimationDuration;
          timeController.animateTo(
              targetTime: targetTime, animationDuration: animationDuration);

          // should set the state to "animatingForward"
          expectState(TransportState.animatingForward);

          // The right animation frames should be delivered
          var animationIncrement = animationDuration * 0.25;
          var timeIncrement = targetTime * 0.25;

          elapse(animationIncrement);
          expectedTime += timeIncrement;
          expectTimeStamp(expectedTime); // 1/4

          elapse(animationIncrement);
          expectedTime += timeIncrement;
          expectTimeStamp(expectedTime); // 2/4

          // While the animation is running,
          // we decide to animate to a different location

          // Animation increment will change
          final changedTargetTime = targetTime * 2;
          animationIncrement = animationDuration * 0.25;
          timeIncrement = (changedTargetTime - timeController.time) * 0.25;

          // Start animation
          timeController.animateTo(targetTime: changedTargetTime);

          // Check if the right frames are emitted
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

          dispose(fake);
        });
      });

      test('should switch from stop state to paused state', () {
        fakeAsync((fake) {
          init(fake);

          // Animation is stopped
          timeController.stop();
          expectState(TransportState.stopped);

          // Animate
          timeController.animateTo(
            targetTime: targetTime,
            animationDuration: animationDuration,
          );
          expectState(TransportState.animatingForward);

          // Wait until animation is finished
          elapse(animationDuration);

          // After animation state should switched to paused
          expectState(TransportState.paused);

          dispose(fake);
        });
      });

      test('should continue normally after end of animation', () {
        fakeAsync((fake) {
          init(fake);

          // Animation is started
          timeController.play();
          expectState(TransportState.playing);

          // Animate
          timeController.animateTo(
            targetTime: targetTime,
            animationDuration: animationDuration,
          );
          expectState(TransportState.animatingForward);

          // Wait until animation is finished
          elapse(animationDuration);

          // After animation state should switched to paused
          expectState(TransportState.playing);

          final timeBefore = timeController.time;
          elapseOneFrame();

          expectTimeStamp(timeBefore + frameDuration);

          dispose(fake);
        });
      });

      test('should work with a non fake stop watch', () {
        fakeAsync((fake) {
          final stopWatch = FakeStopwatch();

          // Prepare stopwatch.elapsed
          var time = 0;
          when(() => stopWatch.elapsed).thenAnswer(
            (invocation) {
              time += frameDuration.inMicroseconds;
              return Duration(microseconds: time);
            },
          );

          // Listen to time stamps
          final receivedTimestamps = <Duration>[];

          timeController = GgTimeController(
            onTimeStamp: (p0) => receivedTimestamps.add(p0.time),
            stopWatch: stopWatch,
          );

          // Start playing
          timeController.play();
          expect(timeController.state.value, TransportState.playing);

          // Wait for ten frames
          fake.elapse(GgTimeController.defaultFrameDuration * 10);

          // Check result
          expect(receivedTimestamps.length, 10);
          expect(receivedTimestamps[0].inMilliseconds, 16);
          expect(receivedTimestamps[1].inMilliseconds, 33);
          expect(receivedTimestamps[2].inMilliseconds, 49);

          timeController.dispose();
        });
      });
    });
  });
}
