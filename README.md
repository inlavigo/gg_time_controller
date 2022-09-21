A time controller for media players with `play`, `pause`, `stop`, `jumpTo` and `animateTo` methods.

## Features

In media player apps like video players, time control is needed. We need to be
able to play, stop, forward, and backward time. Exactly this is realized with
`GgTimeController`.

* Delivers time stamps on a frame basis
* `start`, `stop`, `pause` delivering time stamps.
* Animate or jump to a given time using `animateTo` and `jumpTo`

## Example

~~~dart
// Create a callback listening to time stamps
final timeController = GgTimeController(onTimeStamp: (timeStamp){
  print('time: ${timeStamp.time.inMilliseconds}')
});

// Listen to state
timeController.state.listen((state){
  print(state);
});

/// Start playing
timeController.play();

/// Wait for five frames
await Future.delayed(GgTimeController.defaultFrameDuration * 5);

/// Pause playing
timeController.play();

/// Jump to 10s
timeController.jumpTo(time: const Duration(seconds: 10));

/// Animate to 20s
timeController.animateTo(time: const Duration(seconds: 10));

// Stop
timeController.stop();
~~~

## Getting started

Look into the example to see how `GgTimeController` works.

## Features and bugs

Please file feature requests and bugs at [GitHub](https://github.com/inlavigo/gg_time_controller).
