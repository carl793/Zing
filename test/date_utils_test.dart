import 'package:flutter_test/flutter_test.dart';
import 'package:zing/core/utils/date_utils.dart';
import 'package:zing/core/utils/validators.dart';

void main() {
  group('ZingDateUtils', () {
    test('today() is UTC midnight of the local calendar day', () {
      final now = DateTime.now();
      final today = ZingDateUtils.today();
      expect(today.isUtc, isTrue);
      expect([today.year, today.month, today.day], [now.year, now.month, now.day]);
      expect([today.hour, today.minute, today.second], [0, 0, 0]);
    });

    test('fromStored normalizes an instant to its UTC calendar day', () {
      expect(
        ZingDateUtils.fromStored(DateTime.utc(2026, 9, 16, 23, 59)),
        DateTime.utc(2026, 9, 16),
      );
    });

    test('fromLocal keeps the calendar day that was picked', () {
      expect(
        ZingDateUtils.fromLocal(DateTime(2026, 2, 3, 18, 30)),
        DateTime.utc(2026, 2, 3),
      );
    });

    test('daysInMonth handles leap years', () {
      expect(ZingDateUtils.daysInMonth(2024, 2), 29);
      expect(ZingDateUtils.daysInMonth(2026, 2), 28);
      expect(ZingDateUtils.daysInMonth(2026, 12), 31);
    });

    test('leadingBlanks counts the cells before the 1st (Sunday first)', () {
      // 1 Nov 2026 is a Sunday; 1 Sep 2026 is a Tuesday.
      expect(ZingDateUtils.leadingBlanks(2026, 11), 0);
      expect(ZingDateUtils.leadingBlanks(2026, 9), 2);
    });

    test('labels', () {
      final day = DateTime.utc(2026, 9, 5);
      expect(ZingDateUtils.isoDate(day), '2026-09-05');
      expect(ZingDateUtils.shortLabel(day), 'SEP 05, 2026');
      expect(ZingDateUtils.monthYearLabel(day), 'SEPTEMBER 2026');
    });
  });

  group('Validators', () {
    test('email', () {
      expect(Validators.isValidEmail(' player1@zing.app '), isTrue);
      expect(Validators.isValidEmail('player1@zing'), isFalse);
      expect(Validators.isValidEmail('no at sign.com'), isFalse);
    });

    test('room code accepts six digits, with or without a dash', () {
      expect(Validators.isValidRoomCode('123456'), isTrue);
      expect(Validators.isValidRoomCode('123-456'), isTrue);
      expect(Validators.isValidRoomCode('12345'), isFalse);
      expect(Validators.isValidRoomCode('12a456'), isFalse);
    });
  });
}
