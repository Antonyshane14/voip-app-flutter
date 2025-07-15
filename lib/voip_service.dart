import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:async';

class ScamAlert {
  final String type;
  final String level;
  final String message;
  final String details;
  final List<String> recommendations;
  final DateTime timestamp;

  ScamAlert({
    required this.type,
    required this.level,
    required this.message,
    required this.details,
    required this.recommendations,
    required this.timestamp,
  });

  factory ScamAlert.fromJson(Map<String, dynamic> json) {
    return ScamAlert(
      type: json['type'] ?? '',
      level: json['level'] ?? '',
      message: json['message'] ?? '',
      details: json['details'] ?? '',
      recommendations: List<String>.from(json['recommendations'] ?? []),
      timestamp: DateTime.now(),
    );
  }
}

class VoIPService {
  static final VoIPService _instance = VoIPService._internal();
  factory VoIPService() => _instance;
  VoIPService._internal();

  // WebRTC components
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  // Socket.IO for signaling
  IO.Socket? _socket;
  
  // Scam detection components
  IO.Socket? _scamSocket;
  String? _bridgeServerUrl;
  Timer? _chunkUploadTimer;
  int _chunkCounter = 0;
  String? _currentCallId;
  bool _isIncomingCall = false; // Track if this is incoming call (potential victim)
  String? _currentUserId;

  // Recording components
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  String? _currentRecordingPath;
  
  // Call state variables
  Map<String, dynamic>? _pendingOffer;
  String? _incomingCallerId;

