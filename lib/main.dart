import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';
import 'package:dotenv/dotenv.dart' as dotenv;

void main() {
  dotenv.load();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'API Integration Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: ApiIntegrationScreen(),
    );
  }
}

class ApiIntegrationScreen extends StatefulWidget {
  @override
  _ApiIntegrationScreenState createState() => _ApiIntegrationScreenState();
}

class _ApiIntegrationScreenState extends State<ApiIntegrationScreen> {
  TextDetector textDetector = GoogleMlKit.vision.textDetector();
  CameraController _controller;
  bool _isCameraInitialized = false;
  String detectedText = '';
  String generatedText = '';

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (await Permission.camera.request().isGranted) {
      try {
        final cameras = await availableCameras();
        final camera = cameras.first;
        _controller = CameraController(
          camera,
          ResolutionPreset.medium,
        );

        await _controller.initialize();

        setState(() {
          _isCameraInitialized = true;
        });
      } catch (e) {
        print('Error initializing camera: $e');
      }
    } else {
      print('Camera permission denied');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    textDetector.close();
    super.dispose();
  }

  Future<void> _processImage(XFile image) async {
    try {
      final inputImage = InputImage.fromFilePath(image.path);
      final recognisedText = await textDetector.processImage(inputImage);
      String text = recognisedText.text;
      setState(() {
        detectedText = text;
      });
    } catch (e) {
      print('Error in _processImage: $e');
    }
  }

  Future<void> _generateText(String input) async {
    try {
      String apiKey = dotenv.env['OPENAI_API_KEY'];
      if (apiKey == null) {
        print('OPENAI_API_KEY environment variable not set');
        return;
      }
      String endpoint = 'https://api.openai.com/v1/completions';
      String model = 'text-davinci-003';
      int maxTokens = 50;

      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': model,
          'prompt': input,
          'max_tokens': maxTokens,
        }),
      );

      if (response.statusCode == 200) {
        Map<String, dynamic> data = jsonDecode(response.body);
        setState(() {
          generatedText = data['choices'][0]['text'];
        });
      } else {
        print('Error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in _generateText: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('API Integration Demo'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: CameraPreview(_controller),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                try {
                  final XFile image = await _controller.takePicture();
                  if (image != null) {
                    await _processImage(image);
                  }
                } catch (e) {
                  print('Error in takePicture: $e');
                }
              },
              child: Text('Process Image'),
            ),
            SizedBox(height: 20),
            Text(
              'Detected Text:',
              style: TextStyle(fontSize: 20),
            ),
            SizedBox(height: 10),
            Text(
              detectedText,
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: detectedText.isNotEmpty
                  ? () async {
                      await _generateText(detectedText);
                    }
                  : null,
              child: Text('Generate Text'),
            ),
            SizedBox(height: 20),
            Text(
              'Generated Text:',
              style: TextStyle(fontSize: 20),
            ),
            SizedBox(height: 10),
            Text(
              generatedText,
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}