import 'package:flutter_test/flutter_test.dart';
import 'package:therapy_pal/core/format.dart';

void main() {
  group('fmtTime', () {
    test('converts 24h to 12h', () {
      expect(fmtTime('13:00'), '1:00 PM');
      expect(fmtTime('08:05'), '8:05 AM');
      expect(fmtTime('00:30'), '12:30 AM');
      expect(fmtTime('12:00'), '12:00 PM');
    });
    test('pads when asked', () => expect(fmtTime('08:05', pad: true), '08:05 AM'));
    test('handles missing values', () => expect(fmtTime(null), ''));
  });

  group('names and counts', () {
    test('firstName drops the Dr. prefix', () {
      expect(firstName('Dr. Sarah Carter'), 'Sarah');
      expect(firstName('Alex Rivera'), 'Alex');
    });
    test('plural', () {
      expect(plural(1, 'record'), '1 record');
      expect(plural(3, 'record'), '3 records');
    });
  });

  test('nowQuery uses the device clock format the API expects', () {
    final q = nowQuery();
    expect(RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(q['day']!), isTrue);
    expect(RegExp(r'^\d{2}:\d{2}$').hasMatch(q['time']!), isTrue);
  });
}
