import 'dart:async';

import 'package:gg_time_controller/gg_time_controller.dart';
import 'package:gg_typedefs/gg_typedefs.dart';

void main() async {
  void log(String str) => print('\n$str:');
  final fiveFrames = Duration(
      microseconds:
          ((GgTimeController.defaultFrameDuration * 5 * 1000 * 1000).toInt()));

  /// Listen to time stamps
  void onTimeStamp(GgMilliseconds timeStamp) {
    scheduleMicrotask(
      () => print('    time: $timeStamp'),
    );
  }

  /// Listen to state changes
  void onStateChange(TransportState state) {
    print('  state: ${state.toString().split('.').last}');
  }

  log('Create a time controller');
  final timeController = GgTimeController(onTimeStamp: onTimeStamp);
  timeController.state.listen(onStateChange);

  log('Start playing');
  timeController.play();

  log('Wait for five frames');
  await Future.delayed(fiveFrames);

  // Output:
  //   state: playing
  //     time: 17
  //     time: 33
  //     time: 49
  //     time: 64
  //     time: 81

  log('Pause will also output the last frame');
  timeController.pause();

  // Output:
  //   time: 85

  log('Wait for five frames => No output because controller is paused');
  await Future.delayed(fiveFrames);

  // Output:
  //   state: paused

  log('Stop the controller. Time will be set back to 0');
  timeController.stop();
  await Future.delayed(Duration.zero);

  // Output:
  //   state: stopped
  //     time: 0

  log('Jump to 10s');
  timeController.jumpTo(time: 10.0);
  await Future.delayed(Duration.zero);

  // Output:
  //   time: 1000000

  log('Now play again');
  timeController.play();

  log('Wait for five frames');

  await Future.delayed(fiveFrames);
  timeController.pause();

  // Output:
  //     time: 10017
  //     time: 10033
  //     time: 10050
  //     time: 10065
  //     time: 10082
  //     time: 10083
  //   state: paused
  //     time: 11947

  log('Animate to 20s within 100ms');
  await timeController.animateTo(
    targetTime: 20.0,
    animationDuration: 0.1,
  );
  await Future.delayed(fiveFrames);

  // Output:
  //   state: animatingForward
  //     time: 13578
  //     time: 15107
  //     time: 16736
  //     time: 18255
  //     time: 19879
  //     time: 20000

  log('Animate back 10s within 100ms');
  await timeController.animateTo(
    targetTime: 10.0,
    animationDuration: 0.1,
  );

  // Output:
  //   state: paused
  //   state: animatingBackward
  //     time: 18179
  //     time: 16644
  //     time: 15001
  //     time: 13365
  //     time: 11825
  //     time: 10168
  //     time: 10000
  //   state: paused
}
