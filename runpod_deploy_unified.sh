#!/bin/bash

# VoIP Scam Detection System - RunPod Git Clone Deployment
# Clone the repository directly on RunPod and run the complete system

set -e

echo "🚀 VoIP Scam Detection System - RunPod Git Deployment"
echo "======================================================"

# Update system and install dependencies
echo "📦 Installing system dependencies..."
apt-get update
apt-get install -y curl wget git build-essential ffmpeg sox

# Install Node.js 18.x
echo "📦 Installing Node.js..."
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

# Install Python dependencies
echo "🐍 Installing Python dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

# Install Hugging Face CLI and login (if token provided)
if [ ! -z "$HF_TOKEN" ]; then
    echo "🤗 Setting up Hugging Face access..."
    pip install huggingface_hub
    echo $HF_TOKEN | huggingface-cli login --token
    echo "✅ Hugging Face authenticated"
fi

# Install Node.js dependencies for all services
echo "📦 Installing Node.js dependencies..."

# Signaling server dependencies
echo "📡 Installing signaling server dependencies..."
cd signaling_server
npm install
cd ..

# Bridge server dependencies  
echo "🌉 Installing bridge server dependencies..."
cd scam_detection_bridge
npm install
cd ..

# Create necessary directories
echo "📁 Creating necessary directories..."
mkdir -p python_api/temp_audio
mkdir -p python_api/cache
mkdir -p python_api/speaker_segments
mkdir -p recordings
mkdir -p temp_recordings

# Pre-download AI models for faster startup
echo "🤖 Pre-downloading AI models (this may take a few minutes)..."
cd python_api
python3 -c "
import sys
sys.path.append('.')
try:
    import config
    from modules.transcription import WhisperTranscriber
    from modules.ai_voice_detector import AIVoiceDetector
    from modules.emotion_detector import EmotionDetector

    print('📥 Downloading Whisper model...')
    transcriber = WhisperTranscriber(config.WHISPER_MODEL_SIZE)
    print('✅ Whisper model ready')

    print('📥 Downloading AI voice detection model...')
    ai_detector = AIVoiceDetector(config.AI_VOICE_MODEL)
    print('✅ AI voice detection model ready')

    print('📥 Downloading emotion detection model...')
    emotion_detector = EmotionDetector(config.EMOTION_MODEL)
    print('✅ Emotion detection model ready')

    print('🎉 All AI models downloaded successfully!')
except Exception as e:
    print(f'⚠️ Model download failed: {e}')
    print('Models will be downloaded on first use')
"
cd ..

echo "✅ VoIP Scam Detection System setup complete!"
echo ""
echo "🎯 Ready to start services:"
echo "🐍 Python API: Will run on port 8000"
echo "🌉 Bridge Server: Will run on port 3001"
echo "📡 Signaling Server: Will run on port 3000"
echo ""
echo "� To start all services, run:"
echo "./start_unified_system.sh"
echo ""
echo "📱 Your Flutter app can connect to:"
echo "   Signaling: http://[RUNPOD_IP]:3000"
echo "   Detection: Automatic via bridge server"
