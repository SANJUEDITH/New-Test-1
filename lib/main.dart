import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:audio/audio.dart';

import 'chat_card.dart';
import 'evi_message.dart' as evi;
import 'weather_service.dart';

class ConfigManager {
  static final ConfigManager _instance = ConfigManager._internal();
  String humeApiKey = "";
  String humeAccessToken = "";
  late final String humeConfigId;
  ConfigManager._internal();
  static ConfigManager get instance => _instance;

  String fetchHumeApiKey() {
    return dotenv.env['HUME_API_KEY'] ?? "";
  }

  Future<String> fetchAccessToken() async {
    final authUrl = dotenv.env['MY_SERVER_AUTH_URL'];
    if (authUrl == null) {
      throw Exception('Please set MY_SERVER_AUTH_URL in your .env file');
    }
    final url = Uri.parse(authUrl);
    final response = await http.get(url);
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['access_token'];
    } else {
      throw Exception('Failed to load access token');
    }
  }

  Future<void> loadConfig() async {
    await dotenv.load();
    humeApiKey = fetchHumeApiKey();
    humeConfigId = dotenv.env['HUME_CONFIG_ID'] ?? '';
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ConfigManager.instance.loadConfig();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    if (ConfigManager.instance.humeApiKey.isEmpty &&
        ConfigManager.instance.humeAccessToken.isEmpty) {
      return MaterialApp(
        title: 'Nissan Assistant',
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Column(
            children: [
              const SizedBox(height: 60),
              Center(
                child: Image.asset(
                  'assets/nissan-seeklogo.png',
                  height: 100,
                  errorBuilder: (context, error, stackTrace) {
                    print("Error loading Nissan logo: $error");
                    return const Icon(Icons.car_repair, size: 100, color: Colors.orange);
                  },
                ),
              ),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.orange,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "Error: Please set your Hume API key or access token.",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.grey),
          primaryColor: Colors.orange,
          useMaterial3: true,
        ),
        debugShowCheckedModeBanner: false,
      );
    }

    return MaterialApp(
      title: 'Nissan Assistant',
      home: const MyHomePage(),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.grey),
        primaryColor: Colors.orange,
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
    );
  }

  static List<Score> extractTopThreeEmotions(evi.Inference models) {
    final scores = models.prosody?.scores ?? {};
    final scoresArray = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return scoresArray.take(3).map((entry) {
      return Score(emotion: entry.key, score: entry.value);
    }).toList();
  }
}

