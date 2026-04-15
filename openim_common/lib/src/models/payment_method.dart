enum PaymentMethodType {
  bankCard,  // 银行卡
  wechat,    // 微信支付
  alipay,    // 支付宝
}

class PaymentMethod {
  final String id;
  final PaymentMethodType type;
  final String? cardNumber;
  final String? bankName;
  final String? branchName;
  final String? accountName;
  final String? qrCodeUrl;
  final bool isDefault;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  PaymentMethod({
    required this.id,
    required this.type,
    this.cardNumber,
    this.bankName,
    this.branchName,
    this.accountName,
    this.qrCodeUrl,
    this.isDefault = false,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.index,
    'cardNumber': cardNumber,
    'bankName': bankName,
    'branchName': branchName,
    'accountName': accountName,
    'qrCodeUrl': qrCodeUrl,
    'isDefault': isDefault,
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  factory PaymentMethod.fromJson(Map<String, dynamic> json) => PaymentMethod(
    id: json['id'],
    type: PaymentMethodType.values[json['type']],
    cardNumber: json['cardNumber'],
    bankName: json['bankName'],
    branchName: json['branchName'],
    accountName: json['accountName'],
    qrCodeUrl: json['qrCodeUrl'],
    isDefault: json['isDefault'] ?? false,
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
    updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
  );
}