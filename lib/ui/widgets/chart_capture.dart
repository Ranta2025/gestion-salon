import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

/// Captures the widget painted inside a [RepaintBoundary] as PNG bytes.
/// Used to embed live charts into the PDF report.
Future<Uint8List?> captureBoundaryPng(GlobalKey key) async {
  try {
    final context = key.currentContext;
    if (context == null) return null;
    final boundary = context.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 2.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes?.buffer.asUint8List();
  } catch (_) {
    return null;
  }
}
