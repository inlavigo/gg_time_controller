import 'package:fake_async/fake_async.dart';
import 'package:gg_time_controller/src/gg_time_stamp.dart';
import 'package:test/test.dart';

void main() {
  late GgTimeStamp timeStamp;

  void init(FakeAsync fake) {
    timeStamp = const GgTimeStamp(time: Duration(microseconds: 123));
    fake.flushMicrotasks();
  }

  void dispose(FakeAsync fake) {
    fake.flushMicrotasks();
  }

  group('TimeStamp', () {
    // #########################################################################
    group('initialization', () {
      test('should work fine', () {
        fakeAsync((fake) {
          init(fake);
          expect(timeStamp, isNotNull);
          dispose(fake);
        });
      });
    });

    // #########################################################################
    group('operator==', () {
      test('should return true if timestamps are equal', () {
        expect(timeStamp == GgTimeStamp(time: timeStamp.time), true);
        expect(timeStamp == const GgTimeStamp(time: Duration(days: 5)), false);
      });
    });

    // #########################################################################
    group('toString()', () {
      test('should return a string representation of the time stamp', () {
        expect(timeStamp.toString(), '${timeStamp.time.inMicroseconds}');
      });
    });

    // #########################################################################
    group('hashCode', () {
      test('should return the hashcode of the time stamp', () {
        expect(timeStamp.hashCode, timeStamp.time.hashCode);
      });
    });
  });
}
