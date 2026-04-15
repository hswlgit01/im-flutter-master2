import 'dart:convert';

class RefundData {
  final int customType;
  final RefundDataDetails data;

  RefundData({
    required this.customType,
    required this.data,
  });

  factory RefundData.fromJson(Map<String, dynamic> json) {
    return RefundData(
      customType: json['customType'],
      data: RefundDataDetails.fromJson(json['data']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'customType': customType,
      'data': data.toJson(),
    };
  }

  String toJsonString() => json.encode(toJson());
  
  factory RefundData.fromJsonString(String jsonString) => 
      RefundData.fromJson(json.decode(jsonString));
}

class RefundDataDetails {
  final String currency;
  final num amount;
  final String refundID;
  final int refundTime;
  final int refundType;
  final num? rate;
  final String refundDesc;

  RefundDataDetails({
    required this.currency,
    required this.amount,
    required this.refundID,
    required this.refundTime,
    required this.refundType,
    this.rate,
    this.refundDesc = "",
  });

  factory RefundDataDetails.fromJson(Map<String, dynamic> json) {
    return RefundDataDetails(
      currency: json['currency'],
      amount: num.parse(json['amount']),
      refundID: json['refundID'],
      refundTime: json['refundTime'],
      refundType: json['refundType'],
      rate: num.tryParse(json['rate']),
      refundDesc: json['refundDesc'] ?? "",
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'currency': currency,
      'amount': amount,
      'refundID': refundID,
      'refundTime': refundTime,
      'refundType': refundType,
      'rate': rate,
      'refundDesc': refundDesc,
    };
  }
}