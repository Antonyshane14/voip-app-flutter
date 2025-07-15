import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:record/record.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';

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
  
  // Recording components
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  String? _currentRecordingPath;
  Timer? _uploadTimer;
  String? _serverUrl;
  
  // Configuration
  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ]
  };

  // Callbacks
  Function(MediaStream)? onLocalStream;
  Function(MediaStream)? onRemoteStream;
  Function(String)? onIncomingCall;
  Function()? onCallEnded;
  Function(String)? onError;

  bool get isConnected => _socket?.connected ?? false;
  bool get isInCall => _peerConnection != null;

  // Initialize the VoIP service
  Future<void> initialize({
    required String serverUrl,
    required String userId,
  }) async {
    try {
      // Store server URL for recording uploads
      _serverUrl = serverUrl;
      
      // Connect to signaling server
      _socket = IO.io(serverUrl, <String, dynamic>{
        'transports': ['websocket'],
        'query': {'userId': userId},
      });

      _socket!.onConnect((_) {
        print('Connected to signaling server');
      });

      _socket!.onDisconnect((_) {
        print('Disconnected from signaling server');
      });

      // Handle signaling messages
      _socket!.on('offer', _handleOffer);
      _socket!.on('answer', _handleAnswer);
      _socket!.on('ice-candidate', _handleIceCandidate);
      _socket!.on('call-request', _handleIncomingCall);
      _socket!.on('call-ended', _handleCallEnded);

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
      
      _socket!.emit('call-request', {
        'target': targetUserId,
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
      
      _socket!.emit('answer', {
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
      
      _socket!.emit('end-call', {});
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

  // Handle incoming offer
  void _handleOffer(dynamic data) {
    final offer = data['offer'];
    final fromUser = data['from'];
    onIncomingCall?.call(fromUser);
    // Store offer for when user accepts
    _pendingOffer = offer;
  }

  Map<String, dynamic>? _pendingOffer;

  // Handle answer
  void _handleAnswer(dynamic data) async {
    final answer = data['answer'];
    await _peerConnection?.setRemoteDescription(
      RTCSessionDescription(answer['sdp'], answer['type']),
    );
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

  // Handle incoming call
  void _handleIncomingCall(dynamic data) {
    final fromUser = data['from'];
    final offer = data['offer'];
    _pendingOffer = offer;
    onIncomingCall?.call(fromUser);
  }

  // Handle call ended
  void _handleCallEnded(dynamic data) {
    _cleanupCall();
    onCallEnded?.call();
  }

  // Accept pending call
  Future<void> acceptIncomingCall() async {
    if (_pendingOffer != null) {
      await answerCall(_pendingOffer!);
      _pendingOffer = null;
    }
  }

  // Reject pending call
  void rejectIncomingCall() {
    _socket!.emit('reject-call', {});
    _pendingOffer = null;
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
        // Get the app's documents directory
        final directory = await getApplicationDocumentsDirectory();
        _currentRecordingPath = '${directory.path}/call_recording_${DateTime.now().millisecondsSinceEpoch}.wav';
        
        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: _currentRecordingPath!,
        );
        
        _isRecording = true;
        
        // Start periodic upload of recording chunks (every 10 seconds for scam analysis)
        _uploadTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
          _uploadRecordingChunk();
        });
        
        print('Recording started: $_currentRecordingPath');
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
      _uploadTimer?.cancel();
      _uploadTimer = null;
      
      // Upload the final recording chunk
      await _uploadRecordingChunk();
      
      print('Recording stopped');
    } catch (e) {
      print('Failed to stop recording: $e');
    }
  }

  // Upload recording chunk to server
  Future<void> _uploadRecordingChunk() async {
    if (_currentRecordingPath == null || _serverUrl == null) return;
    
    try {
      final file = File(_currentRecordingPath!);
      if (!await file.exists()) return;
      
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return;
      
      // Upload to server
      final uri = Uri.parse('$_serverUrl/upload-recording');
      final request = http.MultipartRequest('POST', uri);
      
      request.files.add(
        http.MultipartFile.fromBytes(
          'recording',
          bytes,
          filename: 'call_recording_${DateTime.now().millisecondsSinceEpoch}.wav',
        ),
      );
      
      request.fields['timestamp'] = DateTime.now().toIso8601String();
      request.fields['type'] = 'call_recording_chunk';
      request.fields['analysis_priority'] = 'scam_detection';
      request.fields['chunk_interval'] = '10_seconds';
      request.fields['call_duration'] = '${DateTime.now().millisecondsSinceEpoch}';
      
      final response = await request.send();
      if (response.statusCode == 200) {
        print('Recording chunk uploaded for scam analysis');
      } else {
        print('Failed to upload recording chunk: ${response.statusCode}');
      }
      
    } catch (e) {
      print('Error uploading recording chunk: $e');
    }
  }

  // Disconnect from service
  Future<void> disconnect() async {
    await _cleanupCall();
    _socket?.disconnect();
    _socket = null;
  }
}
