import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:torch_light/torch_light.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BikePlay',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 0, 255, 21)),
      ),
      home: const MyHomePage(title: 'BikePlay'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  final player = AudioPlayer();

  void _playBeep() async {
    await player.play(AssetSource('beep.mp3'));
  }

  bool _isFlashlightOn = false;

  Future<void> _toggleFlashlight() async {
    final status = await Permission.camera.request();

    if (!status.isGranted) {
      print("Camera permission not granted");
      return;
    }

    setState(() {
      _isFlashlightOn = !_isFlashlightOn;
    });

    try {
      final available = await TorchLight.isTorchAvailable();
      print("Torch available: $available");

      if (!available) return;

      if (_isFlashlightOn) {
        print("Enabling torch");
        await TorchLight.enableTorch();
      } else {
        print("Disabling torch");
        await TorchLight.disableTorch();
      }
    } catch (e, stack) {
      print("Torch error: $e");
      print(stack);
    }
  }

  StreamSubscription<Position>? _positionStream;
  double _speedMps = 0.0;
  final List<double> _speedBuffer = [];

  Future<bool> _ensureLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
  }

  void _startSpeedometer() async {
    final allowed = await _ensureLocationPermission();
    if (!allowed) return;

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 1,
      ),
    ).listen((Position position) {
      final mph = position.speed * 2.23694;

      _speedBuffer.add(mph);
      if (_speedBuffer.length > 5) {
        _speedBuffer.removeAt(0);
      }

      final smoothSpeed =
          _speedBuffer.reduce((a, b) => a + b) / _speedBuffer.length;

      setState(() {
        _speedMps = smoothSpeed;
      });
    });
  }

  void _stopSpeedometer() {
    _positionStream?.cancel();
    _positionStream = null;
  }

  @override
  void initState() {
    super.initState();
    _startSpeedometer();
  }

  @override
  void dispose() {
    _stopSpeedometer();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(
          widget.title,
          style: const TextStyle(
            fontFamily: 'cursive', 
            fontSize: 40,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragEnd: (details) {
          if (details.velocity.pixelsPerSecond.dy < 0) {
            _playBeep(); 
          }
        },
        onDoubleTap: _toggleFlashlight,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text('Your Speed:'),
              Text(
                '$_counter',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Text(
                _speedMps.toStringAsFixed(1),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 20),
              const Text('(Try swiping up anywhere on the screen!v3)'),
            ],
          ),
        ),
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FloatingActionButton.large(
            onPressed: _incrementCounter,
            tooltip: 'Increment',
            child: const Icon(Icons.add),
          ),
          const SizedBox(width: 16), // space between buttons
          FloatingActionButton.large(
            onPressed: _playBeep,
            tooltip: 'Beep',
            child: const Icon(Icons.notifications),
          ),
          const SizedBox(width: 16),
          FloatingActionButton.large(
            onPressed: _toggleFlashlight,
            tooltip: 'Flashlight',
            child: Icon(
              _isFlashlightOn ? Icons.flashlight_off : Icons.flashlight_on,
              size: 40,
            ),
          ),
        ],
      ),
    );
  }
}
