import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error }

class AppLogger {
  static void log(
    String message, {
    String tag = 'App',
    LogLevel level = LogLevel.info,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!kDebugMode && level == LogLevel.debug) return;

    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    final emoji = _getEmoji(level);
    final formattedMessage = '[$timestamp] $emoji [$tag] $message';

    debugPrint(formattedMessage);
    if (error != null) {
      debugPrint('  Error: $error');
    }
    if (stackTrace != null && kDebugMode) {
      debugPrint('  StackTrace: $stackTrace');
    }
  }

  static void info(String message, {String tag = 'Info'}) =>
      log(message, tag: tag, level: LogLevel.info);

  static void debug(String message, {String tag = 'Debug'}) =>
      log(message, tag: tag, level: LogLevel.debug);

  static void warning(String message, {String tag = 'Warning'}) =>
      log(message, tag: tag, level: LogLevel.warning);

  static void error(
    String message, {
    String tag = 'Error',
    Object? error,
    StackTrace? stackTrace,
  }) => log(
    message,
    tag: tag,
    level: LogLevel.error,
    error: error,
    stackTrace: stackTrace,
  );

  static String _getEmoji(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return '🐛';
      case LogLevel.info:
        return 'ℹ️';
      case LogLevel.warning:
        return '⚠️';
      case LogLevel.error:
        return '🚨';
    }
  }
}
