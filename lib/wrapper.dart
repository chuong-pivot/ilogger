import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_painter/image_painter.dart';

import 'draggable_atom.dart';
import 'i_logger/i_logger.dart';

/// A wrapper widget that create an overlay over your app
/// to display utilities buttons.
/// Checkout example/main.dart on how to implement [ILoggerWrapper]
class ILoggerWrapper extends StatelessWidget {
  const ILoggerWrapper({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (kReleaseMode || !ILogger.isDebugLoggerEnabled) {
      return child;
    }

    final container = ProviderContainer();

    container.read(iLoggerProvider);

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          child,
          Positioned.fill(
            child: ProviderScope(
              key: GlobalKey(),
              parent: container,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Overlay(
                      initialEntries: [
                        OverlayEntry(
                          maintainState: true,
                          builder: (context) {
                            return const ButtonArea();
                          },
                        )
                      ],
                    ),
                  ),
                  Consumer(
                    builder: (context, ref, child) {
                      final isHandling = ref.watch(iLoggerProvider
                          .select((value) => value.isHandlingData));

                      return isHandling
                          ? Positioned.fill(
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  const CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                  Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      color: const Color.fromRGBO(0, 0, 0, 1)
                                          .withOpacity(.5),
                                    ),
                                    alignment: Alignment.topCenter,
                                    child: const Text(
                                      'Sending log...',
                                      style: TextStyle(height: 1.5),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox();
                    },
                  ),
                  Consumer(
                    builder: (context, ref, child) {
                      final isEditing = ref.watch(iLoggerProvider
                          .select((value) => value.isEditingImage));

                      return isEditing
                          ? const Positioned.fill(child: EditDebugScreenshot())
                          : const SizedBox();
                    },
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}

class ButtonArea extends StatelessWidget {
  const ButtonArea({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableAtom(
      top: 50,
      left: 100,
      child: Opacity(
        opacity: .5,
        child: OrientationBuilder(
          builder: (context, orientation) {
            return Consumer(
              builder: (context, ref, child) {
                final debugLogger = ref.watch(iLoggerProvider);
                final debugLoggerProv = ref.read(iLoggerProvider.notifier);

                return !debugLogger.isTakingScreenshot
                    ? Flex(
                        direction: orientation == Orientation.portrait
                            ? Axis.vertical
                            : Axis.horizontal,
                        children: [
                          GestureDetector(
                            onTap: () => debugLoggerProv
                                .toogleCollapse(!debugLogger.isButtonCollapsed),
                            child: Container(
                              height: 40,
                              width: 40,
                              clipBehavior: Clip.antiAlias,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.orange,
                              ),
                              child: Icon(
                                debugLogger.isButtonCollapsed
                                    ? Icons.menu
                                    : Icons.close,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          if (!debugLogger.isButtonCollapsed) ...[
                            const SizedBox(
                              width: 10,
                              height: 10,
                            ),
                            GestureDetector(
                              onTap: debugLoggerProv.handleDebugData,
                              child: Container(
                                height: 40,
                                width: 40,
                                clipBehavior: Clip.antiAlias,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.orange,
                                ),
                                child: const Icon(
                                  Icons.outgoing_mail,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(
                              width: 10,
                              height: 10,
                            ),
                            GestureDetector(
                              onTap: debugLoggerProv.takeScreenshot,
                              child: Container(
                                height: 40,
                                width: 40,
                                clipBehavior: Clip.antiAlias,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.orange,
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            if (debugLogger.imagePath != null) ...[
                              const SizedBox(
                                width: 10,
                                height: 10,
                              ),
                              GestureDetector(
                                onTap: () =>
                                    debugLoggerProv.setIsEditingImage(true),
                                child: Container(
                                  height: 40,
                                  width: 40,
                                  clipBehavior: Clip.antiAlias,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.orange,
                                  ),
                                  child: const Icon(
                                    Icons.edit,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ]
                          ],
                        ],
                      )
                    : const SizedBox();
              },
            );
          },
        ),
      ),
    );
  }
}

class EditDebugScreenshot extends StatefulWidget {
  const EditDebugScreenshot({super.key});

  @override
  State<EditDebugScreenshot> createState() => _EditDebugScreenshotState();
}

class _EditDebugScreenshotState extends State<EditDebugScreenshot> {
  final _imageKey = GlobalKey<ImagePainterState>();
  bool isSaving = false;

  Future<void> saveImage(WidgetRef ref) async {
    final debugLoggerState = ref.read(iLoggerProvider);

    if (isSaving || debugLoggerState.imagePath == null) {
      return;
    }

    iLog.i('Saving edited image...');

    setState(() => isSaving = true);

    try {
      final newImageBytes = await _imageKey.currentState?.exportImage();

      if (newImageBytes != null) {
        final file = File(debugLoggerState.imagePath!);
        await file.writeAsBytes(newImageBytes);

        iLog.i('Save success');
      } else {
        iLog.e('Save failed');
      }
    } catch (err) {
      iLog.e(err);
    }

    setState(() => isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    try {
      return MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            leading: Consumer(
              builder: (context, ref, child) {
                final debugLoggerProv = ref.read(iLoggerProvider.notifier);

                return IconButton(
                  onPressed: () async {
                    debugLoggerProv.setIsEditingImage(false);
                  },
                  icon: child!,
                );
              },
              child: const Icon(Icons.arrow_back),
            ),
            actions: [
              Consumer(
                builder: (context, ref, child) {
                  return IconButton(
                    onPressed: () => saveImage(ref),
                    icon: child!,
                  );
                },
                child: const Icon(Icons.save),
              ),
            ],
          ),
          body: Stack(
            alignment: Alignment.center,
            children: [
              Consumer(
                builder: (context, ref, child) {
                  final debugLogger = ref.watch(iLoggerProvider);

                  return debugLogger.imagePath != null
                      ? Positioned.fill(
                          child: ImagePainter.memory(
                            File(debugLogger.imagePath!).readAsBytesSync(),
                            key: _imageKey,
                          ),
                        )
                      : const SizedBox();
                },
              ),
              if (isSaving) ...[
                Positioned.fill(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color:
                              const Color.fromRGBO(0, 0, 0, 1).withOpacity(.5),
                        ),
                      ),
                      const CircularProgressIndicator(
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    } catch (err) {
      iLog.e(err);
    }

    return Container();
  }
}
