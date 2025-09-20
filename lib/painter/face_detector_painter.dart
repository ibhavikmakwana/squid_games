import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'coordinates_translator.dart';

class FaceDetectorPainter extends CustomPainter {
  FaceDetectorPainter(
    this.faces,
    this.imageSize,
    this.rotation,
    this.cameraLensDirection,
    this.eliminatedPlayers,
  );

  final List<Face> faces;
  final Size imageSize;
  final InputImageRotation rotation;
  final CameraLensDirection cameraLensDirection;
  final Map<int, bool> eliminatedPlayers;

  @override
  void paint(Canvas canvas, Size size) {
    // TODO: Step 1a - Draw basic bounding boxes
    // TODO: Step 2a - Update painter for game state (colors and text)
  }

  @override
  bool shouldRepaint(FaceDetectorPainter oldDelegate) {
    // TODO: Step 1a - Basic shouldRepaint
    // TODO: Step 2a - Update shouldRepaint for eliminatedPlayers
    return false;
  }
}