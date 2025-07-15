import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:record/record.dart';
import 'voip_service.dart';
import 'dart:math';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VoIP Dialer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const DialerPage(),
    );
  }
}

class DialerPage extends StatefulWidget {
  const DialerPage({super.key});

  @override
  State<DialerPage> createState() => _DialerPageState();
}

class _DialerPageState extends State<DialerPage> {
  String _phoneNumber = '';
  final VoIPService _voipService = VoIPService();
  String _currentUserId = '';
  bool _isInitialized = false;
  String _serverResponse = '';
  final TextEditingController _testMessageController = TextEditingController();
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String? _recordingPath;
  
  // RunPod server URL setting
  String _runPodUrl = 'http://your-runpod-url:8000';
  final TextEditingController _runPodUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeVoIP();
  }

  Future<String> _getServerUrl() async {
    List<String> possibleIPs = [];

    // Step 1: Check network connectivity and get network info
    try {
      var connectivityResult = await Connectivity().checkConnectivity();
      print('📶 Network type: $connectivityResult');

      if (connectivityResult == ConnectivityResult.none) {
        print('⚠️ No network connection detected');
        return 'http://localhost:3000';
      }

      // If on mobile data, skip cloud server and use local network detection
      if (connectivityResult == ConnectivityResult.mobile) {
        print('📱 Mobile data detected - scanning local network for server');
      }
    } catch (e) {
      print('Connectivity check failed: $e');
    }

    // Step 2: Try to detect current device's network automatically
    try {
      // Attempt to get external IP for better network detection context
      await http
          .get(Uri.parse('https://api.ipify.org?format=json'))
          .timeout(const Duration(seconds: 3));

      // Continue with local network scanning regardless of external IP result
    } catch (e) {
      // External IP detection failed, continue with local scanning
      print('External IP detection failed, scanning local networks: $e');
    }

    // Step 3: Comprehensive network scanning
    // Common network ranges - ordered by probability
    List<String> networkBases = [
      '192.168.1', // Most common home networks
      '192.168.0', // Common router default
      '192.168.2', // Some routers use this
      '192.168.4', // Some mobile hotspots
      '10.0.0', // Corporate/some home networks
      '10.0.1', // Alternative corporate range
      '172.16.0', // Private networks
      '172.20.10', // iPhone hotspot default
      '192.168.43', // Android hotspot default
      '192.168.137', // Windows mobile hotspot default
    ];

    // For each network base, scan the most likely IPs
    for (String base in networkBases) {
      // First try the most common server/router IPs
      possibleIPs.addAll([
        '$base.1', // Most common router IP
        '$base.254', // Alternative router IP
        '$base.100', // Common server IP
        '$base.10', // Common server IP
        '$base.2', // Sometimes used for servers
        '$base.5', // Sometimes used for servers
      ]);

      // Then scan a broader range for development servers
      for (int i = 3; i <= 50; i++) {
        if (i != 10 && i != 100 && i != 254) {
          // Skip already added IPs
          possibleIPs.add('$base.$i');
        }
      }
    }

    // Add localhost variants
    possibleIPs.addAll([
      '127.0.0.1', // Localhost IPv4
      '0.0.0.0', // All interfaces
    ]);

    // Remove duplicates while preserving order
    possibleIPs = possibleIPs.toSet().toList();

    print('🔍 Scanning ${possibleIPs.length} possible server locations...');
    print('📋 Priority networks: ${networkBases.take(3).join(', ')}...');

    // Test each IP to see if the signaling server is running
    int testedCount = 0;
    for (String ip in possibleIPs) {
      testedCount++;
      if (testedCount % 20 == 0) {
        print('📊 Tested $testedCount/${possibleIPs.length} locations...');
      }

      try {
        final response = await http
            .get(Uri.parse('http://$ip:3000'))
            .timeout(
              const Duration(milliseconds: 1200),
            ); // Fast timeout for scanning

        if (response.statusCode == 200) {
          // Check if it's actually our VoIP server by looking for expected response
          if (response.body.contains('VoIP') ||
              response.body.contains('signaling')) {
            print('✅ Found VoIP server at: http://$ip:3000');
            print('📝 Server response: ${response.body.substring(0, 100)}...');
            return 'http://$ip:3000';
          } else {
            print('📍 Found HTTP server at $ip:3000 but not VoIP server');
          }
        } else if (response.statusCode == 404) {
          // Server is responding but might not have root endpoint - could still be our server
          print('� Found server at: http://$ip:3000 (testing further...)');

          // Try to ping a VoIP-specific endpoint
          try {
            final testResponse = await http
                .get(Uri.parse('http://$ip:3000/socket.io/'))
                .timeout(const Duration(milliseconds: 500));
            if (testResponse.statusCode == 400 ||
                testResponse.body.contains('socket.io')) {
              print('✅ Confirmed VoIP server at: http://$ip:3000');
              return 'http://$ip:3000';
            }
          } catch (e) {
            // Continue searching
          }
        }
      } catch (e) {
        // Server not found on this IP, continue silently
        continue;
      }
    }

    print(
      '⚠️ No VoIP server found after scanning ${possibleIPs.length} locations',
    );
    print('💡 Make sure your signaling server is running on port 3000');
    print('🔄 Using localhost fallback - server may be on this device');

    // Final fallback to localhost for desktop testing
    return 'http://localhost:3000';
  }

  Future<void> _initializeVoIP() async {
    // Request permissions
    await _requestPermissions();

    // Generate a random numeric user ID for this session
    _currentUserId =
        '${Random().nextInt(9000) + 1000}'; // 4-digit number (1000-9999)

    // Auto-detect server URL
    String serverUrl = await _getServerUrl();
    print('Using server URL: $serverUrl');

    // Initialize VoIP service
    await _voipService.initialize(serverUrl: serverUrl, userId: _currentUserId);

    // Set up callbacks
    _voipService.onIncomingCall = (String fromUser) {
      _showIncomingCallDialog(fromUser);
    };

    _voipService.onCallEnded = () {
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Call ended')));
      }
    };

    _voipService.onError = (String error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $error')));
      }
    };

    // Set up scam alert callback
    _voipService.onScamAlert = (ScamAlert alert) {
      if (mounted) {
        _showScamAlert(alert);
      }
    };

    setState(() {
      _isInitialized = true;
    });
  }

  Future<void> _requestPermissions() async {
    await [Permission.microphone, Permission.camera].request();
  }

  void _showIncomingCallDialog(String fromUser) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => IncomingCallPage(
          callerName: fromUser,
          onAccept: () {
            _voipService.acceptIncomingCall();
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    CallingPage(phoneNumber: fromUser, isIncomingCall: true),
              ),
            );
          },
          onReject: () {
            _voipService.rejectIncomingCall();
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  void _showScamAlert(ScamAlert alert) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: alert.level == 'HIGH' ? Colors.red[50] : Colors.orange[50],
          title: Row(
            children: [
              Icon(
                alert.level == 'HIGH' ? Icons.dangerous : Icons.warning,
                color: alert.level == 'HIGH' ? Colors.red : Colors.orange,
                size: 28,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  alert.level == 'HIGH' ? 'SCAM ALERT!' : 'CAUTION',
                  style: TextStyle(
                    color: alert.level == 'HIGH' ? Colors.red[800] : Colors.orange[800],
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                alert.message,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                alert.details,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              const Text(
                'Recommendations:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              ...alert.recommendations.map((rec) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(child: Text(rec, style: const TextStyle(fontSize: 13))),
                  ],
                ),
              )).toList(),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Acknowledge'),
            ),
            if (alert.level == 'HIGH')
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _voipService.endCall(); // End call immediately for high risk
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('End Call'),
              ),
          ],
        );
      },
    );
  }

  void _addDigit(String digit) {
    setState(() {
      if (_phoneNumber.length < 15) {
        _phoneNumber += digit;
      }
    });
  }

  void _deleteDigit() {
    setState(() {
      if (_phoneNumber.isNotEmpty) {
        _phoneNumber = _phoneNumber.substring(0, _phoneNumber.length - 1);
      }
    });
  }

  void _callNumber() {
    if (_phoneNumber.isNotEmpty && _isInitialized) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              CallingPage(phoneNumber: _phoneNumber, isIncomingCall: false),
        ),
      );
    }
  }

  Widget _buildDialButton(String digit) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ElevatedButton(
          onPressed: () => _addDigit(digit),
          child: Text(digit, style: const TextStyle(fontSize: 24)),
        ),
      ),
    );
  }

  Future<void> _testServerConnection() async {
    setState(() {
      _serverResponse = 'Testing server connection...';
    });

    try {
      // Use the configurable RunPod URL
      String serverUrl = _runPodUrl;
      
      // Test health endpoint first
      final healthResponse = await http.get(
        Uri.parse('$serverUrl/health'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (healthResponse.statusCode == 200) {
        setState(() {
          _serverResponse = 'Server Health: ${healthResponse.body}';
        });
      } else {
        setState(() {
          _serverResponse = 'Health check failed: ${healthResponse.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _serverResponse = 'Connection failed: $e';
      });
    }
  }

  Future<void> _testScamDetection() async {
    setState(() {
      _serverResponse = 'Testing scam detection...';
    });

    try {
      String serverUrl = _runPodUrl;
      
      // Test the scam detection endpoint with sample data
      final testData = {
        'call_id': 'test_${DateTime.now().millisecondsSinceEpoch}',
        'audio_data': 'test_audio_chunk',
        'text': _testMessageController.text.isNotEmpty 
          ? _testMessageController.text 
          : 'Hello, this is a test message for scam detection',
        'speaker': 'caller',
      };

      final response = await http.post(
        Uri.parse('$serverUrl/analyze_audio'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(testData),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        setState(() {
          _serverResponse = '''✅ Scam Detection Test Results:
          
🔍 Analysis Complete:
${jsonEncode(responseData, toEncodable: (obj) => obj.toString())}

📊 Status: ${responseData['status'] ?? 'Unknown'}
⚡ Processing Time: ${responseData['processing_time'] ?? 'N/A'}s
🛡️ Scam Risk: ${responseData['scam_risk'] ?? 'Unknown'}''';
        });
      } else {
        setState(() {
          _serverResponse = 'Scam detection failed: ${response.statusCode}\nResponse: ${response.body}';
        });
      }
    } catch (e) {
      setState(() {
        _serverResponse = 'Scam detection error: $e';
      });
    }
  }

  Future<void> _startRecording() async {
    try {
      // Request microphone permission
      if (await _audioRecorder.hasPermission()) {
        // Start recording
        await _audioRecorder.start(const RecordConfig(), path: '/tmp/test_recording.wav');
        setState(() {
          _isRecording = true;
          _serverResponse = '🎤 Recording audio... Tap "Stop & Send" when done.';
        });
      } else {
        setState(() {
          _serverResponse = '❌ Microphone permission denied';
        });
      }
    } catch (e) {
      setState(() {
        _serverResponse = 'Recording error: $e';
      });
    }
  }

  Future<void> _stopRecordingAndSend() async {
    try {
      if (_isRecording) {
        // Stop recording
        _recordingPath = await _audioRecorder.stop();
        setState(() {
          _isRecording = false;
          _serverResponse = '🔄 Processing recording and sending to server...';
        });

        if (_recordingPath != null) {
          await _sendAudioToServer();
        }
      }
    } catch (e) {
      setState(() {
        _serverResponse = 'Stop recording error: $e';
        _isRecording = false;
      });
    }
  }

  Future<void> _sendAudioToServer() async {
    try {
      String serverUrl = _runPodUrl;
      
      // Read the audio file
      final audioFile = File(_recordingPath!);
      final audioBytes = await audioFile.readAsBytes();
      final audioBase64 = base64Encode(audioBytes);

      // Prepare the request with real audio data
      final testData = {
        'call_id': 'test_${DateTime.now().millisecondsSinceEpoch}',
        'audio_data': audioBase64, // Real audio data as base64
        'audio_format': 'wav',
        'text': _testMessageController.text.isNotEmpty 
          ? _testMessageController.text 
          : 'Audio analysis from recorded file',
        'speaker': 'caller',
        'analysis_type': 'full', // Request full analysis
      };

      final response = await http.post(
        Uri.parse('$serverUrl/analyze_audio'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(testData),
      ).timeout(const Duration(seconds: 60)); // Longer timeout for audio processing

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        setState(() {
          _serverResponse = '''✅ Audio Analysis Results:
          
🎵 Audio File: ${_recordingPath!.split('/').last}
📏 File Size: ${(audioBytes.length / 1024).toStringAsFixed(1)} KB

🔍 Server Analysis:
${jsonEncode(responseData, toEncodable: (obj) => obj.toString())}

📊 Status: ${responseData['status'] ?? 'Unknown'}
⚡ Processing Time: ${responseData['processing_time'] ?? 'N/A'}s
🛡️ Scam Risk: ${responseData['scam_risk'] ?? 'Unknown'}
🎯 Confidence: ${responseData['confidence'] ?? 'N/A'}
💬 Transcription: ${responseData['transcription'] ?? 'N/A'}
😟 Emotion: ${responseData['emotion'] ?? 'N/A'}''';
        });
      } else {
        setState(() {
          _serverResponse = 'Audio analysis failed: ${response.statusCode}\nResponse: ${response.body}';
        });
      }
    } catch (e) {
      setState(() {
        _serverResponse = 'Audio sending error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('VoIP Dialer'),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: Icon(
                _isInitialized ? Icons.wifi : Icons.wifi_off,
                color: _isInitialized ? Colors.green : Colors.red,
              ),
              onPressed: null,
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.phone), text: 'Dialer'),
              Tab(icon: Icon(Icons.developer_mode), text: 'Server Test'),
            ],
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
          ),
        ),
        body: TabBarView(
          children: [
            // Dialer Tab
            _buildDialerTab(),
            // Server Test Tab
            _buildServerTestTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildDialerTab() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                'Your ID: $_currentUserId',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _phoneNumber.isEmpty ? 'Enter ID to call' : _phoneNumber,
                style: const TextStyle(fontSize: 32, letterSpacing: 2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        for (var row in [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['*', '0', '#'],
        ])
          Row(children: row.map(_buildDialButton).toList()),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.backspace),
              onPressed: _deleteDigit,
              iconSize: 32,
            ),
            const SizedBox(width: 40),
            ElevatedButton.icon(
              onPressed: (_phoneNumber.isNotEmpty && _isInitialized)
                  ? _callNumber
                  : null,
              icon: const Icon(Icons.call),
              label: const Text('Call'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                textStyle: const TextStyle(fontSize: 20),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (!_isInitialized)
          const CircularProgressIndicator()
        else
          const Text(
            'Ready to make calls',
            style: TextStyle(color: Colors.green),
          ),
      ],
    );
  }

  Widget _buildServerTestTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'RunPod Server Testing',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          
          // RunPod URL input
          TextField(
            controller: _runPodUrlController,
            decoration: InputDecoration(
              labelText: 'RunPod Server URL',
              hintText: 'http://your-runpod-url:8000',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.save),
                onPressed: () {
                  setState(() {
                    _runPodUrl = _runPodUrlController.text.isNotEmpty 
                      ? _runPodUrlController.text 
                      : 'http://your-runpod-url:8000';
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('RunPod URL updated: $_runPodUrl')),
                  );
                },
              ),
            ),
            onChanged: (value) {
              setState(() {
                _runPodUrl = value.isNotEmpty ? value : 'http://your-runpod-url:8000';
              });
            },
          ),
          const SizedBox(height: 10),
          
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Current RunPod URL: $_runPodUrl',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          
          // Test message input
          TextField(
            controller: _testMessageController,
            decoration: const InputDecoration(
              labelText: 'Test Message for Scam Detection',
              hintText: 'Enter a message to test scam detection...',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 20),
          
          // Test buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _testServerConnection,
                  icon: const Icon(Icons.health_and_safety),
                  label: const Text('Test Health'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _testScamDetection,
                  icon: const Icon(Icons.security),
                  label: const Text('Test Text'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          
          // Audio recording buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isRecording ? null : _startRecording,
                  icon: Icon(_isRecording ? Icons.mic : Icons.mic_none),
                  label: Text(_isRecording ? 'Recording...' : 'Start Recording'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isRecording ? Colors.red : Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isRecording ? _stopRecordingAndSend : null,
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop & Send'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Server response display
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Server Response:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 200),
                  child: Text(
                    _serverResponse.isEmpty 
                      ? 'No response yet. Tap a test button above to communicate with your RunPod server.'
                      : _serverResponse,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '📋 Instructions:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '1. Update the server URL in the code with your RunPod URL\n'
                  '2. Make sure your RunPod server is running\n'
                  '3. Test the health endpoint first\n'
                  '4. Try text-based scam detection\n'
                  '5. Record audio and test real audio analysis\n'
                  '6. Check the response format and data\n\n'
                  '🎤 Audio Recording:\n'
                  '• Tap "Start Recording" to record audio\n'
                  '• Speak your test message\n'
                  '• Tap "Stop & Send" to analyze the audio\n'
                  '• The app will send the recording to your server',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _voipService.disconnect();
    _testMessageController.dispose();
    _runPodUrlController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }
}

class CallingPage extends StatefulWidget {
  final String phoneNumber;
  final bool isIncomingCall;

  const CallingPage({
    super.key,
    required this.phoneNumber,
    required this.isIncomingCall,
  });

  @override
  State<CallingPage> createState() => _CallingPageState();
}

class _CallingPageState extends State<CallingPage> {
  final VoIPService _voipService = VoIPService();
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isConnected = false;
  
  // Auto recording for scam detection
  final AudioRecorder _autoRecorder = AudioRecorder();
  bool _isAutoRecording = false;
  Timer? _recordingTimer;
  int _chunkCounter = 0;
  String? _currentRecordingPath;

  @override
  void initState() {
    super.initState();
    _initializeRenderers();
    _setupVoIPCallbacks();

    if (!widget.isIncomingCall) {
      // Outgoing call
      _voipService.startCall(widget.phoneNumber);
    }
    
    // Start automatic recording for scam detection
    _startAutoRecording();
  }

  void _initializeRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  void _setupVoIPCallbacks() {
    _voipService.onLocalStream = (MediaStream stream) {
      setState(() {
        _localRenderer.srcObject = stream;
      });
    };

    _voipService.onRemoteStream = (MediaStream stream) {
      setState(() {
        _remoteRenderer.srcObject = stream;
        _isConnected = true;
      });
    };

    // Don't override onCallEnded here - let the main DialerPage handle it

    _voipService.onError = (String error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Call error: $error')));
      }
    };
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _voipService.toggleMicrophone();
    });
  }

  void _toggleSpeaker() {
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
      _voipService.toggleSpeaker(_isSpeakerOn);
    });
  }

  void _endCall() {
    _stopAutoRecording();
    _voipService.endCall();
    // Navigate back to the dialer page
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _startAutoRecording() async {
    try {
      // Check microphone permission
      if (await _autoRecorder.hasPermission()) {
        await _startNewRecordingChunk();
        
        // Set up timer to record in 10-second chunks
        _recordingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
          _processCurrentChunkAndStartNew();
        });
        
        setState(() {
          _isAutoRecording = true;
        });
        
        print('🎤 Auto-recording started for scam detection');
      } else {
        print('❌ Microphone permission not granted for auto-recording');
      }
    } catch (e) {
      print('Auto-recording setup error: $e');
    }
  }

  Future<void> _startNewRecordingChunk() async {
    try {
      _chunkCounter++;
      _currentRecordingPath = '/tmp/call_chunk_${widget.phoneNumber}_$_chunkCounter.wav';
      
      await _autoRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          bitRate: 16000,
          sampleRate: 16000,
        ),
        path: _currentRecordingPath!,
      );
      
      print('📹 Started recording chunk $_chunkCounter');
    } catch (e) {
      print('Error starting recording chunk: $e');
    }
  }

  Future<void> _processCurrentChunkAndStartNew() async {
    try {
      if (_isAutoRecording && _currentRecordingPath != null) {
        // Stop current recording
        final completedPath = await _autoRecorder.stop();
        
        if (completedPath != null) {
          // Send completed chunk to server in background
          _sendAudioChunkToServer(completedPath, _chunkCounter);
        }
        
        // Start new recording chunk
        await _startNewRecordingChunk();
      }
    } catch (e) {
      print('Error processing recording chunk: $e');
    }
  }

  Future<void> _sendAudioChunkToServer(String audioPath, int chunkNumber) async {
    try {
      // Send to RunPod endpoint - get URL from main page
      String serverUrl = 'http://your-runpod-url:8000'; // TODO: Make this configurable
      
      final audioFile = File(audioPath);
      if (!await audioFile.exists()) return;
      
      final audioBytes = await audioFile.readAsBytes();
      final audioBase64 = base64Encode(audioBytes);
      
      final requestData = {
        'call_id': '${widget.phoneNumber}_${DateTime.now().millisecondsSinceEpoch}',
        'chunk_number': chunkNumber,
        'audio_data': audioBase64,
        'audio_format': 'wav',
        'speaker': widget.isIncomingCall ? 'caller' : 'callee',
        'analysis_type': 'realtime',
        'timestamp': DateTime.now().toIso8601String(),
      };

      final response = await http.post(
        Uri.parse('$serverUrl/analyze_audio'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestData),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        // Check for scam alerts
        if (responseData['scam_risk'] != null) {
          final scamRisk = responseData['scam_risk'].toString().toLowerCase();
          
          if (scamRisk == 'high' || scamRisk == 'medium') {
            // Trigger scam alert in the UI
            if (mounted) {
              _showRealTimeScamAlert(responseData);
            }
          }
        }
        
        print('✅ Chunk $chunkNumber analyzed - Risk: ${responseData['scam_risk'] ?? 'None'}');
      } else {
        print('❌ Chunk $chunkNumber analysis failed: ${response.statusCode}');
      }
      
      // Clean up the audio file
      try {
        await audioFile.delete();
      } catch (e) {
        print('Warning: Could not delete audio file: $e');
      }
      
    } catch (e) {
      print('Error sending audio chunk $chunkNumber: $e');
    }
  }

  void _showRealTimeScamAlert(Map<String, dynamic> analysisData) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final scamRisk = analysisData['scam_risk']?.toString().toUpperCase() ?? 'UNKNOWN';
        final isHigh = scamRisk == 'HIGH';
        
        return AlertDialog(
          backgroundColor: isHigh ? Colors.red[50] : Colors.orange[50],
          title: Row(
            children: [
              Icon(
                isHigh ? Icons.dangerous : Icons.warning,
                color: isHigh ? Colors.red : Colors.orange,
                size: 28,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isHigh ? 'SCAM DETECTED!' : 'SUSPICIOUS ACTIVITY',
                  style: TextStyle(
                    color: isHigh ? Colors.red[800] : Colors.orange[800],
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Real-time analysis detected potential scam activity in this call.',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Text('Risk Level: $scamRisk'),
              if (analysisData['confidence'] != null)
                Text('Confidence: ${analysisData['confidence']}%'),
              if (analysisData['transcription'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Transcript: "${analysisData['transcription']}"',
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Continue Call'),
            ),
            if (isHigh)
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _endCall(); // End call for high risk
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('End Call'),
              ),
          ],
        );
      },
    );
  }

  void _stopAutoRecording() {
    try {
      _recordingTimer?.cancel();
      _autoRecorder.stop();
      setState(() {
        _isAutoRecording = false;
      });
      print('🛑 Auto-recording stopped');
    } catch (e) {
      print('Error stopping auto-recording: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    widget.phoneNumber,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isConnected
                        ? 'Connected'
                        : (widget.isIncomingCall
                              ? 'Incoming call...'
                              : 'Calling...'),
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isAutoRecording ? Icons.fiber_manual_record : Icons.stop_circle,
                        color: _isAutoRecording ? Colors.red : Colors.grey,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isAutoRecording 
                          ? 'Live Recording • AI Scam Analysis' 
                          : 'Recording Stopped',
                        style: TextStyle(
                          color: _isAutoRecording ? Colors.red : Colors.grey,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Video area
            Expanded(
              child: Stack(
                children: [
                  // Remote video (full screen)
                  if (_remoteRenderer.srcObject != null)
                    RTCVideoView(_remoteRenderer, mirror: false)
                  else
                    Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: Colors.grey[900],
                      child: const Center(
                        child: Icon(
                          Icons.person,
                          size: 100,
                          color: Colors.white54,
                        ),
                      ),
                    ),

                  // Local video (small overlay)
                  if (_localRenderer.srcObject != null)
                    Positioned(
                      top: 20,
                      right: 20,
                      child: Container(
                        width: 120,
                        height: 160,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: RTCVideoView(_localRenderer, mirror: true),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Controls
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mute button
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: _isMuted ? Colors.red : Colors.white24,
                    child: IconButton(
                      icon: Icon(
                        _isMuted ? Icons.mic_off : Icons.mic,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: _toggleMute,
                    ),
                  ),

                  // End call button
                  CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.red,
                    child: IconButton(
                      icon: const Icon(
                        Icons.call_end,
                        color: Colors.white,
                        size: 32,
                      ),
                      onPressed: _endCall,
                    ),
                  ),

                  // Speaker button
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: _isSpeakerOn
                        ? Colors.blue
                        : Colors.white24,
                    child: IconButton(
                      icon: Icon(
                        _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: _toggleSpeaker,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _stopAutoRecording();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _autoRecorder.dispose();
    super.dispose();
  }
}

// Incoming Call Page - Full screen call acceptance interface
class IncomingCallPage extends StatefulWidget {
  final String callerName;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const IncomingCallPage({
    super.key,
    required this.callerName,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<IncomingCallPage> createState() => _IncomingCallPageState();
}

class _IncomingCallPageState extends State<IncomingCallPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Column(
          children: [
            // Top section with caller info
            Expanded(
              flex: 3,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Incoming Call',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Animated avatar
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.blue.shade400,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.3),
                                blurRadius: 20,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.person,
                            size: 80,
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 30),

                  // Caller name
                  Text(
                    widget.callerName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w300,
                    ),
                  ),

                  const SizedBox(height: 10),

                  const Text(
                    'VoIP Call',
                    style: TextStyle(color: Colors.white60, fontSize: 16),
                  ),
                ],
              ),
            ),

            // Bottom section with action buttons
            Expanded(
              flex: 1,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Reject button
                  GestureDetector(
                    onTap: widget.onReject,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.call_end,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),

                  // Accept button
                  GestureDetector(
                    onTap: widget.onAccept,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.green,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.call,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}
