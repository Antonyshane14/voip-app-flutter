# VoIP Scam Detection Integration 🚨

Real-time scam detection system for VoIP calls using AI analysis.

## Architecture Overview

```
VoIP Flutter App ←→ Node.js Bridge ←→ Python AI API
                    (Port 3001)     (Port 8000)
```

### Components:

1. **Python AI API** (`main.py`) - Advanced scam analysis
   - Whisper transcription
   - AI voice detection  
   - Speaker diarization
   - Emotion detection
   - LLM-based scam analysis

2. **Node.js Bridge** (`bridge_server.js`) - VoIP integration
   - Receives audio chunks from Flutter app
   - Forwards to Python API for analysis
   - Real-time WebSocket notifications
   - Risk level assessment

3. **Flutter VoIP App** - User interface
   - Records call audio in 10-second chunks
   - Sends to bridge for analysis
   - Shows real-time scam alerts
   - Local audio storage

## RunPod Deployment

### 1. Upload Files to RunPod
```bash
# Upload these files to your RunPod instance:
- main.py (Python scam detection API)
- config.py (Python configuration)
- modules/ (all Python modules)
- requirements_scam.txt (Python dependencies)
- scam_detection_bridge/ (Node.js bridge service)
- runpod_deploy.sh (deployment script)
```

### 2. Run Deployment Script
```bash
cd /workspace
chmod +x runpod_deploy.sh
./runpod_deploy.sh
```

### 3. Configure Your VoIP App
Update your Flutter app's bridge URL:

```dart
// For mobile data (use RunPod external IP)
_bridgeServerUrl = 'http://YOUR_RUNPOD_IP:3001';

// For local network (if running locally)
_bridgeServerUrl = 'http://192.168.x.x:3001';
```

## How It Works

### During a VoIP Call:

1. **Call Starts** 📞
   - Flutter app starts recording
   - Registers call with bridge service for notifications
   - Generates unique call ID

2. **Real-time Analysis** 🔍
   - Every 10 seconds, audio chunk sent to bridge
   - Bridge forwards to Python API for AI analysis
   - Results processed for scam indicators

3. **Smart Alerts** 🚨
   - **HIGH RISK**: Immediate popup with "End Call" option
   - **MEDIUM RISK**: Caution warning with recommendations
   - **LOW RISK**: No interruption, silent monitoring

### Scam Detection Features:

- **Transcription Analysis**: Detects scam keywords and phrases
- **Voice Analysis**: Identifies AI-generated voices
- **Speaker Patterns**: Analyzes speaker changes and emotions
- **Background Noise**: Detects call center environments
- **LLM Analysis**: Advanced pattern recognition

## API Endpoints

### Bridge Service (Port 3001)

- `POST /analyze-call-chunk` - Send audio for analysis
- `GET /call-summary/:call_id` - Get call analysis summary  
- `GET /health` - Service health check
- `GET /test-python-api` - Test Python API connectivity

### Python API (Port 8000)

- `POST /analyze-audio` - Analyze audio chunk
- `GET /call-summary/:call_id` - Get detailed analysis
- `GET /health` - API health check

## Example Alert Messages

### High Risk Alert:
```
🚨 SCAM ALERT: High risk detected! Be very cautious.
Detected 3 high-risk indicators

Recommendations:
• Do not share personal information
• Do not make any payments  
• Hang up and verify independently
```

### Medium Risk Alert:
```
⚠️ CAUTION: Potential scam indicators detected
Detected suspicious patterns in conversation

Recommendations:
• Be cautious with personal information
• Verify caller identity independently
```

## Testing the System

### 1. Health Check
```bash
/workspace/health_check.sh
```

### 2. Test Analysis
```bash
cd /workspace/scam_detection_bridge
node test_client.js
```

### 3. Check Logs
```bash
# Python API logs
journalctl -u scam-api.service -f

# Bridge service logs  
journalctl -u scam-bridge.service -f
```

## Troubleshooting

### Common Issues:

1. **Bridge can't connect to Python API**
   ```bash
   systemctl restart scam-api.service
   curl http://localhost:8000/health
   ```

2. **Flutter app can't reach bridge**
   - Check RunPod external IP: `curl ifconfig.me`
   - Update bridge URL in Flutter app
   - Ensure port 3001 is accessible

3. **Analysis taking too long**
   - Check Python API logs for errors
   - Verify Hugging Face token is set
   - Monitor CPU/memory usage

### Configuration Files:

- **Python config**: `config.py`
- **Node.js config**: Environment variables
- **Flutter config**: Bridge URL in `voip_service.dart`

## Performance Notes

- **Analysis Time**: ~5-15 seconds per 10-second chunk
- **Memory Usage**: ~2-4GB for Python models
- **CPU Usage**: High during analysis, idle between chunks
- **Network**: Minimal bandwidth (~100KB per chunk)

## Security

- All audio processing happens on your RunPod instance
- No audio data sent to external services
- Local storage for call recordings
- Real-time analysis without data retention

---

## Quick Start Checklist

- [ ] Deploy to RunPod using `runpod_deploy.sh`
- [ ] Get RunPod external IP: `curl ifconfig.me`
- [ ] Update Flutter app bridge URL
- [ ] Test with health check script
- [ ] Make a test call to verify alerts
- [ ] Monitor logs for any issues

🎉 **Your VoIP calls are now protected with real-time scam detection!**
