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
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableLandmarks: true,
      enableTracking: true,
      performanceMode: FaceDetectorMode.fast,
    ),
  );
  bool _canProcess = true;
  bool _isBusy = false;
  CustomPaint? _customPaint;
  String? _text;
  var _cameraLensDirection = CameraLensDirection.front;

  // Squid Game variables
  bool _isRedLight = false;
  DateTime _lastLightSwitch = DateTime.now();
  final Duration _lightSwitchInterval = Duration(seconds: 5);
  Map<int, Rect> _previousFaceRects = {};
  Set<int> _eliminatedPlayers = {};
  int _totalPlayers = 0;

  // Audio player for looping game music
  final AudioPlayer _audioPlayer = AudioPlayer();
  int _secondsToNextSwitch = 5;
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _playAudioLoop();
    _ticker = Ticker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final secondsSinceSwitch = DateTime.now().difference(_lastLightSwitch).inSeconds;
    setState(() {
      _secondsToNextSwitch = (_lightSwitchInterval.inSeconds - secondsSinceSwitch).clamp(
        0,
        _lightSwitchInterval.inSeconds,
      );
    });
  }

  void _playAudioLoop() async {
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    await _audioPlayer.play(AssetSource('audio/red_light_green_light.mp3'));
  }

  @override
  void dispose() {
    _ticker.dispose();
    _canProcess = false;
    _faceDetector.close();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _refreshGame() {
    setState(() {
      _previousFaceRects.clear();
      _eliminatedPlayers.clear();
      _totalPlayers = 0;
      _customPaint = null;
      _text = null;
      _lastLightSwitch = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    int activePlayers = _totalPlayers - _eliminatedPlayers.length;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 8,
        title: Row(
          children: [
            Icon(Icons.people, color: Colors.white, size: 22),
            SizedBox(width: 4),
            Text(
              'Total: $_totalPlayers',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            SizedBox(width: 12),
            Icon(Icons.person_outline, color: Colors.greenAccent, size: 22),
            SizedBox(width: 4),
            Text(
              'Active: ${activePlayers >= 0 ? activePlayers : 0}',
              style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
            ),
            SizedBox(width: 12),
            Icon(Icons.person_off, color: Colors.redAccent, size: 22),
            SizedBox(width: 4),
            Text(
              'Elim: ${_eliminatedPlayers.length}',
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Restart Game',
            onPressed: _refreshGame,
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black,
                            Colors.pink.shade900.withAlpha((255 * 0.2).toInt()),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.pinkAccent.withAlpha((255 * 0.2).toInt()),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: DetectorView(
                        title: 'Squid Game - Red Light Green Light',
                        customPaint: _customPaint,
                        text: _text,
                        onImage: _processImage,
                        initialCameraLensDirection: _cameraLensDirection,
                        onCameraLensDirectionChanged: (value) => _cameraLensDirection = value,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 60), // Space for bottom bar
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 16, horizontal: 32),
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
                    color: _isRedLight
                        ? Colors.redAccent.withAlpha((255 * 0.5).toInt())
                        : Colors.greenAccent.withAlpha((255 * 0.5).toInt()),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(
                  color: _isRedLight ? Colors.pinkAccent : Colors.greenAccent,
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isRedLight ? Icons.close : Icons.check_circle,
                    color: Colors.white,
                    size: 28,
                  ),
                  SizedBox(width: 16),
                  Text(
                    _isRedLight ? "RED LIGHT" : "GREEN LIGHT",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  SizedBox(width: 32),
                  Icon(Icons.timer, color: Colors.white, size: 28),
                  SizedBox(width: 8),
                  Text(
                    '$_secondsToNextSwitch s',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
    _totalPlayers = faces.length;

    // Use a temporary map for the current frame's face data
    Map<int, Rect> currentFaceRects = {};
    Map<int, bool> eliminatedStatus = {};

    for (final face in faces) {
      final trackingId = face.trackingId;
      if (trackingId != null) {
        currentFaceRects[trackingId] = face.boundingBox;

        // Check for movement during a red light
        if (_isRedLight && !_eliminatedPlayers.contains(trackingId)) {
          final prevRect = _previousFaceRects[trackingId];
          if (prevRect != null) {
            final movement = (face.boundingBox.center - prevRect.center).distance;
            if (movement > 15) {
              // Movement threshold
              _eliminatedPlayers.add(trackingId);
            }
          }
        }
        eliminatedStatus[trackingId] = _eliminatedPlayers.contains(trackingId);
      }
    }

    // Update the previous face rects for the next frame
    _previousFaceRects = currentFaceRects;

    if (inputImage.metadata?.size != null && inputImage.metadata?.rotation != null) {
      final painter = FaceDetectorPainter(
        faces,
        inputImage.metadata!.size,
        inputImage.metadata!.rotation,
        _cameraLensDirection,
        eliminatedStatus,
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
