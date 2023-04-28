import 'dart:io';

import 'package:flutter/material.dart';
import 'package:ilogger/i_logger.dart';
import 'package:path/path.dart';

import 'package:path_provider/path_provider.dart';

// flutter run --dart-define I_LOGGER_ENABLED=true
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  iLoggerHandlingData = (result, isOffline) async {};

  /// Please note that since [ILoggerWrapper] using riverpod to manage
  /// state, so if your app using riverpod too then you should use
  /// [ILoggerWrapper] like this:
  /// ```dart
  /// runApp(
  ///   const ILoggerWrapper(
  ///     child: ProviderScope(
  ///       child: MyApp(),
  ///     ),
  ///   ),
  /// );
  /// ```
  runApp(
    const ILoggerWrapper(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        backgroundColor: Colors.white,
        body: const Center(
          child: Text('Running on: \n'),
        ),
      ),
    );
  }
}
