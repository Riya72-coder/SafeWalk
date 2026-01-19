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
  // checkSafetyWithGemini("Help me! Someone is following me!");
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
      // checkSafetyWithGemini("Help me, someone is following me!");
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
    String lowerText = text.toLowerCase();
    if(lowerText.contains("help") || lowerText.contains("bachao") || lowerText.contains("danger")) {
      setState(() {
        _isDanger = true;
        _wordsSpoken = "Emergency Detected: $text";
      });
      return;
    }
    final model = GenerativeModel(model: "gemini-1.5-flash", apiKey: "AIzaSyD4f_SwQ9hiXKGAj8j5oT8NHvAhkYUYuIY");

    final prompt = """
      Analyze this user audio transcript: '$text'.
      Is the user in immediate physical danger?
      Look for keywords in English, Hindi, or Marathi like 'Help', 'Bachao', 'Follow', 'Kidnap'.
      Reply with ONLY one word: 'ALERT' or 'SAFE'.
    """;
    try {
      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);
      final responseText = response.text?.trim().toUpperCase() ?? "";

      setState(() {
        if(responseText.contains("ALERT")) {
          _isDanger = true;
          _wordsSpoken = "⚠️ ALERT: $text";
        } else {
          _isDanger = false;
          _wordsSpoken = "✅ Safe: $text";
        }
      });
    } catch (e) {
      debugPrint("---GEMINI DEBUG ERROR---");
      debugPrint(e.toString());
      debugPrint("----------------");
      setState(() {
        _wordsSpoken = "AI Error: terminal/console";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDanger ? Colors.red.shade900: Colors.indigo.shade900,
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
                  color: Colors.white ,
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

              if(_isDanger)...[
                const SizedBox(height: 15),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isDanger = false;
                      _wordsSpoken = "Tap the mic and say something...";
                    });
                  },
                  icon: const Icon(Icons.check_circle, color: Colors.white),
                  label: const Text("i AM SAFE NOW", style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    minimumSize: const Size(double.infinity,50),
                  ),
                ),
              ],
            ],
          ),
        ),
        ],
      ),
    );
  }
}
