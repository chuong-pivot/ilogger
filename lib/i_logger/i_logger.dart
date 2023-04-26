import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:native_screenshot/native_screenshot.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../enviroment_variables.dart';
import '../folders_path.dart';
import 'state/i_logger_result.dart';
import 'state/state.dart';

part 'i_logger.g.dart';

final iLog = ILogger.log;
Future<void> Function(ILoggerResult result)? iLoggerHandlingData;

@Riverpod(keepAlive: true)
class ILogger extends _$ILogger {
  @override
  DebugLoggerState build() {
    return DebugLoggerState();
  }

  static void logPrint(Object? obj) {
    // for PrettyDiaLogger
    if (kDebugMode) {
      print(obj);
    }

    ILogger.appendDebugLogs(obj.toString());
  }

  static void appendDebugLogs(String logs) {
    logData += '$logs\n';
  }

  static const isDebugLoggerEnabled = EnviromentVariables.debugLoggerEnabled;

  static String logData = '';

  static final log = Logger(
    printer: PrettyPrinter(
      lineLength: 80,
      colors: false,
    ),
    filter: CustomLogFilter(),
    output: CustomLogOutput(),
  );

  void toogleCollapse(bool isCollapse) {
    state = state.copyWith(
      isButtonCollapsed: isCollapse,
    );
  }

  Future<void> takeScreenshot() async {
    setIsTakingScrenshot(true);

    await Future.delayed(const Duration(milliseconds: 200));

    iLog.i('Taking screenshot...');

    try {
      final dir = await getApplicationDocumentsDirectory();
      const fileName = 'debug_screenshot.png';
      final savedPath = join(dir.path, FolderPaths.images, fileName);

      await File(savedPath).create(recursive: true);

      final screenshotFilePath =
          await NativeScreenshot.takeScreenshot(saveScreenshotPath: savedPath);

      iLog.i('Screenshot file path = $screenshotFilePath');

      if (screenshotFilePath == null) {
        iLog.e('Take screenshot error');
        return;
      }

      setImagePath(screenshotFilePath);
    } catch (err) {
      iLog.e('Take screenshot error: $err');
    }

    Future.delayed(const Duration(milliseconds: 200), () {
      setIsTakingScrenshot(false);
    });
  }

  Future<void> handleDebugData() async {
    if (state.isHandlingData || state.isTakingScreenshot) {
      return;
    }

    if (state.imagePath == null) {
      await takeScreenshot();
    }

    setIsHandling(true);

    try {
      iLog.i('Adding device info...');
      final deviceInfo = await DeviceInfoPlugin().deviceInfo;
      logData = 'Device Info:\n$deviceInfo\n\n$logData';

      iLog.i('Write log to file...');
      final directory = await getApplicationDocumentsDirectory();
      final logFileName =
          'travelo_debug_log_${DateTime.now().toIso8601String()}.log';
      final filePath = join(directory.path, FolderPaths.debugLog, logFileName);

      await File(filePath).create(recursive: true);
      final logFile = File(filePath);

      await compute(
        (message) async => await logFile.writeAsString(message, flush: true),
        logData,
      );
      iLog.i('Log file path = ${logFile.path}');

      iLog.i('Start hanlding data...');
      await iLoggerHandlingData?.call(ILoggerResult(
        debugLogFilePath: logFile.path,
        imageFilePath: state.imagePath,
      ));
      iLog.i('Done hanlding data!');
    } catch (err) {
      iLog.e(err);
    } finally {
      setIsHandling(false);
    }
  }

  void setIsHandling(bool isHandling) {
    state = state.copyWith(
      isHandlingData: isHandling,
    );
  }

  void setIsTakingScrenshot(bool isTakingScreenshot) {
    state = state.copyWith(
      isTakingScreenshot: isTakingScreenshot,
    );
  }

  void setIsEditingImage(bool isEditing) {
    state = state.copyWith(
      isEditingImage: isEditing,
    );
  }

  void setImagePath(String? path) {
    state = state.copyWith(
      imagePath: path,
    );
  }
}

class CustomLogFilter extends LogFilter {
  /* to enable outputting debug log in release build
   (when testHelperEnabled=true only) */
  @override
  bool shouldLog(LogEvent event) {
    return kDebugMode || EnviromentVariables.debugLoggerEnabled;
  }
}

class CustomLogOutput extends LogOutput {
  static final consoleOutput = ConsoleOutput();

  @override
  void output(OutputEvent event) {
    consoleOutput.output(event); // output to terminal

    // save logs for sending later
    event.lines.forEach(ILogger.appendDebugLogs);
  }
}
