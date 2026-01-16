import "package:flutter/material.dart";
import "package:google_generative_ai/google_generative_ai.dart";
import "package:speech_to_text/speech_to_text.dart" as stt;
import "package:permission_handler/permission_handler.dart";

void main() => runApp(const SafeWalkApp());

class SafeWalkApp extends StatelessWidget {
  const SafeWalkApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.indigo, useMaterial3: true),
      home: const MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  // logic variables
  bool _isListening = false;
  String _wordsSpoken = "Tap the mic and say something...";
  bool _isDanger = false;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  //1. Ask for permission
  Future<void> _requestPermissions() async {
    await [Permission.microphone, Permission.location].request();
  }

  //2. The voice logic
  void _listen() async {
  var status = await Permission.microphone.status;
  
  if (status.isDenied) {
    await Permission.microphone.request();
    return; 
  }

  if (!_isListening) {
    bool available = await _speech.initialize(
      onStatus: (val) => debugPrint('Speech Status: $val'),
      onError: (val) => debugPrint('Speech Error: $val'),
    );
    
    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (val) => setState(() {
          _wordsSpoken = val.recognizedWords;
          if (val.finalResult) {
            _isListening = false;
            checkSafetyWithGemini(_wordsSpoken);
          }
        }),
        listenFor: const Duration(seconds: 60), //keeps mic listening longer than just millisec.
        pauseFor: const Duration(seconds: 30), //Allows pauses while speking
      );
    } // This closes 'if (available)'
    else {
      debugPrint("The user has denied the use of speech recognition or mic is busy.");
    } 
  } // This closes 'if (!_isListening)'
  else {
    setState(() => _isListening = false);
    _speech.stop();
  }
}

  // 3. The AI brain
  Future<void> checkSafetyWithGemini(String text) async {
    final model = GenerativeModel(
      model: "gemini-1.5-flash",
      apiKey: "AIzaSyBdmjgt0kKlJZujyhCYV-FOLnUvwNzYO0Y",
    );

    final prompt = "User Said: '$text'. Analyze for danger(Help, Bacho, etc). Reply ONLY 'Alert' or 'OK'. ";
    final content = [Content.text(prompt)];
    final response = await model.generateContent(content);

    if(response.text?.contains("ALERT") ?? false) {
      _triggerAlert();
    }
  }
  void _triggerAlert() {
    setState(() {
      _isDanger = true; // change UI to red color for showing warning 
    });
    // add code to send SMS/whatsapp
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDanger ? Colors.red[900]: Colors.grey[100],
      appBar: AppBar(
        title: const Text("SafeWalk Guardian"),
        backgroundColor: _isDanger ? Colors.red : Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                _isDanger ? "DANGER DETECTED!" : _wordsSpoken,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  color: _isDanger ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,                
                ),
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(30),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            children: [
              Text(_isDanger ? "Emergency Services Alerted" : "Guardian is Listening"),
              const SizedBox(height: 20),
              FloatingActionButton.extended(
                onPressed: _listen,
                label: Text(_isListening ? "Listening..." : "Talk to Guardian"),
                icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
                backgroundColor: _isListening ? Colors.red : Colors.indigo,
              ),
            ],
          ),
        ),
        ],
      ),
    );
  }
}
