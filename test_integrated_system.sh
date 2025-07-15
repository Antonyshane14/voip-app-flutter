#!/bin/bash
# Test script to verify the integrated system works locally before RunPod deployment

echo "🧪 Testing VoIP Scam Detection System with integrated goat configuration..."

# Check if we're in the right directory
if [ ! -f "package.json" ] || [ ! -d "python_api" ]; then
    echo "❌ Error: Please run this script from the voip directory"
    exit 1
fi

# Install Node.js dependencies
echo "📦 Installing Node.js dependencies..."
npm install

# Export HuggingFace Token (REQUIRED for PyAnnote and other models)
echo "🔑 Setting up HuggingFace token..."
export HF_TOKEN="hf_your_actual_token_here"
echo "HF_TOKEN exported for this session"

# Install Python dependencies
echo "🐍 Installing Python dependencies..."
cd python_api
pip3 install -r requirements.txt
cd ..

# Start Python API in background
echo "🚀 Starting Python API on port 8000..."
cd python_api
python3 main.py &
PYTHON_PID=$!
cd ..

# Wait for Python API to start
echo "⏳ Waiting for Python API to initialize..."
sleep 5

# Start Node.js bridge in background
echo "🌉 Starting Node.js bridge on port 3001..."
node bridge_server.js &
NODE_PID=$!

# Wait for bridge to start
echo "⏳ Waiting for bridge to initialize..."
sleep 3

# Test health endpoints
echo "🔍 Testing system health..."
echo "Testing Python API..."
curl -s http://localhost:8000/health || echo "Python API not responding"

echo "Testing Node.js bridge..."
curl -s http://localhost:3001/health || echo "Node.js bridge not responding"

echo ""
echo "✅ System test complete!"
echo "📊 Process Status:"
echo "- Python API PID: $PYTHON_PID"
echo "- Node.js Bridge PID: $NODE_PID"
echo ""
echo "🌍 Service URLs:"
echo "- Python API: http://localhost:8000"
echo "- Node.js Bridge: http://localhost:3001"
echo "- Health checks available at /health on both services"
echo ""
echo "🛑 To stop all services:"
echo "kill $PYTHON_PID $NODE_PID"
echo ""
echo "🎉 System is ready for RunPod deployment!"
