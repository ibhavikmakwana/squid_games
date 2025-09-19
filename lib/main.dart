import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:squid_games/camera_view.dart';
import 'package:squid_games/detector_view.dart';
import 'package:squid_games/painter/face_detector_painter.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'dart:math';
import 'package:squid_games/splash_screen.dart';
import 'package:audioplayers/audioplayers.dart';

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

class _FaceDetectorViewState extends State<FaceDetectorView> {
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(enableContours: true, enableLandmarks: true),
  );
  bool _canProcess = true;
  bool _isBusy = false;
  CustomPaint? _customPaint;
  String? _text;
  var _cameraLensDirection = CameraLensDirection.front;

  // Squid Game variables
  bool _isRedLight = false;
  DateTime _lastLightSwitch = DateTime.now();
  final Duration _lightSwitchInterval = Duration(seconds: 3);
  Map<int, Rect> _previousFaceRects = {};
  Set<int> _eliminatedPlayers = {};
  int _playerCounter = 0;

  // Audio player for looping game music
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _playAudioLoop();
  }

  void _playAudioLoop() async {
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    await _audioPlayer.play(AssetSource('audio/red_light_green_light.mp3'));
  }

  @override
  void dispose() {
    _canProcess = false;
    _faceDetector.close();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        DetectorView(
          title: 'Squid Game - Red Light Green Light',
          customPaint: _customPaint,
          text: _text,
          onImage: _processImage,
          initialCameraLensDirection: _cameraLensDirection,
          onCameraLensDirectionChanged: (value) => _cameraLensDirection = value,
        ),
        Positioned(
          top: 40,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isRedLight
                    ? [Colors.red.shade900, Colors.pinkAccent]
                    : [Colors.green.shade900, Colors.greenAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _isRedLight ? Colors.redAccent.withOpacity(0.6) : Colors.greenAccent.withOpacity(0.6),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isRedLight ? Colors.pinkAccent : Colors.greenAccent,
                  width: 4,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isRedLight ? Icons.close : Icons.check_circle,
                    color: Colors.white,
                    size: 32,
                  ),
                  SizedBox(width: 16),
                  ShaderMask(
                    shaderCallback: (Rect bounds) {
                      return LinearGradient(
                        colors: _isRedLight
                          ? [Colors.redAccent, Colors.pinkAccent]
                          : [Colors.greenAccent, Colors.white],
                        tileMode: TileMode.mirror,
                      ).createShader(bounds);
                    },
                    child: Text(
                      _isRedLight ? "RED LIGHT" : "GREEN LIGHT",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3,
                        shadows: [
                          Shadow(
                            blurRadius: 12,
                            color: _isRedLight ? Colors.redAccent : Colors.greenAccent,
                            offset: Offset(0, 0),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _switchLightIfNeeded() {
    if (DateTime.now().difference(_lastLightSwitch) > _lightSwitchInterval) {
      setState(() {
        _isRedLight = !_isRedLight;
        _lastLightSwitch = DateTime.now();
      });
    }
  }

  Future<void> _processImage(InputImage inputImage) async {
    _switchLightIfNeeded();
    if (!_canProcess) return;
    if (_isBusy) return;
    _isBusy = true;
    setState(() {
      _text = '';
    });
    final faces = await _faceDetector.processImage(inputImage);

    // Assign player numbers and track movement
    Map<int, Rect> currentRects = {};
    Map<int, bool> eliminated = {};
    int faceIdx = 0;
    for (final face in faces) {
      // Assign player number based on order (simple for demo)
      int playerNum = faceIdx;
      currentRects[playerNum] = face.boundingBox;

      // Check movement if red light
      bool isEliminated = false;
      if (_isRedLight && !_eliminatedPlayers.contains(playerNum)) {
        final prevRect = _previousFaceRects[playerNum];
        if (prevRect != null) {
          double movement = (face.boundingBox.center - prevRect.center).distance;
          if (movement > 10) { // threshold for movement
            _eliminatedPlayers.add(playerNum);
            isEliminated = true;
          }
        }
      }
      eliminated[playerNum] = _eliminatedPlayers.contains(playerNum);
      faceIdx++;
    }
    _previousFaceRects = currentRects;

    if (inputImage.metadata?.size != null && inputImage.metadata?.rotation != null) {
      final painter = FaceDetectorPainter(
        faces,
        inputImage.metadata!.size,
        inputImage.metadata!.rotation,
        _cameraLensDirection,
        eliminated,
      );
      _customPaint = CustomPaint(painter: painter);
    } else {
      String text = 'Faces found: ${faces.length}\n\n';
      for (final face in faces) {
        text += 'face: ${face.boundingBox}\n\n';
      }
      _text = text;
      _customPaint = null;
    }
    _isBusy = false;
    if (mounted) {
      setState(() {});
    }
  }
}
