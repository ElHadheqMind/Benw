import 'package:flutter_test/flutter_test.dart';
import 'package:benw_edu/services/benw_edu_service.dart';
import 'package:flutter_gemma/flutter_gemma.dart';


void main() {
  // This test ensures the model can initialize and generate a response without any UI.
  // Note: This requires the model asset to be present and LiteRT to be available.
  
  test('Benw Model Inference Test (Headless)', () async {
    print('🚀 Starting Benw Headless Test...');
    
    // 1. Initialize FlutterGemma (Low-level)
    await FlutterGemma.initialize();
    print('✅ FlutterGemma Core Initialized');

    final benwEduService = BenwEduService();
    
    // 2. Initialize Service (Loads model from assets)
    print('📂 Loading Model from assets...');
    await benwEduService.init();
    
    if (!benwEduService.isInitialized) {
      fail('❌ Benw Service failed to initialize. Check if assets/models/gemma-4-E2B-it.litertlm exists.');
    }
    print('✅ Model Loaded successfully');

    // 3. Test Text Generation
    print('🤖 Sending test prompt: "Hello, who are you?"');
    try {
      final response = await benwEduService.generateNote('Hello, who are you?');
      print('📝 Received Response:');
      print('Title: ${response['title']}');
      print('Content: ${response['content']}');
      
      expect(response['title'], isNotEmpty);
      expect(response['content'], isNotEmpty);
      print('🎉 Test Passed!');
    } catch (e) {
      print('❌ Inference Error: $e');
      fail('Inference failed');
    }
  });
}