// ErrorMessage class removed as it's now inlined in the error UI

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final Audio _audio = Audio();
  WebSocketChannel? _chatChannel;
  bool _isConnected = false;
  bool _isMuted = false;
  bool _isProcessing = false;
  var chatEntries = <ChatEntry>[];
  
  // Weather preferences
  String _lastWeatherLocation = 'Delhi, India';
  String _lastWeatherFormat = 'celsius';
  

  void appendNewChatMessage(evi.ChatMessage chatMessage, evi.Inference models) {
    final role = chatMessage.role == 'assistant' ? Role.assistant : Role.user;
    final entry = ChatEntry(
      role: role,
      timestamp: DateTime.now().toString(),
      content: chatMessage.content,
      scores: MyApp.extractTopThreeEmotions(models),
    );
    setState(() {
      chatEntries.add(entry);
    });
  }

  final TextEditingController _textController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    void _onSubmit() {
      final input = _textController.text.trim();
      if (input.isNotEmpty && _isConnected && !_isProcessing) {
        debugPrint('User input: $input');
        
        setState(() {
          _isProcessing = true;
        });
        
        // Send a message to the current chat channel
        _chatChannel?.sink.add(jsonEncode({
          'type': 'text_input',
          'text': input,
        }));
        
        _textController.clear();
      } else if (!_isConnected) {
        // Show a snackbar to indicate the user needs to connect first
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please connect first to send messages'),
            duration: Duration(seconds: 2),
          ),
        );
      } else if (_isProcessing) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please wait, still processing your previous request'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }

    void _onEngineOilPressed() {
      debugPrint('Engine Oil button pressed');
      if (_isConnected && !_isProcessing) {
        setState(() {
          _isProcessing = true;
        });
        
        _chatChannel?.sink.add(jsonEncode({
          'type': 'text_input',
          'text': 'Tell me about engine oil maintenance for my Nissan vehicle',
        }));
      } else if (!_isConnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please connect first to use this feature'),
            duration: Duration(seconds: 2),
          ),
        );
      } else if (_isProcessing) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please wait, still processing your previous request'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }

    void _onTirePressurePressed() {
      debugPrint('Tire Pressure button pressed');
      if (_isConnected && !_isProcessing) {
        setState(() {
          _isProcessing = true;
        });
        
        _chatChannel?.sink.add(jsonEncode({
          'type': 'text_input',
          'text': 'What should my tire pressure be in my Nissan vehicle and how do I check it?',
        }));
      } else if (!_isConnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please connect first to use this feature'),
            duration: Duration(seconds: 2),
          ),
        );
      } else if (_isProcessing) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please wait, still processing your previous request'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          const SizedBox(height: 60),
          Center(
            child: Image.asset(
              'assets/nissan-seeklogo.png',
              height: 100,
              errorBuilder: (context, error, stackTrace) {
                print("Error loading Nissan logo: $error");
                return const Icon(Icons.car_repair, size: 100, color: Colors.orange);
              },
            ),
          ),

          // Connection status - subtle indicator
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Text(
              _isConnected ? 'Connected' : 'Disconnected',
              style: TextStyle(
                fontSize: 12, 
                color: _isConnected ? Colors.green : Colors.red,
              ),
            ),
          ),

          // Main chat section
          Expanded(
            child: chatEntries.isEmpty
                ? const Center(
                    child: Text(
                      "Ask me anything about your Nissan vehicle!",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  )
                : ChatDisplay(entries: chatEntries),
          ),

          // Connection and mute controls - subtle row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: _isConnected ? _disconnect : _connect,
                  child: Text(_isConnected ? 'Disconnect' : 'Connect'),
                ),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: _isMuted ? _unmuteInput : _muteInput,
                  child: Text(_isMuted ? 'Unmute' : 'Mute'),
                ),
              ],
            ),
          ),

          // Quick action buttons
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton(
                    heroTag: 'btn1',
                    onPressed: _onEngineOilPressed,
                    tooltip: 'Engine Oil',
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    backgroundColor: Colors.orange,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Image.asset(
                        'assets/icons8-engine-oil-48.png',
                        height: 24,
                        width: 24,
                        errorBuilder: (context, error, stackTrace) {
                          print("Error loading engine oil icon: $error");
                          return const Icon(Icons.oil_barrel, size: 24, color: Colors.orange);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  FloatingActionButton(
                    heroTag: 'btn2',
                    onPressed: _onTirePressurePressed,
                    tooltip: 'Tire Pressure',
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    backgroundColor: Colors.black,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Image.asset(
                        'assets/icons8-tire-pressure-50.png',
                        height: 24,
                        width: 24,
                        errorBuilder: (context, error, stackTrace) {
                          print("Error loading tire pressure icon: $error");
                          return const Icon(Icons.tire_repair, size: 24, color: Colors.black);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Input field
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _textController,
              enabled: _isConnected && !_isProcessing,
              onSubmitted: (_) => _onSubmit(),
              decoration: InputDecoration(
                hintText: _isProcessing 
                  ? 'Processing...' 
                  : (_isConnected ? 'Enter your query here...' : 'Connect first to chat...'),
                suffixIcon: _isProcessing 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.orange,
                        ),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _isConnected ? _onSubmit : null,
                      color: _isConnected ? Colors.orange : Colors.grey,
                    ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _isConnected ? Colors.orange : Colors.grey,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _audio.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _connect() {
    setState(() {
      _isConnected = true;
    });

    var uri = 'wss://api.hume.ai/v0/evi/chat';
    final cfg = ConfigManager.instance;
    if (cfg.humeAccessToken.isNotEmpty) {
      uri += '?access_token=${cfg.humeAccessToken}';
    } else if (cfg.humeApiKey.isNotEmpty) {
      uri += '?api_key=${cfg.humeApiKey}';
    }

    if (cfg.humeConfigId.isNotEmpty) {
      uri += '&config_id=${cfg.humeConfigId}';
    }

    _chatChannel = WebSocketChannel.connect(Uri.parse(uri));

    _chatChannel!.stream.listen((event) async {
      final message = evi.EviMessage.decode(event);
      switch (message) {
        case (evi.ErrorMessage errorMessage):
          debugPrint("Error: ${errorMessage.message}");
          break;
        case (evi.ChatMetadataMessage _):
          _prepareAudioSettings();
          _startRecording();
          break;
        case (evi.AudioOutputMessage audioOutputMessage):
          _audio.enqueueAudio(audioOutputMessage.data);
          break;
        case (evi.UserInterruptionMessage _):
          _handleInterruption();
          break;
        case (evi.AssistantMessage assistantMessage):
          appendNewChatMessage(assistantMessage.message, assistantMessage.models);
          setState(() {
            _isProcessing = false;
          });
          break;
        case (evi.UserMessage userMessage):
          appendNewChatMessage(userMessage.message, userMessage.models);
          _handleInterruption();
          break;
        case (evi.ToolCallMessage toolCallMessage):
          // Handle tool calls via our handler
          await _handleWeatherToolCall(
            toolCallMessage.name, 
            toolCallMessage.parameters, 
            toolCallMessage.toolCallId
          );
          break;
        case (evi.UnknownMessage unknownMessage):
          debugPrint("Unknown message type: ${unknownMessage.type}");
          debugPrint("Full unknown message: ${jsonEncode(unknownMessage.rawJson)}");
          
          // Handle assistant_end message explicitly
          if (unknownMessage.type == 'assistant_end') {
            debugPrint("Assistant ended conversation");
          }
          break;
      }
    }, onError: (error) {
      debugPrint("Connection error: $error");
      _handleConnectionClosed();
    }, onDone: () {
      debugPrint("Connection closed");
      _handleConnectionClosed();
    });
  }

  Future<void> _handleWeatherToolCall(String toolName, Map<String, dynamic> params, String toolCallId) async {
    // Handle both correct spelling and misspelled version
    if (toolName == 'get_current_weather' || toolName == 'get_cuurent_weather') {
      debugPrint("Weather tool called with name: $toolName");
      
      // Add debug output for parameters
      debugPrint("Parameters type: ${params.runtimeType}");
      debugPrint("Raw parameters: ${jsonEncode(params)}");
      
      // Start with the last used preferences or defaults
      String location = _lastWeatherLocation;
      String format = _lastWeatherFormat;

      // If parameters are empty, try to extract location from the last user message
      if (params.isEmpty && chatEntries.isNotEmpty) {
        // Look for the last user message
        for (int i = chatEntries.length - 1; i >= 0; i--) {
          if (chatEntries[i].role == Role.user) {
            final userMessage = chatEntries[i].content.toLowerCase();
            debugPrint("Analyzing user message: $userMessage");
            
            // Try to find city name in user message
            List<String> possibleCityNames = _extractPossibleCities(userMessage);
            if (possibleCityNames.isNotEmpty) {
              location = possibleCityNames.first;
              _lastWeatherLocation = location;
              debugPrint("Extracted location from user message: $location");
            }
            break;
          }
        }
      }

      try {
        // 1. Try to extract 'location' parameter directly
        if (params.containsKey('location') &&
            params['location'] != null &&
            params['location'].toString().trim().isNotEmpty) {
          location = params['location'].toString().trim();
          debugPrint("Using location from params: $location");
          _lastWeatherLocation = location;
        } else {
          // 2. If 'location' is not present, try to extract the first non-empty string value
          for (var value in params.values) {
            if (value != null && value.toString().trim().isNotEmpty) {
              location = value.toString().trim();
              debugPrint("Using first non-empty value as location: $location");
              _lastWeatherLocation = location;
              break;
            }
          }
        }

        // 3. Extract 'format' parameter if present
        if (params.containsKey('format') &&
            params['format'] != null &&
            params['format'].toString().trim().isNotEmpty) {
          format = params['format'].toString().trim().toLowerCase();
          debugPrint("Using format from params: $format");
          _lastWeatherFormat = format;
        }

        debugPrint("Final weather params: location=$location, format=$format");
      } catch (e) {
        debugPrint("Error extracting parameters: $e");
      }
      
      debugPrint("Weather request for location: $location, format: $format");
      
      try {
        // Call fetchWeather directly from our imported file
        final result = await fetchWeather(location, format);
        debugPrint("Weather result: $result");
        
        // Ensure we have a valid tool call ID before sending response
        if (toolCallId.isNotEmpty) {
          final response = {
            "type": "tool_response",
            "tool_call_id": toolCallId,
            "content": result,
          };

          _chatChannel?.sink.add(jsonEncode(response));
          debugPrint("Tool response sent for $toolCallId");
        } else {
          debugPrint("Warning: Cannot send tool response - missing tool call ID");
        }
      } catch (e) {
        debugPrint("Error in weather tool call flow: $e");
        
        // Try to send an error response if possible
        if (toolCallId.isNotEmpty) {
          final errorResponse = {
            "type": "tool_response",
            "tool_call_id": toolCallId,
            "content": "Sorry, there was an error processing the weather request: $e",
          };
          _chatChannel?.sink.add(jsonEncode(errorResponse));
        }
      }
    } else {
      debugPrint("Unknown tool call: $toolName");
    }
  }

  void _disconnect() {
    _handleConnectionClosed();
    _handleInterruption();
    _chatChannel?.sink.close();
  }

  void _handleConnectionClosed() {
    setState(() {
      _isConnected = false;
    });
    _stopRecording();
  }

  void _handleInterruption() {
    _audio.stopPlayback();
  }

  void _muteInput() {
    _stopRecording();
    setState(() {
      _isMuted = true;
    });
  }

  void _unmuteInput() {
    _startRecording();
    setState(() {
      _isMuted = false;
    });
  }

  void _prepareAudioSettings() {
    _chatChannel?.sink.add(jsonEncode({
      'type': 'session_settings',
      'audio': {
        'encoding': 'linear16',
        'sample_rate': 48000,
        'channels': 1,
      },
    }));
  }

  void _sendAudio(String base64) {
    _chatChannel?.sink.add(jsonEncode({
      'type': 'audio_input',
      'data': base64,
    }));
  }

  void _startRecording() async {
    await _audio.startRecording();
    _audio.audioStream.listen((data) {
      _sendAudio(data);
    }, onError: (error) {
      debugPrint("Error recording audio: $error");
    });
  }

  void _stopRecording() {
    _audio.stopRecording();
  }

  List<String> _extractPossibleCities(String userMessage) {
    // Improved regex patterns to capture city names more effectively
    final RegExp cityNamePattern = RegExp(
      r'\b(?:in|at|for|to)\s+([A-Za-z\s-]+)(?:\s+weather|\s+forecast)?\b',
      caseSensitive: false,
    );

    final matches = cityNamePattern.allMatches(userMessage);
    return matches.map((match) {
      // Return the first capturing group which should be the city name
      return match.group(1)?.trim() ?? '';
    }).where((city) => city.isNotEmpty).toList();
  }
}
