import 'dart:developer';
import 'package:battery_plus/battery_plus.dart';
import 'package:system_info_plus/system_info_plus.dart';

class CactusModelConfig {
  final String path;
  final String reason;
  final bool isNetwork;
  final bool needsVision;

  CactusModelConfig({
    required this.path,
    required this.reason,
    this.isNetwork = false,
    this.needsVision = false,
  });
}

/// CactusRouter dynamically determines which LiteRT Model to utilize
/// strictly prioritizing Hardware Specs (Battery & RAM).
class CactusRouter {
  static final CactusRouter _instance = CactusRouter._internal();
  factory CactusRouter() => _instance;
  CactusRouter._internal();

  final Battery _battery = Battery();

  // LiteRT Asset Paths
  static const String pathEco = 'assets/models/gemma-4-E2B-it.litertlm';
  static const String pathHeavy = 'assets/models/gemma-4-E4B-it.litertlm';

  /// Set the minimum required RAM for the heavier model
  static const double _minGbRamForHeavy = 5.5;

  /// Evaluates device status (battery & RAM) to determine model tier.
  /// Targets the Cactus Track: "Intelligently routes tasks between models".
  Future<CactusModelConfig> getRecommendedModel({bool needsVision = false, String complexity = 'low'}) async {
    try {
      // 1. Check Battery
      final level = await _battery.batteryLevel;
      final isLowBattery = level < 25;
      
      // 2. Check RAM (Available for Android/iOS via package)
      // Note: SystemInfoPlus.physicalMemory is in bytes
      final physicalRam = await SystemInfoPlus.physicalMemory ?? 4000000000;
      final gbRam = physicalRam / (1024 * 1024 * 1024);
      final isLowResources = gbRam < _minGbRamForHeavy;

      log('Cactus: Battery Level: $level%, RAM: ${gbRam.toStringAsFixed(1)} GB');

      // 3. Routing Logic
      if (isLowBattery || isLowResources) {
        return CactusModelConfig(
          path: pathEco,
          reason: isLowBattery ? 'Eco Mode: Battery preserving ($level%)' : 'Eco Mode: Memory preserving (${gbRam.toStringAsFixed(1)}GB < $_minGbRamForHeavy GB)',
          needsVision: needsVision,
        );
      }

      /* 
      // DISABLED: Heavy model is not in pubspec.yaml
      if (complexity == 'high' || (needsVision && !isLowResources)) {
        return CactusModelConfig(
          path: pathHeavy,
          reason: 'High Performance Mode: Adequate resources & complex task detected.',
          needsVision: needsVision,
        );
      }
      */

      // Default to Eco for standard text tasks to save energy
      return CactusModelConfig(
        path: pathEco,
        reason: 'Optimal Mode: Standard task efficiency.',
        needsVision: needsVision,
      );
    } catch (e) {
      log('Cactus Router Error (Fallback to Eco): $e');
      return CactusModelConfig(
        path: pathEco,
        reason: 'Fallback: Error detecting system state.',
        needsVision: needsVision,
      );
    }
  }
}
