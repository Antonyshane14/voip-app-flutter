const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const cors = require('cors');
const multer = require('multer');
const axios = require('axios');
const FormData = require('form-data');
const fs = require('fs');
const path = require('path');

const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
});

app.use(cors());
app.use(express.json());

// Store active call analysis sessions
const activeCalls = new Map();
const callSockets = new Map(); // Map call_id to socket_id for notifications

// Configure multer for temporary file storage
const upload = multer({
  dest: './temp_recordings/',
  limits: {
    fileSize: 10 * 1024 * 1024 // 10MB limit
  }
});

// Ensure temp directory exists
if (!fs.existsSync('./temp_recordings')) {
  fs.mkdirSync('./temp_recordings', { recursive: true });
}

// Python API configuration
const PYTHON_API_URL = process.env.PYTHON_API_URL || 'http://localhost:8000';

console.log(`🐍 Python API URL: ${PYTHON_API_URL}`);

// Main endpoint: Receive audio from VoIP app and forward to Python
app.post('/analyze-call-chunk', upload.single('audio'), async (req, res) => {
  try {
    const { call_id, chunk_number, user_id } = req.body;
    
    if (!req.file) {
      return res.status(400).json({ error: 'No audio file provided' });
    }

    console.log(`📞 Processing call chunk: ${call_id} #${chunk_number}`);

    // Create FormData to send to Python API
    const formData = new FormData();
    formData.append('file', fs.createReadStream(req.file.path), {
      filename: `${call_id}_${chunk_number}.wav`,
      contentType: 'audio/wav'
    });
    formData.append('call_id', call_id);
    formData.append('chunk_number', chunk_number);

    // Forward to Python API
    const pythonResponse = await axios.post(
      `${PYTHON_API_URL}/analyze-audio`,
      formData,
      {
        headers: {
          ...formData.getHeaders(),
          'Content-Type': 'multipart/form-data'
        },
        timeout: 30000 // 30 second timeout
      }
    );

    const analysisResult = pythonResponse.data;
    
    // Store analysis result
    if (!activeCalls.has(call_id)) {
      activeCalls.set(call_id, {
        user_id,
        chunks: [],
        scam_indicators: [],
        overall_risk: 'low'
      });
    }

    const callData = activeCalls.get(call_id);
    callData.chunks.push({
      chunk_number,
      timestamp: Date.now(),
      analysis: analysisResult
    });

    // Extract scam analysis from LLM
    const scamAnalysis = analysisResult.results?.scam_analysis;
    let riskLevel = 'low';
    let notification = null;

    if (scamAnalysis) {
      // Parse LLM response for scam indicators
      const analysisText = JSON.stringify(scamAnalysis).toLowerCase();
      
      // Check for high-risk indicators
      const highRiskKeywords = [
        'scam', 'fraud', 'suspicious', 'urgent', 'money', 'transfer',
        'bank details', 'personal information', 'verify account',
        'limited time', 'act now', 'confirm payment'
      ];

      const mediumRiskKeywords = [
        'unusual', 'unexpected', 'verify', 'confirm', 'update',
        'security', 'account', 'payment', 'prize', 'winner'
      ];

      const highRiskCount = highRiskKeywords.filter(keyword => 
        analysisText.includes(keyword)
      ).length;

      const mediumRiskCount = mediumRiskKeywords.filter(keyword => 
        analysisText.includes(keyword)
      ).length;

      // Determine risk level
      if (highRiskCount >= 2) {
        riskLevel = 'high';
        notification = {
          type: 'SCAM_ALERT',
          level: 'HIGH',
          message: '🚨 SCAM ALERT: High risk detected! Be very cautious.',
          details: `Detected ${highRiskCount} high-risk indicators`,
          recommendations: [
            'Do not share personal information',
            'Do not make any payments',
            'Hang up and verify independently'
          ]
        };
      } else if (highRiskCount >= 1 || mediumRiskCount >= 3) {
        riskLevel = 'medium';
        notification = {
          type: 'CAUTION',
          level: 'MEDIUM',
          message: '⚠️ CAUTION: Potential scam indicators detected',
          details: `Detected suspicious patterns in conversation`,
          recommendations: [
            'Be cautious with personal information',
            'Verify caller identity independently'
          ]
        };
      }

      // Update overall call risk
      callData.overall_risk = riskLevel;
      
      if (notification) {
        callData.scam_indicators.push({
          chunk_number,
          risk_level: riskLevel,
          notification,
          timestamp: Date.now()
        });
      }
    }

    // Send real-time notification to VoIP app if risk detected
    if (notification && callSockets.has(call_id)) {
      const socketId = callSockets.get(call_id);
      io.to(socketId).emit('scam-alert', {
        call_id,
        chunk_number,
        ...notification
      });
      console.log(`🚨 Sent ${riskLevel} risk alert for call ${call_id}`);
    }

    // Cleanup temporary file
    fs.unlink(req.file.path, (err) => {
      if (err) console.error('Error deleting temp file:', err);
    });

    // Return response to VoIP app
    res.json({
      status: 'success',
      call_id,
      chunk_number,
      risk_level: riskLevel,
      notification,
      processing_time: analysisResult.processing_time,
      analysis_summary: {
        transcription: analysisResult.results?.transcription?.text || '',
        ai_voice: analysisResult.results?.ai_voice_detection?.is_ai || false,
        emotions: analysisResult.results?.speaker_analysis?.emotions || {},
        background_noise: analysisResult.results?.background_noise?.level || 'normal'
      }
    });

  } catch (error) {
    console.error('❌ Error processing call chunk:', error.message);
    
    // Cleanup temp file on error
    if (req.file && fs.existsSync(req.file.path)) {
      fs.unlink(req.file.path, () => {});
    }

    res.status(500).json({
      error: 'Analysis failed',
      message: error.message,
      call_id: req.body.call_id
    });
  }
});

