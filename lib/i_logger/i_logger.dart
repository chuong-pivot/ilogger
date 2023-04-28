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

void logPrint(Object? obj) {
  // for PrettyDiaLogger
  if (kDebugMode) {
    print(obj);
  }

  ILogger.appendDebugLogs(obj.toString());
}

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
  String debugSuffix = DateTime.now().millisecondsSinceEpoch.toString();

  Future<void> takeScreenshot() async {
    setIsTakingScrenshot(true);

    await Future.delayed(const Duration(milliseconds: 200));

    iLog.i('Taking screenshot...');

    try {
      final dir = await getApplicationDocumentsDirectory();
      final fileName = 'debug_image_$debugSuffix.png';

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
      debugSuffix = DateTime.now().millisecondsSinceEpoch.toString();
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
      final logFileName = 'debug_log_$debugSuffix.log';

      final savedDirPath = join(dir.path, FolderPaths.debugLog);
      await Directory(savedDirPath).create(recursive: true);

      final filePath = join(dir.path, FolderPaths.debugLog, logFileName);
      await File(filePath).create(recursive: true);
      final logFile = File(filePath);
      await logFile.writeAsString(logData, flush: true);
      iLog.i('Log file path: ${logFile.path}');

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
          '$keyPrefix$debugSuffix',
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

/// For upload file to firestore
// Future<Reference?> uploadFileToServer({
//   required File file,
//   required String path,
// }) async {
//   try {
//     debugLogger.d('Uploading $path');
// 
//     final strgRef = storageRef.child(path);
// 
//     await strgRef.putFile(file);
// 
//     return strgRef;
//   } catch (err) {
//     debugLogger.e(err);
//   }
// 
//   return null;
// }

// String? logFileDownloadURL;
// try {
//   final debugLogsRef = await uploadFileToServer(
//     file: logFile,
//     path: 'debug_logs/$logFileName',
//   );

//   if (debugLogsRef == null) {
//     debugLogger.d("Can't upload file to server.");
//   }

//   await debugLogsRef?.putFile(logFile);

//   logFileDownloadURL = await debugLogsRef?.getDownloadURL();
// } catch (err) {
//   debugLogger.e(err);
// }

// debugLogger.d('Log file download URL: $logFileDownloadURL');

// String? screenshotDownloadUrl;

// if (state.imagePath.isNotEmpty) {
//   final fileName =
//       'travelo_debug_screenshot_${DateTime.now().toIso8601String()}.png';

//   final screenshotFile = File(state.imagePath);

//   debugLogger.d('Upload image file name: $fileName');

//   final debugScreenshotRef = await uploadFileToServer(
//     file: screenshotFile,
//     path: 'debug_screenshots/$fileName',
//   );

//   try {
//     await debugScreenshotRef?.putFile(screenshotFile);
//   } catch (err) {
//     debugLogger.d(err);
//   }

//   screenshotDownloadUrl = await debugScreenshotRef?.getDownloadURL();

//   debugLogger.d('Screenshot download URL:  $screenshotDownloadUrl');
// }

/// For upload to slack channel
// await SlackNotifier('T4P5H32FR/B04AX1VU8Q3/1X9rKYxilhahfEIP4F4H08Ua')
//     .send(
//   '''New debug log received: ${DateTime.now().toString()} 
// \nDevice: ${androidInfo.brand} ${androidInfo.model} 
// \nDownload URL: $logFileDownloadURL
// \nScreenshot URL: $screenshotDownloadUrl''',
//   channel: 'aspr_travelo_stg_debug_log',
//   iconEmoji: ':smirk_cat:',
// );