  // Configuration
  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ],
  };

  // Callbacks
  Function(MediaStream)? onLocalStream;
  Function(MediaStream)? onRemoteStream;
  Function(String)? onIncomingCall;
  Function()? onCallEnded;
  Function(String)? onError;
  Function(ScamAlert)? onScamAlert; // New callback for scam alerts

  bool get isConnected => _socket?.connected ?? false;
  bool get isInCall => _peerConnection != null;

  // Initialize the VoIP service
  Future<void> initialize({
    required String serverUrl,
    required String userId,
  }) async {
    try {
      // Store current user ID
      _currentUserId = userId;
      
      // Connect to signaling server
      _socket = IO.io(serverUrl, <String, dynamic>{
        'transports': ['websocket'],
        'query': {'userId': userId},
      });

      // Initialize scam detection bridge
      await _initializeScamDetection(serverUrl);

      _socket!.onConnect((_) {
        print('✅ Connected to signaling server');
        // Register user on connection
        _socket!.emit('register', {'userId': userId});
      });

      _socket!.onDisconnect((_) {
        print('❌ Disconnected from signaling server');
      });

      // Handle registration confirmation
      _socket!.on('registered', (data) {
        print('👤 Registered as user: ${data['userId']}');
      });

      // Handle incoming calls
      _socket!.on('incoming-call', _handleIncomingCall);
      
      // Handle call accepted
      _socket!.on('call-accepted', _handleCallAccepted);
      
      // Handle call rejected
      _socket!.on('call-rejected', _handleCallRejected);
      
      // Handle ICE candidates
      _socket!.on('ice-candidate', _handleIceCandidate);
      
      // Handle call ended
      _socket!.on('call-ended', _handleCallEnded);
      
      // Handle call failed
      _socket!.on('call-failed', (data) {
        onError?.call('Call failed: ${data['message']}');
      });

      // Handle user updates
      _socket!.on('users-update', (data) {
        print('👥 Active users: ${data['users']}');
      });

      _socket!.connect();
    } catch (e) {
      onError?.call('Failed to initialize VoIP service: $e');
    }
  }

  // Start a call
  Future<void> startCall(String targetUserId) async {
    try {
      await _createPeerConnection();
      await _getUserMedia();

      if (_localStream != null) {
        _localStream!.getTracks().forEach((track) {
          _peerConnection!.addTrack(track, _localStream!);
        });
        onLocalStream?.call(_localStream!);
      }

      // Create and send offer
      RTCSessionDescription offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      // Start recording when call starts
      await startRecording();
      
      // Mark as outgoing call (caller = potential scammer, no alerts needed)
      _isIncomingCall = false;
      
      // Start scam detection (but won't send alerts for outgoing calls)
      final callId = 'call_${DateTime.now().millisecondsSinceEpoch}';
      _startScamDetection(callId, targetUserId);

      _socket!.emit('call-user', {
        'userToCall': targetUserId,
        'from': _currentUserId,
        'offer': offer.toMap(),
      });
    } catch (e) {
      onError?.call('Failed to start call: $e');
    }
  }

  // Answer an incoming call
  Future<void> answerCall(Map<String, dynamic> offer) async {
    try {
      await _createPeerConnection();
      await _getUserMedia();

      if (_localStream != null) {
        _localStream!.getTracks().forEach((track) {
          _peerConnection!.addTrack(track, _localStream!);
        });
        onLocalStream?.call(_localStream!);
      }

      // Set remote description
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(offer['sdp'], offer['type']),
      );

      // Create and send answer
      RTCSessionDescription answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      // Start recording when answering call
      await startRecording();

      _socket!.emit('accept-call', {
        'to': offer['callerId'],
        'answer': answer.toMap(),
      });
    } catch (e) {
      onError?.call('Failed to answer call: $e');
    }
  }

  // End the current call
  Future<void> endCall() async {
    try {
      // Stop recording when call ends
      await stopRecording();
      
      // Stop scam detection
      _stopScamDetection();

      _socket!.emit('end-call', {
        'to': null, // Will be handled by server
      });
      await _cleanupCall();
      onCallEnded?.call();
    } catch (e) {
      onError?.call('Failed to end call: $e');
    }
  }

  // Create peer connection
  Future<void> _createPeerConnection() async {
    _peerConnection = await createPeerConnection(_iceServers);

    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      _socket!.emit('ice-candidate', {
        'to': _incomingCallerId, // Send to the other peer
        'candidate': candidate.toMap(),
      });
    };

    _peerConnection!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        onRemoteStream?.call(_remoteStream!);
      }
    };

    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      print('Connection state: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _cleanupCall();
        onCallEnded?.call();
      }
    };
  }

  // Get user media (microphone and camera)
  Future<void> _getUserMedia() async {
    final Map<String, dynamic> constraints = {
      'audio': true,
      'video': false, // Set to true if you want video calls
    };

    _localStream = await navigator.mediaDevices.getUserMedia(constraints);
  }

  // Handle incoming call
  void _handleIncomingCall(dynamic data) {
    print('📞 Incoming call from: ${data['from']}');
    
    // Mark as incoming call (potential victim, needs alerts)
    _isIncomingCall = true;
    
    // Store the offer and caller info for later use
    _pendingOffer = data['offer'];
    _incomingCallerId = data['callerId'];
    
    onIncomingCall?.call(data['from']);
  }

  // Handle call accepted (when we made a call)
  void _handleCallAccepted(dynamic data) async {
    print('✅ Call accepted, setting up connection...');
    try {
      // Set the remote description (answer)
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(data['answer']['sdp'], data['answer']['type']),
      );
    } catch (e) {
      onError?.call('Failed to handle call accepted: $e');
    }
  }

  // Handle call rejected
  void _handleCallRejected(dynamic data) {
    print('❌ Call was rejected');
    onError?.call('Call was rejected by the other party');
    endCall();
  }

  // Handle ICE candidate
  void _handleIceCandidate(dynamic data) async {
    final candidate = data['candidate'];
    await _peerConnection?.addCandidate(
      RTCIceCandidate(
        candidate['candidate'],
        candidate['sdpMid'],
        candidate['sdpMLineIndex'],
      ),
    );
  }

  // Handle call ended
  void _handleCallEnded(dynamic data) {
    print('📵 Call ended by remote party');
    _cleanupCall();
    onCallEnded?.call();
  }

  // Accept pending call
  Future<void> acceptIncomingCall() async {
    if (_pendingOffer != null) {
      // Mark as incoming call (receiver = potential victim, needs alerts)
      _isIncomingCall = true;
      
      // Start recording and scam detection for incoming call
      await startRecording();
      final callId = 'call_${DateTime.now().millisecondsSinceEpoch}';
      _startScamDetection(callId, 'incoming_caller');
      
      await answerCall(_pendingOffer!);
      _pendingOffer = null;
    }
  }

  // Reject pending call
  void rejectIncomingCall() {
    _socket!.emit('reject-call', {
      'to': _incomingCallerId,
    });
    _pendingOffer = null;
    _incomingCallerId = null;
  }

  // Cleanup call resources
  Future<void> _cleanupCall() async {
    // Stop recording if still active
    if (_isRecording) {
      await stopRecording();
    }

    await _localStream?.dispose();
    await _remoteStream?.dispose();
    await _peerConnection?.close();

    _localStream = null;
    _remoteStream = null;
    _peerConnection = null;
  }

  // Toggle microphone
  void toggleMicrophone() {
    if (_localStream != null) {
      bool enabled = _localStream!.getAudioTracks()[0].enabled;
      _localStream!.getAudioTracks()[0].enabled = !enabled;
    }
  }

  // Toggle speaker
  void toggleSpeaker(bool enabled) {
    Helper.setSpeakerphoneOn(enabled);
  }

  // Start recording the call
  Future<void> startRecording() async {
    if (_isRecording) return;

    try {
      // Check if recorder has permission
      if (await _recorder.hasPermission()) {
        // Get a local directory for storing recordings
        Directory recordingsDir;

        if (Platform.isAndroid || Platform.isIOS) {
          // For mobile: use app documents directory
          final directory = await getApplicationDocumentsDirectory();
          recordingsDir = Directory('${directory.path}/voip_recordings');
        } else {
          // For desktop: use user's home directory
          final homeDir =
              Platform.environment['HOME'] ??
              Platform.environment['USERPROFILE'] ??
              '/tmp';
          recordingsDir = Directory('$homeDir/VoIP_Recordings');
        }

        // Create directory if it doesn't exist
        if (!await recordingsDir.exists()) {
          await recordingsDir.create(recursive: true);
        }

        final timestamp = DateTime.now();
        final fileName =
            'call_${timestamp.year}${timestamp.month.toString().padLeft(2, '0')}${timestamp.day.toString().padLeft(2, '0')}_${timestamp.hour.toString().padLeft(2, '0')}${timestamp.minute.toString().padLeft(2, '0')}.wav';
        _currentRecordingPath = '${recordingsDir.path}/$fileName';

        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: _currentRecordingPath!,
        );

        _isRecording = true;

        print('🎙️ Recording started locally: $_currentRecordingPath');
        print('📁 Recordings folder: ${recordingsDir.path}');
      }
    } catch (e) {
      print('Failed to start recording: $e');
    }
  }

  // Stop recording the call
  Future<void> stopRecording() async {
    if (!_isRecording) return;

    try {
      await _recorder.stop();
      _isRecording = false;

      if (_currentRecordingPath != null) {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          final fileSizeBytes = await file.length();
          final fileSizeMB = (fileSizeBytes / (1024 * 1024)).toStringAsFixed(2);
          print('✅ Recording saved locally: $_currentRecordingPath');
          print('📊 File size: ${fileSizeMB}MB');
          print(
            '🔍 You can find your recordings in the VoIP_Recordings folder',
          );
        }
      }

      print('Recording stopped and saved locally');
    } catch (e) {
      print('Failed to stop recording: $e');
    }
  }

  // Disconnect from service
  Future<void> disconnect() async {
    await _cleanupCall();
    _socket?.disconnect();
    _socket = null;
    
    // Cleanup scam detection
    _chunkUploadTimer?.cancel();
    _scamSocket?.disconnect();
    _scamSocket = null;
  }

  // Initialize scam detection bridge connection
  Future<void> _initializeScamDetection(String serverUrl) async {
    try {
      // Extract base URL and use port 3001 for bridge service
      final uri = Uri.parse(serverUrl);
      _bridgeServerUrl = '${uri.scheme}://${uri.host}:3001';
      
      // Connect to bridge server for real-time notifications
      _scamSocket = IO.io(_bridgeServerUrl!, <String, dynamic>{
        'transports': ['websocket'],
      });

      _scamSocket!.onConnect((_) {
        print('🌉 Connected to scam detection bridge');
      });

      _scamSocket!.on('scam-alert', (data) {
        _handleScamAlert(data);
      });

      _scamSocket!.on('registration-confirmed', (data) {
        print('📞 Call registered for scam monitoring: ${data['call_id']}');
      });

      print('🔍 Scam detection bridge initialized: $_bridgeServerUrl');
    } catch (e) {
      print('⚠️ Failed to initialize scam detection: $e');
    }
  }

  // Handle incoming scam alerts
  void _handleScamAlert(dynamic data) {
    try {
      // Only process alerts for incoming calls (potential victims)
      if (!_isIncomingCall) {
        print('🔇 Scam alert ignored - outgoing call (caller role)');
        return;
      }

      final alert = ScamAlert.fromJson(Map<String, dynamic>.from(data));
      print('🚨 SCAM ALERT (INCOMING CALL): ${alert.level} - ${alert.message}');
      
      // Notify the UI through callback (only for potential victims)
      onScamAlert?.call(alert);
    } catch (e) {
      print('Error processing scam alert: $e');
    }
  }

  // Start scam detection for a call
  void _startScamDetection(String callId, String userId) {
    _currentCallId = callId;
    _chunkCounter = 0;
    
    // Register call for notifications with role information
    _scamSocket?.emit('register-call', {
      'call_id': callId,
      'user_id': _currentUserId,
      'is_incoming_call': _isIncomingCall, // Tell bridge about call direction
      'target_user': userId,
    });

    // Start periodic chunk upload (every 10 seconds)
    _chunkUploadTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _uploadRecordingChunk();
    });
    
    print('🔍 Started scam detection for call: $callId');
  }

  // Stop scam detection for a call
  void _stopScamDetection() {
    _chunkUploadTimer?.cancel();
    
    if (_currentCallId != null) {
      _scamSocket?.emit('unregister-call', {
        'call_id': _currentCallId,
      });
    }
    
    _currentCallId = null;
    _chunkCounter = 0;
    print('🔍 Stopped scam detection');
  }

  // Upload recording chunk for analysis
  Future<void> _uploadRecordingChunk() async {
    if (_currentRecordingPath == null || _bridgeServerUrl == null || _currentCallId == null) {
      return;
    }

    try {
      final file = File(_currentRecordingPath!);
      if (!await file.exists()) return;

      _chunkCounter++;
      
      // Create a temporary chunk file (last 10 seconds of recording)
      final chunkPath = await _createRecordingChunk();
      if (chunkPath == null) return;

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_bridgeServerUrl/analyze-call-chunk'),
      );

      request.files.add(
        await http.MultipartFile.fromPath('audio', chunkPath),
      );

      request.fields['call_id'] = _currentCallId!;
      request.fields['chunk_number'] = _chunkCounter.toString();
      request.fields['user_id'] = _currentUserId ?? 'unknown_user';
      request.fields['is_incoming_call'] = _isIncomingCall.toString();
      request.fields['user_role'] = _isIncomingCall ? 'receiver' : 'caller';

      final response = await request.send();
      
      if (response.statusCode == 200) {
        print('📤 Uploaded chunk $_chunkCounter for analysis');
      } else {
        print('❌ Failed to upload chunk: ${response.statusCode}');
      }

      // Cleanup temporary chunk file
      final chunkFile = File(chunkPath);
      if (await chunkFile.exists()) {
        await chunkFile.delete();
      }

    } catch (e) {
      print('Error uploading recording chunk: $e');
    }
  }

  // Create a 10-second chunk from the current recording
  Future<String?> _createRecordingChunk() async {
    // For now, return the current recording path
    // In a real implementation, you'd extract the last 10 seconds
    return _currentRecordingPath;
  }
}
