import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

class MentionText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextStyle mentionStyle;
  final Function(String mentionStr)? onMentionTap;
  final String Function(String mentionStr)? formatText;
  final List<String> mentionPrefixes;

  const MentionText({
    super.key,
    required this.text,
    this.style,
    this.mentionStyle = const TextStyle(
      color: Colors.blue,
      fontWeight: FontWeight.bold,
    ),
    this.onMentionTap,
    this.mentionPrefixes = const ['@'], 
    this.formatText,
  });

  @override
  Widget build(BuildContext context) {
    final defaultStyle = style ?? Theme.of(context).textTheme.bodyMedium;
    final spans = <TextSpan>[];
    final pattern = RegExp(
      mentionPrefixes.map((prefix) => '($prefix\\w+)').join('|'),
    );

    int lastEnd = 0;
    for (final match in pattern.allMatches(text)) {
      // 添加匹配前的普通文本
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastEnd, match.start),
            style: defaultStyle,
          ),
        );
      }

      // 添加提及文本
      final mention = match.group(0)!;
      spans.add(
        TextSpan(
          text: formatText != null
              ? formatText!(mention)
              : mention,
          style: mentionStyle,
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              if (onMentionTap != null) {
                onMentionTap!(mention);
              }
            },
        ),
      );

      lastEnd = match.end;
    }

    // 添加最后一段普通文本
    if (lastEnd < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastEnd),
          style: defaultStyle,
        ),
      );
    }

    return RichText(
      text: TextSpan(
        children: spans,
        style: defaultStyle,
      ),
    );
  }
}