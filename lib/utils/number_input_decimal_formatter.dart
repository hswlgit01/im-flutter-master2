import 'package:flutter/services.dart';
import 'package:get/get.dart';

class DecimalTextInputFormatter extends TextInputFormatter {
  final Rx<int> decimalPlaces; // 小数位数

  DecimalTextInputFormatter({required this.decimalPlaces});

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final RegExp regex =
        RegExp(r'^\d*\.?\d{0,' + decimalPlaces.value.toString() + r'}');
    String newString = regex.stringMatch(newValue.text) ?? '';
    return TextEditingValue(
      text: newString,
      selection: TextSelection.collapsed(offset: newString.length),
    );
  }
}
