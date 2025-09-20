# Squid Game - Live Coding Steps

This file contains the code snippets to be added incrementally during the live coding session.

> **Note for the Presenter:** The explanations below are written to be easily understood by first
> and second-year students. Feel free to use them directly or adapt them to your presentation style.
> The goal is to explain the *why* behind the code, not just the *what*.

## Step 0: Project Setup & Dependencies

> **Explanation:** Every Flutter project has a "shopping list" file called `pubspec.yaml`. We need
> to tell it which external tools, or "packages," our app needs to work.
> - `google_mlkit_face_detection`: This is the "brain" of our app. It's a powerful, pre-trained
    machine learning model from Google that can find faces in an image.
> - `camera`: This package is the "eyes" of our app. It lets us access the phone's camera feed.
> - `audioplayers`: This gives our app a "voice," allowing us to play the background music and sound
    effects.
> - `google_mlkit_commons` & `path_provider`: These are helper packages that the other ones need to
    function correctly.

First, ensure you have a new Flutter project. Then, add the required dependencies by running these
commands in your terminal:

```bash
flutter pub add google_mlkit_face_detection
flutter pub add camera
flutter pub add audioplayers
flutter pub add path_provider
flutter pub add google_mlkit_commons
```

Also, make sure you have the audio file at `assets/audio/red_light_green_light.mp3` and
your `pubspec.yaml` is configured to include it in the assets.

## Step 1: Basic Face Detection & Drawing

> **Goal:** Let's get the basics working. We want to see the camera feed and draw a simple box
> around any face the app detects.

### 1a. Create the Face Painter

> **Explanation:** In Flutter, a `CustomPainter` is like a digital artist. It gives you a blank
> canvas and tools to draw whatever you want—shapes, lines, text, etc. We're creating one to draw
> the
> boxes around the faces.
> - The `paint` method is where all the drawing happens. It loops through each `Face` object given
    to it.
> - For each face, it gets the coordinates of the bounding box.
> - `translateX` and `translateY` are helper functions (already provided
    in `coordinates_translator.dart`) that convert the coordinates from the camera's image size to
    the phone's screen size.
> - `canvas.drawRect` is the command that actually draws the green rectangle on the screen.
> - `shouldRepaint` is an optimization. It tells Flutter to redraw only if the list of faces or the
    image size has changed.

In `lib/painter/face_detector_painter.dart`, add the basic painter class:

```dart
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'coordinates_translator.dart';

class FaceDetectorPainter extends CustomPainter {
  FaceDetectorPainter(this.faces,
      this.imageSize,
      this.rotation,
      this.cameraLensDirection,
      this.eliminatedPlayers,);

  final List<Face> faces;
  final Size imageSize;
  final InputImageRotation rotation;
  final CameraLensDirection cameraLensDirection;
  final Map<int, bool> eliminatedPlayers;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paintGreen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.green;

    for (final Face face in faces) {
      final left = translateX(
          face.boundingBox.left, size, imageSize, rotation, cameraLensDirection);
      final top = translateY(face.boundingBox.top, size, imageSize, rotation, cameraLensDirection);
      final right = translateX(
          face.boundingBox.right, size, imageSize, rotation, cameraLensDirection);
      final bottom = translateY(
          face.boundingBox.bottom, size, imageSize, rotation, cameraLensDirection);

      // Draw bounding box
      canvas.drawRect(
        Rect.fromLTRB(left, top, right, bottom),
        paintGreen,
      );
    }
  }

  @override
  bool shouldRepaint(FaceDetectorPainter oldDelegate) {
    return oldDelegate.imageSize != imageSize || oldDelegate.faces != faces;
  }
}
```

### 1b. Initialize the Face Detector in `main.dart`

> **Explanation:** Now let's use the ML Kit "brain" in our main screen.
> - `_faceDetector`: This is the actual face detection object. We're enabling `tracking` so that it
    can assign a unique ID to each face it sees, which is crucial for our game later.
> - `_canProcess` & `_isBusy`: These are like traffic lights. The camera sends images very fast.
    These booleans prevent the app from trying to process a new image while it's still busy with the
    last one, which would cause it to crash.
> - `_customPaint`: This will hold the `CustomPainter` we just created.

In `lib/main.dart`, inside `_FaceDetectorViewState`, add the following variables:

```dart
  // This is the "brain" from Google's ML Kit that finds faces.
// We enable tracking to give each face a unique ID.
final FaceDetector _faceDetector = FaceDetector(
  options: FaceDetectorOptions(
    enableContours: true,
    enableLandmarks: true,
    enableTracking: true,
    performanceMode: FaceDetectorMode.fast,
  ),
);

// These act like traffic lights to prevent the app from crashing by processing too many images at once.
bool _canProcess = true;
bool _isBusy = false;

// This will hold our custom painter, which draws on the screen.
CustomPaint? _customPaint;
String? _text;
var _cameraLensDirection = CameraLensDirection.front;
```

> **Explanation:** This is the most important method right now. It's the link between the camera ("
> eyes") and the ML model ("brain").
> - It's `async`, meaning it can perform tasks (like face detection) without freezing the app's UI.
> - It takes an `InputImage` from the camera stream.
> - It checks our "traffic lights" (`_canProcess` and `_isBusy`).
> - `await _faceDetector.processImage(inputImage)`: This is where the magic happens. We send the
    image to the ML model and `await` the results.
> - Once we get the `faces` back, we create our `FaceDetectorPainter` and give it the list of faces
    to draw.
> - We wrap our painter in a `CustomPaint` widget and use `setState` to tell Flutter to update the
    screen with our new drawings.

Then, add the `_processImage` method inside `_FaceDetectorViewState`:

```dart
  Future<void> _processImage(InputImage inputImage) async {
  if (!_canProcess) return;
  if (_isBusy) return;
  _isBusy = true;
  setState(() {
    _text = '';
  });

  // Send the image from the camera to the ML model to detect faces.
  final faces = await _faceDetector.processImage(inputImage);

  if (inputImage.metadata?.size != null &&
      inputImage.metadata?.rotation != null) {
    // If faces are found, create our painter to draw the bounding boxes.
    final painter = FaceDetectorPainter(
      faces,
      inputImage.metadata!.size,
      inputImage.metadata!.rotation,
      _cameraLensDirection,
      {}, // Empty map for eliminated players initially
    );
    _customPaint = CustomPaint(painter: painter);
  } else {
    // Fallback for when image metadata is not available.
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
```

> **Explanation:** The `DetectorView` is a helper widget that contains the `CameraView`. We need to
> pass our `_customPaint` object to it so our drawings can be overlaid on top of the camera feed. We
> also pass our `_processImage` function so the `CameraView` can call it every time it has a new
> image.

Finally, update the `DetectorView` in the `build` method:

```dart
// ... inside build method
/*

child: DetectorView(
title: 'Squid Game - Red Light Green Light',
customPaint: _customPaint,
text: _text,
onImage: _processImage,
initialCameraLensDirection: _cameraLensDirection,
onCameraLensDirectionChanged: (value) => _cameraLensDirection = value,
),

*/
// ...
```

## Step 2: Add Game Logic and Update Painter

> **Goal:** Now we'll add the actual "Red Light, Green Light" rules. We need to track when players
> are moving during a "Red Light" and mark them as eliminated.

### 2a. Update the Face Painter for Game State

