import 'package:flutter/material.dart';

class RichTextSprintf extends StatelessWidget {
  final String template;
  final List<InlineSpan> values;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final StrutStyle? strutStyle;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;

  const RichTextSprintf(
    this.template,
    this.values, {
    super.key,
    this.style = const TextStyle(color: Colors.black),
    this.textAlign,
    this.textDirection,
    this.locale,
    this.strutStyle,
    this.textWidthBasis,
    this.textHeightBehavior,
  });

  @override
  Widget build(BuildContext context) {
    final RegExp placeholder = RegExp(r'%s');
    final List<InlineSpan> spans = [];

    int valueIndex = 0;
    int currentIndex = 0;

    for (final match in placeholder.allMatches(template)) {
      if (match.start > currentIndex) {
        spans.add(TextSpan(
          text: template.substring(currentIndex, match.start),
        ));
      }

      if (valueIndex < values.length) {
        spans.add(values[valueIndex]);
        valueIndex++;
      } else {
        spans.add(const TextSpan(text: '%s'));
      }

      currentIndex = match.end;
    }

    if (currentIndex < template.length) {
      spans.add(TextSpan(text: template.substring(currentIndex)));
    }

    return RichText(
      text: TextSpan(style: style, children: spans),
      textAlign: textAlign ?? TextAlign.start,
      textDirection: textDirection,
      locale: locale,
      strutStyle: strutStyle,
      textWidthBasis: textWidthBasis ?? TextWidthBasis.parent,
      textHeightBehavior: textHeightBehavior,
    );
  }
}
