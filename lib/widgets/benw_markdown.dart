import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:benw_edu/theme/app_theme.dart';

/// Converts model-generated LaTeX delimiters to the format
/// expected by gpt_markdown:
///   $$...$$  →  \[...\]   (display/block math)
///   $...$    →  \(...\)   (inline math)
///
/// This is necessary because on-device models (Gemma, etc.) output
/// standard LaTeX dollar-sign notation, while gpt_markdown v1.x uses
/// the backslash-bracket / backslash-paren convention.
String normalizeMathDelimiters(String input) {
  // 1. Block math: $$...$$ → \[...\]
  //    Use non-greedy match so nested $ are handled correctly.
  String result = input.replaceAllMapped(
    RegExp(r'\$\$(.+?)\$\$', dotAll: true),
    (m) => '\\[${m.group(1)}\\]',
  );

  // 2. Inline math: $...$ → \(...\)
  //    Exclude: empty $$, currency (e.g. $10), already converted \[...\]
  result = result.replaceAllMapped(
    RegExp(r'(?<!\$)\$(?!\$)(.+?)(?<!\$)\$(?!\$)', dotAll: true),
    (m) {
      final inner = m.group(1) ?? '';
      // Heuristic: if it looks like a price / plain number, keep as-is
      if (RegExp(r'^\s*[\d,\.]+\s*$').hasMatch(inner)) return m.group(0)!;
      return '\\(${inner}\\)';
    },
  );

  return result;
}

/// A drop-in `GptMarkdown` wrapper used across every AI output surface.
/// Handles:
///   • LaTeX $ → \( \) conversion for gpt_markdown compatibility
///   • Consistent text color / line height / font size
///   • Bold, italic, headings, lists, code blocks, tables all render correctly
class BenwMarkdown extends StatelessWidget {
  final String data;
  final TextStyle? style;
  final Color? textColor;

  const BenwMarkdown(
    this.data, {
    super.key,
    this.style,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = (style ??
            Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: textColor ?? AppColors.textPrimary,
                  height: 1.6,
                ))
        ?.copyWith(color: textColor ?? AppColors.textPrimary);

    return GptMarkdown(
      normalizeMathDelimiters(data),
      style: baseStyle,
    );
  }
}
