const axios = require('axios');
const FormData = require('form-data');
const fs = require('fs');

// Test configuration
const BRIDGE_URL = process.env.BRIDGE_URL || 'http://localhost:3001';
const TEST_AUDIO_PATH = './test_audio.wav';

async function testScamDetection() {
  console.log('🧪 Testing VoIP Scam Detection System');
  console.log('====================================');

  try {
    // 1. Test health endpoints
    console.log('1. Testing health endpoints...');
    
    const healthResponse = await axios.get(`${BRIDGE_URL}/health`);
    console.log('✅ Bridge Health:', healthResponse.data);

    const pythonTestResponse = await axios.get(`${BRIDGE_URL}/test-python-api`);
    console.log('✅ Python API Connection:', pythonTestResponse.data);

    // 2. Create test audio file if it doesn't exist
    if (!fs.existsSync(TEST_AUDIO_PATH)) {
      console.log('2. Creating test audio file...');
      // Create a simple WAV file for testing (silence)
      const silence = Buffer.alloc(44100 * 2 * 10); // 10 seconds of silence
      fs.writeFileSync(TEST_AUDIO_PATH, silence);
    }

    // 3. Test audio analysis
    console.log('3. Testing audio analysis...');
    
    const formData = new FormData();
    formData.append('audio', fs.createReadStream(TEST_AUDIO_PATH));
    formData.append('call_id', 'test_call_123');
    formData.append('chunk_number', '1');
    formData.append('user_id', 'test_user');

    const analysisResponse = await axios.post(
      `${BRIDGE_URL}/analyze-call-chunk`,
      formData,
      {
        headers: {
          ...formData.getHeaders(),
        },
        timeout: 30000
      }
    );

    console.log('✅ Analysis Result:', JSON.stringify(analysisResponse.data, null, 2));

    // 4. Test call summary
    console.log('4. Testing call summary...');
    const summaryResponse = await axios.get(`${BRIDGE_URL}/call-summary/test_call_123`);
    console.log('✅ Call Summary:', JSON.stringify(summaryResponse.data, null, 2));

    console.log('\n🎉 All tests passed! System is working correctly.');

  } catch (error) {
    console.error('❌ Test failed:', error.message);
    if (error.response) {
      console.error('Response data:', error.response.data);
    }
    process.exit(1);
  }
}

// Run tests
testScamDetection();
