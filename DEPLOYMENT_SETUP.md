# 🚀 VoIP Scam Detection - Deployment Setup

## 🔑 HuggingFace Token Setup (REQUIRED)

Before deploying, you MUST set up your HuggingFace token:

### 1. Get Your Token
- Go to: https://huggingface.co/settings/tokens
- Create a new token with **READ** permissions
- Copy the token (starts with `hf_`)

### 2. Update the Hardcoded Token

Replace `hf_your_actual_token_here` with your actual token in these files:

#### For Local Testing:
```bash
# Edit test_integrated_system.sh line 12:
export HF_TOKEN="hf_your_actual_token_here"
```

#### For RunPod Deployment:
```bash
# Edit runpod_setup.sh line 8:
export HF_TOKEN="hf_your_actual_token_here"
```

#### For Environment Config:
```bash
# Edit python_api/.env line 4:
HF_TOKEN=hf_your_actual_token_here
```

### 3. Manual Export (Alternative)

You can also export the token manually before running scripts:

```bash
# Export token in your terminal session
export HF_TOKEN="hf_your_actual_token_here"

# Then run the deployment
./runpod_setup.sh
```

## 🧪 Testing Locally

```bash
# Make sure you're in the voip directory
cd /home/antonyshane/voip

# Update HF token in test_integrated_system.sh first!
# Then run the test
chmod +x test_integrated_system.sh
./test_integrated_system.sh
```

## 🌐 RunPod Deployment

```bash
# Update HF token in runpod_setup.sh first!
# Then run the setup
chmod +x runpod_setup.sh
./runpod_setup.sh
```

## ⚠️ Security Note

- Never commit your actual HF token to git
- Replace the hardcoded token with placeholder before committing
- The token is required for PyAnnote speaker diarization models

---
**Ready for deployment!** 🎉
