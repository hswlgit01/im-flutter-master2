import 'package:flutter/material.dart';

class NumberKeyboard extends StatelessWidget {
  final Function(String) onKeyPressed;

  const NumberKeyboard({super.key, required this.onKeyPressed});

  @override
  Widget build(BuildContext context) {
    final List<List<String>> buttons = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.5,
      ),
      itemCount: buttons.length * buttons[0].length,
      itemBuilder: (context, index) {
        final row = index ~/ buttons[0].length;
        final col = index % buttons[0].length;
        final text = buttons[row][col];

        if (text.isEmpty) return const SizedBox.shrink();

        return ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            shape: const CircleBorder(),
          ),
          onPressed: () => onKeyPressed(text),
          child: Text(
            text == '⌫' ? '删除' : text,
            style: const TextStyle(fontSize: 24),
          ),
        );
      },
    );
  }
}
