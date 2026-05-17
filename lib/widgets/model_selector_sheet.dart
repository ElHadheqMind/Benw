import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:benw_edu/providers/settings_provider.dart';
import 'package:benw_edu/services/benw_edu_service.dart';
import 'package:benw_edu/services/cactus_router.dart';
import 'package:benw_edu/theme/app_theme.dart';

class ModelSelectorSheet extends StatelessWidget {
  ModelSelectorSheet({super.key});

  final BenwEduService _benwService = BenwEduService();

  void _selectModel(BuildContext context, CactusModelConfig config) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    settings.setSelectedModel(config.path, config.isNetwork);
    _benwService.forceLoadModel(config);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.only(
        top: 24,
        left: 20,
        right: 20,
        bottom: 24 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.memory_rounded, color: AppColors.accent),
              ),
              const SizedBox(width: 12),
              Text(
                'AI Model Selector',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.textHint),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Select the backbone brain for your Benw assistant. Your phone will auto-route by default unless you force an override.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 24),

          // 2B ECO MODEL
          _buildModelCard(
            context,
            title: 'Benw 4 Eco (2B)',
            description: 'Lightning fast local execution. Perfect for battery saving and offline quick notes.',
            icon: Icons.energy_savings_leaf_rounded,
            config: CactusModelConfig(
              path: CactusRouter.pathEco,
              reason: 'Eco model selected manually via settings',
              isNetwork: false,
            ),
          ),

          const SizedBox(height: 16),

          // 4B HEAVY MODEL
          _buildModelCard(
            context,
            title: 'Benw 4 Heavy (4B)',
            description: 'Advanced reasoning engine. Powerful offline inference.',
            icon: Icons.psychology_alt_rounded,
            config: CactusModelConfig(
              path: 'https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm/resolve/main/gemma-4-E4B-it.litertlm',
              reason: 'Heavy model selected manually via settings',
              isNetwork: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelCard(BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required CactusModelConfig config,
  }) {
    return ValueListenableBuilder<String>(
      valueListenable: _benwService.activeModelName,
      builder: (context, activeName, child) {
        final isActive = activeName == title;

        return GestureDetector(
          onTap: () => _selectModel(context, config),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isActive ? AppColors.accent.withValues(alpha: 0.1) : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isActive ? AppColors.accent : AppColors.textHint.withValues(alpha: 0.1),
                width: isActive ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: isActive ? AppColors.accent : AppColors.textPrimary, size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(description, style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.3)),
                    ],
                  ),
                ),
                if (isActive)
                  const Padding(
                    padding: EdgeInsets.only(left: 8.0),
                    child: Icon(Icons.check_circle_rounded, color: AppColors.accent),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
