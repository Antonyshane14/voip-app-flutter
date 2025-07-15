#!/bin/bash

# VoIP Scam Detection System - Unified Startup Script
# Starts all required services for the complete VoIP system

set -e

echo "🚀 Starting VoIP Scam Detection System..."
echo "========================================="

# Check if we're in the right directory
if [ ! -f "python_api/main.py" ]; then
    echo "❌ Error: python_api/main.py not found"
    echo "Please run this script from the voip-app-flutter directory"
    exit 1
fi

# Create necessary directories
echo "📁 Creating directories..."
mkdir -p python_api/temp_audio
mkdir -p python_api/cache
mkdir -p python_api/speaker_segments
mkdir -p recordings
mkdir -p temp_recordings

# Check Python dependencies
echo "🐍 Checking Python environment..."
python3 -c "import fastapi, uvicorn, torch, transformers" 2>/dev/null || {
    echo "❌ Python dependencies missing. Please run:"
    echo "pip install -r requirements.txt"
    exit 1
}

# Check Node.js dependencies
echo "📦 Checking Node.js dependencies..."
if [ ! -d "signaling_server/node_modules" ]; then
    echo "� Installing signaling server dependencies..."
    cd signaling_server
    npm install
    cd ..
fi

if [ ! -d "scam_detection_bridge/node_modules" ]; then
    echo "🌉 Installing bridge server dependencies..."
    cd scam_detection_bridge
    npm install
    cd ..
fi

# Start Python API Server
echo "🐍 Starting Python API Server (Port 8000)..."
cd python_api
python3 main.py &
PYTHON_PID=$!
cd ..

echo "⏳ Waiting for Python API to start..."
sleep 15

# Verify Python API is running
python_ready=false
for i in {1..10}; do
    if curl -s http://localhost:8000/health > /dev/null 2>&1; then
        python_ready=true
        break
    fi
    echo "   Attempt $i/10: Waiting for Python API..."
    sleep 2
done

if [ "$python_ready" = false ]; then
    echo "❌ Python API failed to start"
    kill $PYTHON_PID 2>/dev/null || true
    exit 1
fi

echo "✅ Python API is running"

# Start Bridge Server
echo "🌉 Starting Bridge Server (Port 3001)..."
cd scam_detection_bridge
node bridge_server.js &
BRIDGE_PID=$!
cd ..

echo "⏳ Waiting for Bridge Server to start..."
sleep 8

# Verify Bridge Server is running
bridge_ready=false
for i in {1..5}; do
    if curl -s http://localhost:3001/health > /dev/null 2>&1; then
        bridge_ready=true
        break
    fi
    echo "   Attempt $i/5: Waiting for Bridge Server..."
    sleep 2
done

if [ "$bridge_ready" = false ]; then
    echo "❌ Bridge Server failed to start"
    kill $PYTHON_PID $BRIDGE_PID 2>/dev/null || true
    exit 1
fi

echo "✅ Bridge Server is running"

# Start Signaling Server
echo "📡 Starting Signaling Server (Port 3000)..."
cd signaling_server
node server.js &
SIGNALING_PID=$!
cd ..

echo "⏳ Waiting for Signaling Server to start..."
sleep 5

# Verify Signaling Server is running
signaling_ready=false
for i in {1..5}; do
    if curl -s http://localhost:3000/ > /dev/null 2>&1; then
        signaling_ready=true
        break
    fi
    echo "   Attempt $i/5: Waiting for Signaling Server..."
    sleep 2
done

if [ "$signaling_ready" = false ]; then
    echo "❌ Signaling Server failed to start"
    kill $PYTHON_PID $BRIDGE_PID $SIGNALING_PID 2>/dev/null || true
    exit 1
fi

echo "✅ Signaling Server is running"

echo ""
echo "🎉 All services started successfully!"
echo "======================================"
echo "🐍 Python API:      http://0.0.0.0:8000"
echo "🌉 Bridge Server:   http://0.0.0.0:3001" 
echo "📡 Signaling Server: http://0.0.0.0:3000"
echo ""
echo "🎯 VoIP System Status: READY"
echo "📱 Flutter app can now connect for calls + scam detection"
echo "🔒 Role-based alerts: Only victims will receive warnings"
echo ""

# Function to check service health
check_services() {
    python_ok=$(curl -s http://localhost:8000/health > /dev/null 2>&1 && echo "✅" || echo "❌")
    bridge_ok=$(curl -s http://localhost:3001/health > /dev/null 2>&1 && echo "✅" || echo "❌")
    signaling_ok=$(curl -s http://localhost:3000/ > /dev/null 2>&1 && echo "✅" || echo "❌")
    
    echo "📊 Service Health: Python $python_ok | Bridge $bridge_ok | Signaling $signaling_ok"
}

# Monitor services and restart if they crash
echo "🔄 Monitoring services (Ctrl+C to stop)..."

# Cleanup function
cleanup() {
    echo ""
    echo "🛑 Shutting down services..."
    kill $PYTHON_PID $BRIDGE_PID $SIGNALING_PID 2>/dev/null || true
    wait
    echo "✅ All services stopped"
    exit 0
}

# Set trap for cleanup
trap cleanup INT TERM

# Main monitoring loop
while true; do
    sleep 30
    
    # Check and restart Python API if needed
    if ! kill -0 $PYTHON_PID 2>/dev/null; then
        echo "⚠️  Python API crashed, restarting..."
        cd python_api
        python3 main.py &
        PYTHON_PID=$!
        cd ..
        sleep 10
    fi
    
    # Check and restart Bridge server if needed
    if ! kill -0 $BRIDGE_PID 2>/dev/null; then
        echo "⚠️  Bridge server crashed, restarting..."
        cd scam_detection_bridge
        node bridge_server.js &
        BRIDGE_PID=$!
        cd ..
        sleep 5
    fi
    
    # Check and restart Signaling server if needed
    if ! kill -0 $SIGNALING_PID 2>/dev/null; then
        echo "⚠️  Signaling server crashed, restarting..."
        cd signaling_server
        node server.js &
        SIGNALING_PID=$!
        cd ..
        sleep 5
    fi
    
    # Show service status every 5 minutes
    if [ $(($(date +%s) % 300)) -eq 0 ]; then
        check_services
    fi
done
