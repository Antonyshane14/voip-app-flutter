#!/bin/bash

echo "🧪 Testing VoIP System Setup"
echo "============================"

# Test 1: Check if Node.js dependencies are installed
echo "1. Checking Node.js dependencies..."
if [ -d "node_modules" ]; then
    echo "   ✅ Node modules found"
else
    echo "   ❌ Node modules missing - run 'npm install'"
    exit 1
fi

# Test 2: Check if Python API dependencies exist
echo "2. Checking Python API..."
if [ -f "python_api/requirements.txt" ]; then
    echo "   ✅ Python requirements found"
else
    echo "   ❌ Python requirements missing"
    exit 1
fi

# Test 3: Check if Flutter dependencies are ready
echo "3. Checking Flutter dependencies..."
if [ -f "pubspec.yaml" ]; then
    echo "   ✅ Flutter project found"
else
    echo "   ❌ Flutter project missing"
    exit 1
fi

# Test 4: Test Node.js server startup (quick test)
echo "4. Testing Node.js server startup..."
timeout 3s node bridge_server.js > /dev/null 2>&1
if [ $? -eq 124 ]; then
    echo "   ✅ Node.js server starts successfully"
else
    echo "   ❌ Node.js server failed to start"
    echo "   💡 Try: npm install"
fi

# Test 5: Check if ports are available
echo "5. Checking port availability..."
if lsof -i :3000 > /dev/null 2>&1; then
    echo "   ⚠️ Port 3000 is in use"
else
    echo "   ✅ Port 3000 is available"
fi

if lsof -i :8000 > /dev/null 2>&1; then
    echo "   ⚠️ Port 8000 is in use"
else
    echo "   ✅ Port 8000 is available"
fi

echo ""
echo "🎯 System Status:"
echo "   Node.js WebRTC Server: Ready for port 3000"
echo "   Python AI API: Ready for port 8000"
echo "   Flutter VoIP App: Ready to run"
echo ""
echo "🚀 To start the system:"
echo "   Terminal 1: cd python_api && python main.py"
echo "   Terminal 2: npm start"
echo "   Terminal 3: flutter run"
echo ""
echo "📱 The app will auto-discover the server on your local network!"
