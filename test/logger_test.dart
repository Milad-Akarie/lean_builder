import 'dart:async';

import 'package:lean_builder/src/logger.dart';
import 'package:test/test.dart';

void main() {
  group('Logger', () {
    late List<String> printedMessages;

    void logCapturer(String message) {
      printedMessages.add(message);
    }

    setUp(() {
      printedMessages = [];
      Logger.level = LogLevel.info; // Reset level for each test
    });

    test('Logger singleton', () {
      expect(Logger(), same(Logger()));
    });

    test('log level filtering - info level hides fine/debug', () {
      runZoned(
        () {
          Logger.fine('fine');
          Logger.debug('debug');
          Logger.info('info');
        },
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, message) {
            logCapturer(message);
          },
        ),
      );

      expect(printedMessages, hasLength(1));
      expect(printedMessages.first, contains('[INFO]'));
      expect(printedMessages.first, contains('info'));
    });

    test('log level filtering - fine level shows everything', () {
      Logger.level = LogLevel.fine;
      runZoned(
        () {
          Logger.fine('fine message');
          Logger.debug('debug message');
          Logger.info('info message');
        },
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, message) {
            logCapturer(message);
          },
        ),
      );

      expect(printedMessages, hasLength(3));
      expect(printedMessages[0], contains('[FINE]'));
      expect(printedMessages[0], contains('fine message'));
      expect(printedMessages[1], contains('[DEBUG]'));
      expect(printedMessages[2], contains('[INFO]'));
    });

    test('success method', () {
      runZoned(
        () {
          Logger.success('success message');
        },
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, message) {
            logCapturer(message);
          },
        ),
      );

      expect(printedMessages.first, contains('[SUCCESS]'));
      expect(printedMessages.first, contains('success message'));
    });

    test('warning method', () {
      runZoned(
        () {
          Logger.warning('warning message');
        },
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, message) {
            logCapturer(message);
          },
        ),
      );

      expect(printedMessages.first, contains('[WARNING]'));
      expect(printedMessages.first, contains('warning message'));
    });

    test('error method without stacktrace', () {
      runZoned(
        () {
          Logger.error('error message');
        },
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, message) {
            logCapturer(message);
          },
        ),
      );

      expect(printedMessages.first, contains('[ERROR]'));
      expect(printedMessages.first, contains('error message'));
    });

    test('error method with stacktrace', () {
      final st = StackTrace.current;
      runZoned(
        () {
          Logger.error('error with trace', stackTrace: st);
        },
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, message) {
            logCapturer(message);
          },
        ),
      );

      expect(printedMessages.first, contains('[ERROR]'));
      expect(printedMessages.first, contains('error with trace'));
      // Check that it contains some stack frames
      expect(printedMessages.first, contains('.dart'));
    });

    test('error method with stacktrace and fine level shows more frames', () {
      Logger.level = LogLevel.fine;
      final st = StackTrace.current;

      runZoned(
        () {
          Logger.error('detailed error', stackTrace: st);
        },
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, message) {
            logCapturer(message);
          },
        ),
      );

      expect(printedMessages.first, contains('[ERROR]'));
      expect(printedMessages.first, contains('detailed error'));
      // In fine level, it should show more frames.
      // The implementation uses trace.frames for fine, and trace.frames.take(4) otherwise.
      // We can count newlines or just ensure it contains frames.
      final lines = printedMessages.first.split('\n');
      expect(lines.length, greaterThan(4));
    });
  });
}
