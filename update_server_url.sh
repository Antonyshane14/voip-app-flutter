#!/bin/bash

# Update VoIP Server URL Configuration
# Usage: ./update_server_url.sh "https://your-actual-server.com"

if [ -z "$1" ]; then
    echo "❌ Error: Please provide your server URL"
    echo "Usage: $0 \"https://your-server.com\""
    echo ""
    echo "Examples:"
    echo "  $0 \"https://my-voip-app.onrender.com\""
    echo "  $0 \"https://my-voip-app.railway.app\""
    echo "  $0 \"https://abc123.pods.run\""
    echo "  $0 \"http://192.168.1.100:3000\""
    exit 1
fi

SERVER_URL="$1"
CONFIG_FILE="lib/voip_config.dart"

echo "🔧 Updating VoIP server configuration..."
echo "📍 New server URL: $SERVER_URL"

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Error: Configuration file not found: $CONFIG_FILE"
    exit 1
fi

# Create backup
cp "$CONFIG_FILE" "${CONFIG_FILE}.backup"
echo "💾 Backup created: ${CONFIG_FILE}.backup"

# Update the primary server URL
sed -i "s|static const String primaryServerUrl = '.*';|static const String primaryServerUrl = '$SERVER_URL';|" "$CONFIG_FILE"

# Also update the first entry in the serverUrls list
sed -i "0,/primaryServerUrl,/s|primaryServerUrl,|'$SERVER_URL',|" "$CONFIG_FILE"

echo "✅ Configuration updated successfully!"
echo ""
echo "📱 Next steps:"
echo "1. Build your app: flutter build apk --release"
echo "2. Test the connection to: $SERVER_URL"
echo "3. Distribute APK to users"
echo ""
echo "🌍 Users can now call each other globally!"

# Show the updated configuration
echo "📄 Updated configuration:"
grep -A 5 "primaryServerUrl" "$CONFIG_FILE"
