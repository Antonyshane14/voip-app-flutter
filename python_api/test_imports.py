#!/usr/bin/env python3
"""
Quick test to verify all modules can be imported
"""

import sys
import os

# Add the project root to Python path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

def test_imports():
    """Test that all modules can be imported without errors"""
    print("Testing module imports...")
    
    try:
        # Test basic imports
        import config
        print("✓ Config module imported")
        
        # Test module imports
        from modules.audio_processor import AudioProcessor
        print("✓ AudioProcessor imported")
        
        from modules.cache_manager import CacheManager
        print("✓ CacheManager imported")
        
        from modules.llm_analyzer import LLMAnalyzer
        print("✓ LLMAnalyzer imported")
        
        # Test if we can create instances (without loading heavy models)
        audio_processor = AudioProcessor()
        cache_manager = CacheManager()
        llm_analyzer = LLMAnalyzer()
        
        print("✓ Basic instances created successfully")
        print("\n🎉 All core modules imported successfully!")
        print("📝 Note: Heavy ML models are not loaded in this test")
        
        return True
        
    except ImportError as e:
        print(f"❌ Import error: {e}")
        return False
    except Exception as e:
        print(f"❌ Other error: {e}")
        return False

if __name__ == "__main__":
    print("=== Audio Scam Detection System - Module Test ===")
    success = test_imports()
    
    if success:
        print("\n✅ System is ready for full startup!")
        print("Run: python main.py")
    else:
        print("\n❌ Issues found. Please install missing dependencies.")
        print("Run: pip install -r requirements.txt")
    
    sys.exit(0 if success else 1)
