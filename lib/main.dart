import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:squid_games/detector_view.dart';
import 'package:squid_games/painter/face_detector_painter.dart';
import 'package:squid_games/splash_screen.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:camera/camera.dart';

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/game': (context) => const FaceDetectorView(),
      },
    );
  }
}

class FaceDetectorView extends StatefulWidget {
  const FaceDetectorView({super.key});

  @override
  State<FaceDetectorView> createState() => _FaceDetectorViewState();
}

class _FaceDetectorViewState extends State<FaceDetectorView> with SingleTickerProviderStateMixin {
  // TODO: Step 1 - Add FaceDetector variables

  // TODO: Step 2 - Add Squid Game state variables

  // TODO: Step 3 - Add Audio and Timer variables

  @override
  void initState() {
    super.initState();
    // TODO: Step 3 - Initialize audio and ticker in initState
  }

  // TODO: Step 3 - Add _onTick and _playAudioLoop methods

  @override
  void dispose() {
    // TODO: Step 3 - Dispose audio and ticker resources
    super.dispose();
  }

  // TODO: Step 4 - Add _refreshGame method

  @override
  Widget build(BuildContext context) {
    // TODO: Step 4 - Replace build method with final UI
    // TODO: Step 1 - Update DetectorView parameters
    return DetectorView(
      title: 'Face Detector',
      onImage: (inputImage) {
        // TODO: Step 1 - Add _processImage method call
      },
    );
  }

  // TODO: Step 2 - Add _switchLightIfNeeded method

  // TODO: Step 1 - Add _processImage method
  // TODO: Step 2 - Update _processImage with game logic
}
