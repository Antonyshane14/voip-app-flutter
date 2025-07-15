// VoIP Server Configuration
// Update this file with your actual deployed server URL

class VoIPConfig {
  // Replace this with your actual RunPod URL once deployed
  static const String primaryServerUrl = 'https://your-pod-id-80.proxy.runpod.net';

  // Alternative server URLs (for redundancy)
  static const List<String> serverUrls = [
    // Primary RunPod server (update this!)
    'https://your-pod-id-80.proxy.runpod.net',
    primaryServerUrl,

    // Backup servers
    'https://your-app-name.railway.app',
    'https://your-runpod-id.pods.run',
    'https://your-app-name.herokuapp.com',
    'http://your-server-ip:3000',

    // Local development (for testing)
    'http://localhost:3000',
    'http://127.0.0.1:3000',
  ];

  // Server endpoints
  static const String socketPath = '/socket.io/';
  static const String healthPath = '/health';

  // Connection settings
  static const Duration connectionTimeout = Duration(seconds: 5);
  static const Duration socketTimeout = Duration(seconds: 3);

  // Instructions:
  // 1. Deploy your server to a cloud platform (RunPod, Render, Railway, etc.)
  // 2. Update the primaryServerUrl above with your actual server URL
  // 3. Build and distribute your Flutter app
  // 4. Users can call each other from anywhere in the world!
}
