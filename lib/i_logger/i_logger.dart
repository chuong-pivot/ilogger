import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:iscreenshot/iscreenshot.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'enviroment_variables.dart';
import 'folders_path.dart';
import 'state/i_logger_result.dart';
import 'state/state.dart';

part 'i_logger.g.dart';

final iLog = ILogger.log;
Future<void> Function(List<ILoggerResult> result, bool isOffline)?
    iLoggerHandlingData;

@Riverpod(keepAlive: true)
class ILogger extends _$ILogger {
  @override
  DebugLoggerState build() {
    return DebugLoggerState();
  }

  static const isDebugLoggerEnabled = EnviromentVariables.debugLoggerEnabled;
  static String logData = '';

  final prefs = Completer<SharedPreferences>();
  final keyPrefix = 'ilogger_debug_';
  String current_debug_suffix =
      DateTime.now().millisecondsSinceEpoch.toString();

  Future<void> takeScreenshot() async {
    setIsTakingScrenshot(true);

    await Future.delayed(const Duration(milliseconds: 200));

    iLog.i('Taking screenshot...');

    try {
      final dir = await getApplicationDocumentsDirectory();
      final fileName = 'debug_image_$current_debug_suffix.png';

      final savedDirPath = join(dir.path, FolderPaths.images);
      await Directory(savedDirPath).create(recursive: true);

      var savedPath = join(FolderPaths.images, fileName);

      if (Platform.isAndroid) {
        savedPath = join(dir.path, savedPath);
        await File(savedPath).create(recursive: true);
      }

      final screenshotFilePath = await IScreenshot.takeScreenshot(
        saveScreenshotPath: savedPath,
      );

      iLog.i('Screenshot file path = $screenshotFilePath');

      if (screenshotFilePath == null) {
        throw Error();
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

    if (!prefs.isCompleted) {
      prefs.complete(await SharedPreferences.getInstance());
    }

    if (state.imagePath == null) {
      current_debug_suffix = DateTime.now().millisecondsSinceEpoch.toString();
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
      final dir = await getApplicationDocumentsDirectory();
      final logFileName = 'debug_log_$current_debug_suffix.log';

      final savedDirPath = join(dir.path, FolderPaths.debugLog);
      await Directory(savedDirPath).create(recursive: true);

      final filePath = join(dir.path, FolderPaths.debugLog, logFileName);

      await File(filePath).create(recursive: true);
      final logFile = File(filePath);
      await logFile.writeAsString(logData, flush: true);

      iLog.i('Check network connection...');
      bool isOnline = false;

      final connectStatus = await Connectivity().checkConnectivity();
      if (connectStatus != ConnectivityResult.none &&
          await InternetConnectionChecker().hasConnection) {
        isOnline = true;
      }

      iLog.i('Connection status: $connectStatus\nIs online: $isOnline');

      final logResult = ILoggerResult(
        debugLogFilePath: logFile.path,
        imageFilePath: state.imagePath,
      );

      if (isOnline) {
        iLog.i('Start hanlding data...');

        final logs = await loadLogs();
        await clearLogs();

        logs.add(logResult);

        await iLoggerHandlingData?.call(
          logs,
          !isOnline,
        );
        iLog.i('Done hanlding data!');
      } else {
        iLog.i('Saving log...');
        saveLog(
          '$keyPrefix$current_debug_suffix',
          logResult,
        );
        iLog.i('Done saving log!');
      }

      setImagePath(null);
    } catch (err) {
      iLog.e(err);
    }

    setIsHandling(false);
  }

  Future<void> saveLog(String key, ILoggerResult log) async {
    final pref = await prefs.future;

    await pref.setStringList(key, [
      log.debugLogFilePath ?? '',
      log.imageFilePath ?? '',
    ]);
  }

  Future<List<ILoggerResult>> loadLogs() async {
    final pref = await prefs.future;

    final list = pref.getKeys().where((e) => e.startsWith(keyPrefix)).map((e) {
      final logs = pref.getStringList(e);

      return ILoggerResult(
        debugLogFilePath: logs?[0],
        imageFilePath: logs?[1],
      );
    }).toList();

    return list;
  }

  Future<void> clearLogs() async {
    final pref = await prefs.future;

    final keys =
        pref.getKeys().where((element) => element.startsWith(keyPrefix));

    for (var key in keys) {
      await pref.remove(key);
    }
  }

  void toogleCollapse(bool isCollapse) {
    state = state.copyWith(
      isButtonCollapsed: isCollapse,
    );
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

  static final log = Logger(
    printer: PrettyPrinter(
      lineLength: 80,
      colors: false,
    ),
    filter: CustomLogFilter(),
    output: CustomLogOutput(),
  );
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