> **Explanation:** Our painter needs to get smarter. Instead of just drawing green boxes, it now
> needs to draw red boxes for eliminated players.
> - We create two `Paint` objects: one green for active players, one red for eliminated players.
> - Inside the loop, we check the `eliminatedPlayers` map (which we'll create in the next step) to
    see if the current face's `trackingId` is marked as eliminated.
> - We choose the correct paint (red or green) based on the player's status.
> - We also use `TextPainter` to draw the player's number and "ELIMINATED" status above their head.
> - In `shouldRepaint`, we add `eliminatedPlayers` to the check, so the painter redraws whenever a
    player is eliminated.

In `lib/painter/face_detector_painter.dart`, update the `paint` and `shouldRepaint` methods:

```dart
  @override
void paint(Canvas canvas, Size size) {
  // Create a green paint for active players and a red paint for eliminated ones.
  final Paint paintGreen = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.0
    ..color = Colors.green;
  final Paint paintRed = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.0
    ..color = Colors.red;

  final textStyle = TextStyle(
    color: Colors.white,
    fontSize: 18,
    fontWeight: FontWeight.bold,
    backgroundColor: Colors.black54,
  );

  for (final Face face in faces) {
    final left = translateX(face.boundingBox.left, size, imageSize, rotation, cameraLensDirection);
    final top = translateY(face.boundingBox.top, size, imageSize, rotation, cameraLensDirection);
    final right = translateX(
        face.boundingBox.right, size, imageSize, rotation, cameraLensDirection);
    final bottom = translateY(
        face.boundingBox.bottom, size, imageSize, rotation, cameraLensDirection);

    final trackingId = face.trackingId;
    if (trackingId == null) continue;

    // Check if the player is in the eliminated list.
    final isEliminated = eliminatedPlayers[trackingId] ?? false;
    final paint = isEliminated ? paintRed : paintGreen;

    // Draw the bounding box with the correct color.
    canvas.drawRect(
      Rect.fromLTRB(left, top, right, bottom),
      paint,
    );

    // Draw the player's number and status above their head.
    final textSpan = TextSpan(
      text: isEliminated
          ? 'Player ${trackingId % 100} ELIMINATED'
          : 'Player ${trackingId % 100}',
      style: textStyle.copyWith(
        color: isEliminated ? Colors.red : Colors.green,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(minWidth: 0, maxWidth: size.width);
    textPainter.paint(canvas, Offset(left, top - 24));
  }
}

@override
bool shouldRepaint(FaceDetectorPainter oldDelegate) {
  // We need to repaint if the faces change OR if the list of eliminated players changes.
  return oldDelegate.imageSize != imageSize ||
      oldDelegate.faces != faces ||
      oldDelegate.eliminatedPlayers != eliminatedPlayers;
}
```

### 2b. Add Game Logic in `main.dart`

> **Explanation:** We need variables to keep track of the game's state.
> - `_isRedLight`: A boolean that's `true` when players must be still, and `false` otherwise.
> - `_lastLightSwitch` & `_lightSwitchInterval`: These control the timing of the game, switching
    between red and green light every 5 seconds.
> - `_previousFaceRects`: A `Map` to store the position of each face from the *previous* frame. This
    is how we'll detect movement.
> - `_eliminatedPlayers`: A `Set` to store the unique `trackingId` of every player who has been
    eliminated. A `Set` is used because it's fast and automatically handles duplicates.

Add the game state variables to `_FaceDetectorViewState`:

```dart
  // --- Game State Variables ---

// Is the game in "Red Light" mode?
bool _isRedLight = false;
// When did the light last change?
DateTime _lastLightSwitch = DateTime.now();
// How long between light switches.
final Duration _lightSwitchInterval = Duration(seconds: 5);
// Stores the position of each face from the previous frame to detect movement.
Map<int, Rect> _previousFaceRects = {};
// A list of all players who have been eliminated.
Set<int> _eliminatedPlayers = {};
// How many players are currently on screen.
int _totalPlayers = 0;
```

> **Explanation:** This is a simple helper method. On every frame, we'll check if enough time has
> passed since the last light switch. If it has, we flip the `_isRedLight` boolean and reset the
> timer.

Add the `_switchLightIfNeeded` method inside `_FaceDetectorViewState`:

```dart
  void _switchLightIfNeeded() {
  // Check if it's time to switch the light.
  if (DateTime.now().difference(_lastLightSwitch) > _lightSwitchInterval) {
    setState(() {
      _isRedLight = !_isRedLight; // Flip the light state.
      _lastLightSwitch = DateTime.now(); // Reset the timer.
    });
  }
}
```

> **Explanation:** This is the core of our game logic! We're updating `_processImage` to handle the
> rules.
> 1. First, we call `_switchLightIfNeeded()` to update the game state.
> 2. We get the list of `faces` from ML Kit as before.
> 3. **Movement Detection:** We loop through each face. If it's currently "Red Light" and the player
     hasn't been eliminated yet, we do the following:
     > a. Look up the face's `trackingId` in our `_previousFaceRects` map to find its position in
     the last frame.
     > b. If we have a previous position, we calculate the `distance` the center of the face has
     moved.
     > c. If the `movement` is greater than a certain threshold (e.g., 15 pixels), we add the
     player's `trackingId` to the `_eliminatedPlayers` set.
> 4. After checking all faces, we update `_previousFaceRects` with the current face positions, so
     we're ready for the next frame.
> 5. Finally, we pass the `eliminatedStatus` map to our `FaceDetectorPainter` so it knows who to
     draw in red.

Now, update the `_processImage` method to include the game logic:

```dart
  Future<void> _processImage(InputImage inputImage) async {
  _switchLightIfNeeded(); // First, check if we need to switch the light.

  if (!_canProcess) return;
  if (_isBusy) return;
  _isBusy = true;
  setState(() {
    _text = '';
  });

  final faces = await _faceDetector.processImage(inputImage);
  _totalPlayers = faces.length;

  Map<int, Rect> currentFaceRects = {};
  Map<int, bool> eliminatedStatus = {};

  for (final face in faces) {
    final trackingId = face.trackingId;
    if (trackingId != null) {
      currentFaceRects[trackingId] = face.boundingBox;

      // --- CORE GAME LOGIC ---
      // If it's a red light and the player isn't already out...
      if (_isRedLight && !_eliminatedPlayers.contains(trackingId)) {
        final prevRect = _previousFaceRects[trackingId];
        if (prevRect != null) {
          // ...check how much the face has moved since the last frame.
          final movement = (face.boundingBox.center - prevRect.center).distance;
          // If they moved too much, eliminate them!
          if (movement > 15) { // Movement threshold
            _eliminatedPlayers.add(trackingId);
          }
        }
      }
      eliminatedStatus[trackingId] = _eliminatedPlayers.contains(trackingId);
    }
  }

  // Remember the current face positions for the next frame.
  _previousFaceRects = currentFaceRects;

  if (inputImage.metadata?.size != null &&
      inputImage.metadata?.rotation != null) {
    final painter = FaceDetectorPainter(
      faces,
      inputImage.metadata!.size,
      inputImage.metadata!.rotation,
      _cameraLensDirection,
      eliminatedStatus, // Pass the latest status to the painter.
    );
    _customPaint = CustomPaint(painter: painter);
  } else {
    // Fallback for when image metadata is not available.
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
```

## Step 3: Add Audio and Timers

> **Goal:** Let's make the game more immersive with background music and a visible countdown timer.

> **Explanation:**
> - `AudioPlayer`: The object from the `audioplayers` package that will handle playing our music
    file.
> - `_secondsToNextSwitch`: An integer to hold the countdown value (e.g., "5, 4, 3...").
> - `Ticker`: This is a special, highly efficient Flutter timer that fires on every single frame.
    It's perfect for UI animations and countdowns because it's synced with the screen's refresh
    rate.

Add the following state variables to `_FaceDetectorViewState`:

```dart
  // The object that will play our background music.
final AudioPlayer _audioPlayer = AudioPlayer();
// The variable for our UI countdown timer.
int _secondsToNextSwitch = 5;
// A special timer that fires on every frame, perfect for updating the UI.
late final Ticker _ticker;
```

> **Explanation:**
> - `_onTick`: This method will be called by the `Ticker` on every frame. It calculates how many
    seconds are left until the next light switch and updates the `_secondsToNextSwitch`
    variable. `clamp` just ensures the number stays between 0 and 5.
> - `_playAudioLoop`: A simple method to start the background music and set it to loop forever.

Add the `_onTick` and `_playAudioLoop` methods:

```dart
  void _onTick(Duration elapsed) {
  // This is called on every frame.
  final secondsSinceSwitch = DateTime
      .now()
      .difference(_lastLightSwitch)
      .inSeconds;
  setState(() {
    // Update the countdown timer for the UI.
    _secondsToNextSwitch = (_lightSwitchInterval.inSeconds - secondsSinceSwitch).clamp(
      0,
      _lightSwitchInterval.inSeconds,
    );
  });
}

void _playAudioLoop() async {
  // Set the audio to loop and start playing.
  await _audioPlayer.setReleaseMode(ReleaseMode.loop);
  await _audioPlayer.play(AssetSource('audio/red_light_green_light.mp3'));
}
```

> **Explanation:** `initState` is a special method that runs exactly once when the widget is first
> created. It's the perfect place to start things that need to run for the entire lifetime of the
> screen, like our music and our countdown ticker.

In `initState`, initialize the audio and ticker:

```dart
  @override
void initState() {
  super.initState();
  // Start the music and the countdown ticker as soon as the screen loads.
  _playAudioLoop();
  _ticker = Ticker(_onTick)
    ..start();
}
```

> **Explanation:** `dispose` is the opposite of `initState`. It's called when the screen is being
> destroyed. It's crucial to clean up resources here to prevent memory leaks. We need to stop the
> ticker, close the face detector, and dispose of the audio player.

In `dispose`, clean up the resources:

```dart
  @override
void dispose() {
  // Clean up all our resources to prevent memory leaks when the screen is closed.
  _ticker.dispose();
  _canProcess = false;
  _faceDetector.close();
  _audioPlayer.dispose();
  super.dispose();
}
```

## Step 4: Add UI Overlays

> **Goal:** The game is functional, but it needs a user interface! Let's add a top app bar to show
> player stats and a bottom bar to show the game status ("Red Light" / "Green Light") and the
> countdown.

> **Explanation:** We need a way to reset the game. This method simply clears all the game state
> variables back to their initial values.

Add the `_refreshGame` method to `_FaceDetectorViewState`:

```dart
  void _refreshGame() {
  setState(() {
    // Reset all game variables to their starting values.
    _previousFaceRects.clear();
    _eliminatedPlayers.clear();
    _totalPlayers = 0;
    _customPaint = null;
    _text = null;
    _lastLightSwitch = DateTime.now();
  });
}
```

> **Explanation:** This is the final `build` method that brings everything together.
> - It uses a `Scaffold` to provide the basic app structure (app bar, body).
> - The `AppBar` at the top displays the total, active, and eliminated player counts. It also has a
    refresh button that calls our `_refreshGame` method.
> - The body uses a `Stack` widget, which allows us to place widgets on top of each other. This is
    how we overlay the UI on top of the camera feed.
> - The `DetectorView` is in the background of the `Stack`.
> - The `Positioned` widget at the bottom creates the status bar. It uses a `LinearGradient` to
    change its color from green to red based on the `_isRedLight` variable. It displays the game
    status text and our `_secondsToNextSwitch` countdown timer.

Finally, replace the entire `build` method with the one that includes the full UI:

```dart
  @override
Widget build(BuildContext context) {
  int activePlayers = _totalPlayers - _eliminatedPlayers.length;
  return Scaffold(
    // Top bar for player stats.
    appBar: AppBar(
      backgroundColor: Colors.black,
      elevation: 8,
      title: Row(
        children: [
          Icon(Icons.people, color: Colors.white, size: 22),
          SizedBox(width: 4),
          Text('Total: $_totalPlayers',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          SizedBox(width: 12),
          Icon(Icons.person_outline, color: Colors.greenAccent, size: 22),
          SizedBox(width: 4),
          Text('Active: ${activePlayers >= 0 ? activePlayers : 0}',
              style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
          SizedBox(width: 12),
          Icon(Icons.person_off, color: Colors.redAccent, size: 22),
          SizedBox(width: 4),
          Text('Elim: ${_eliminatedPlayers.length}',
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
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
        // The main camera view.
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
                        colors: [Colors.black, Colors.pink.shade900.withAlpha((255 * 0.2).toInt())],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(color: Colors.pinkAccent.withAlpha((255 * 0.2).toInt()),
                            blurRadius: 16,
                            spreadRadius: 2),
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
        // The bottom status bar, positioned over the camera view.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 16, horizontal: 32),
            decoration: BoxDecoration(
              // Change color based on the game state.
              gradient: LinearGradient(
                colors: _isRedLight ? [Colors.red.shade900, Colors.pinkAccent] : [
                  Colors.green.shade900,
                  Colors.greenAccent
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                    color: _isRedLight ? Colors.redAccent.withAlpha((255 * 0.5).toInt()) : Colors
                        .greenAccent.withAlpha((255 * 0.5).toInt()),
                    blurRadius: 12,
                    spreadRadius: 1),
              ],
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(
                  color: _isRedLight ? Colors.pinkAccent : Colors.greenAccent, width: 2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_isRedLight ? Icons.close : Icons.check_circle, color: Colors.white, size: 28),
                SizedBox(width: 16),
                Text(_isRedLight ? "RED LIGHT" : "GREEN LIGHT", style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2)),
                SizedBox(width: 32),
                Icon(Icons.timer, color: Colors.white, size: 28),
                SizedBox(width: 8),
                // Display the countdown timer.
                Text('$_secondsToNextSwitch s', style: TextStyle(
                    color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
```