// WebSocket connection for real-time notifications
io.on('connection', (socket) => {
  console.log('📱 VoIP app connected:', socket.id);

  // Register call for notifications
  socket.on('register-call', (data) => {
    const { call_id, user_id } = data;
    callSockets.set(call_id, socket.id);
    console.log(`📞 Registered call ${call_id} for notifications`);
    
    socket.emit('registration-confirmed', {
      call_id,
      message: 'Call registered for scam monitoring'
    });
  });

  // Unregister call
  socket.on('unregister-call', (data) => {
    const { call_id } = data;
    callSockets.delete(call_id);
    console.log(`📞 Unregistered call ${call_id}`);
  });

  socket.on('disconnect', () => {
    // Remove socket from all call registrations
    for (const [call_id, socket_id] of callSockets.entries()) {
      if (socket_id === socket.id) {
        callSockets.delete(call_id);
        console.log(`📞 Auto-unregistered call ${call_id} due to disconnect`);
      }
    }
  });
});

// Get call analysis summary
app.get('/call-summary/:call_id', (req, res) => {
  const { call_id } = req.params;
  const callData = activeCalls.get(call_id);
  
  if (!callData) {
    return res.status(404).json({ error: 'Call not found' });
  }

  res.json({
    call_id,
    overall_risk: callData.overall_risk,
    total_chunks: callData.chunks.length,
    scam_indicators: callData.scam_indicators,
    call_duration: callData.chunks.length * 10, // 10 seconds per chunk
    analysis_summary: {
      transcriptions: callData.chunks.map(chunk => 
        chunk.analysis.results?.transcription?.text || ''
      ).filter(text => text.length > 0),
      risk_timeline: callData.scam_indicators.map(indicator => ({
        time: indicator.chunk_number * 10,
        risk_level: indicator.risk_level,
        message: indicator.notification.message
      }))
    }
  });
});

// Clear call data
app.delete('/call-data/:call_id', (req, res) => {
  const { call_id } = req.params;
  activeCalls.delete(call_id);
  callSockets.delete(call_id);
  
  res.json({
    message: `Call data cleared for ${call_id}`
  });
});

// Health check
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    service: 'VoIP Scam Detection Bridge',
    python_api: PYTHON_API_URL,
    active_calls: activeCalls.size,
    connected_clients: io.engine.clientsCount
  });
});

// Test Python API connectivity
app.get('/test-python-api', async (req, res) => {
  try {
    const response = await axios.get(`${PYTHON_API_URL}/health`);
    res.json({
      status: 'connected',
      python_api_response: response.data
    });
  } catch (error) {
    res.status(500).json({
      status: 'disconnected',
      error: error.message
    });
  }
});

const PORT = process.env.PORT || 3001;
server.listen(PORT, () => {
  console.log(`🌉 VoIP Scam Detection Bridge running on port ${PORT}`);
  console.log(`🐍 Python API: ${PYTHON_API_URL}`);
  console.log(`📱 Ready to process VoIP call analysis`);
});
