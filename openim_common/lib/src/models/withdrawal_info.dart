// 在 openim_common 中创建 withdrawal_info.dart
import 'dart:convert';

class WithdrawalRule {
  bool? isEnabled; // 是否启用提现功能
  double? minAmount; // 最小提现金额
  double? maxAmount; // 最大提现金额
  double? feeRate; // 手续费率 (百分比)
  double? feeFixed; // 固定手续费
  bool? needRealName; // 是否需要实名认证
  bool? needBindAccount; // 是否需要绑定收款账户

  WithdrawalRule({
    this.isEnabled,
    this.minAmount,
    this.maxAmount,
    this.feeRate,
    this.feeFixed,
    this.needRealName,
    this.needBindAccount,
  });

  factory WithdrawalRule.fromJson(Map<String, dynamic> json) {
    return WithdrawalRule(
      isEnabled: json['isEnabled'] ?? false,
      minAmount: (json['minAmount'] as num?)?.toDouble(),
      maxAmount: (json['maxAmount'] as num?)?.toDouble(),
      feeRate: (json['feeRate'] as num?)?.toDouble(),
      feeFixed: (json['feeFixed'] as num?)?.toDouble(),
      needRealName: json['needRealName'],
      needBindAccount: json['needBindAccount'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isEnabled': isEnabled,
      'minAmount': minAmount,
      'maxAmount': maxAmount,
      'feeRate': feeRate,
      'feeFixed': feeFixed,
      'needRealName': needRealName,
      'needBindAccount': needBindAccount,
    };
  }
}

class WithdrawalAccount {
  String? id;
  String? type; // bank/alipay/wechat
  String? accountName;
  String? accountNumber;
  String? bankName; // 银行名称
  String? bankBranch; // 支行名称
  String? alipayAccount; // 支付宝账号
  String? wechatOpenId; // 微信OpenID
  bool? isDefault;
  
  WithdrawalAccount({
    this.id,
    this.type,
    this.accountName,
    this.accountNumber,
    this.bankName,
    this.bankBranch,
    this.alipayAccount,
    this.wechatOpenId,
    this.isDefault,
  });
  
  factory WithdrawalAccount.fromJson(Map<String, dynamic> json) {
    return WithdrawalAccount(
      id: json['id'],
      type: json['type'],
      accountName: json['accountName'],
      accountNumber: json['accountNumber'],
      bankName: json['bankName'],
      bankBranch: json['bankBranch'],
      alipayAccount: json['alipayAccount'],
      wechatOpenId: json['wechatOpenId'],
      isDefault: json['isDefault'] ?? false,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'accountName': accountName,
      'accountNumber': accountNumber,
      'bankName': bankName,
      'bankBranch': bankBranch,
      'alipayAccount': alipayAccount,
      'wechatOpenId': wechatOpenId,
      'isDefault': isDefault,
    };
  }
  
  String get displayText {
    switch (type) {
      case 'bank':
        return '${bankName ?? ''} ${accountNumber?.substring(accountNumber!.length - 4)}';
      case 'alipay':
        return '支付宝($alipayAccount)';
      case 'wechat':
        return '微信支付';
      default:
        return '';
    }
  }
}

// 提现记录
class WithdrawalRecord {
  String? id;
  String? orderNo; // 提现订单号
  double? amount; // 提现金额
  double? fee; // 手续费
  double? actualAmount; // 实际到账金额
  int? status; // 状态: 0-待审核,1-已通过,2-打款中,3-已完成,4-已拒绝,5-已取消
  int? paymentType; // 收款方式类型: 0-银行卡,1-微信,2-支付宝
  String? paymentInfo; // 收款账户信息
  String? rejectReason; // 拒绝原因
  DateTime? approveTime; // 审批时间
  DateTime? transferTime; // 打款时间
  DateTime? completeTime; // 完成时间
  DateTime? createdAt; // 创建时间

  WithdrawalRecord({
    this.id,
    this.orderNo,
    this.amount,
    this.fee,
    this.actualAmount,
    this.status,
    this.paymentType,
    this.paymentInfo,
    this.rejectReason,
    this.approveTime,
    this.transferTime,
    this.completeTime,
    this.createdAt,
  });

  factory WithdrawalRecord.fromJson(Map<String, dynamic> json) {
    return WithdrawalRecord(
      id: json['id'],
      orderNo: json['orderNo'],
      amount: (json['amount'] as num?)?.toDouble(),
      fee: (json['fee'] as num?)?.toDouble(),
      actualAmount: (json['actualAmount'] as num?)?.toDouble(),
      status: json['status'],
      paymentType: json['paymentType'],
      paymentInfo: json['paymentInfo'],
      rejectReason: json['rejectReason'],
      approveTime: json['approveTime'] != null ? DateTime.parse(json['approveTime']).toLocal() : null,
      transferTime: json['transferTime'] != null ? DateTime.parse(json['transferTime']).toLocal() : null,
      completeTime: json['completeTime'] != null ? DateTime.parse(json['completeTime']).toLocal() : null,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']).toLocal() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orderNo': orderNo,
      'amount': amount,
      'fee': fee,
      'actualAmount': actualAmount,
      'status': status,
      'paymentType': paymentType,
      'paymentInfo': paymentInfo,
      'rejectReason': rejectReason,
      'approveTime': approveTime?.toIso8601String(),
      'transferTime': transferTime?.toIso8601String(),
      'completeTime': completeTime?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  // 状态文本
  String get statusText {
    switch (status) {
      case 0:
        return '待审核';
      case 1:
        return '已通过';
      case 2:
        return '打款中';
      case 3:
        return '已完成';
      case 4:
        return '已拒绝';
      case 5:
        return '已取消';
      default:
        return '未知';
    }
  }

  // 状态颜色
  String get statusColor {
    switch (status) {
      case 0:
        return '#FF9800'; // 橙色 - 待审核
      case 1:
        return '#2196F3'; // 蓝色 - 已通过
      case 2:
        return '#2196F3'; // 蓝色 - 打款中
      case 3:
        return '#4CAF50'; // 绿色 - 已完成
      case 4:
        return '#F44336'; // 红色 - 已拒绝
      case 5:
        return '#9E9E9E'; // 灰色 - 已取消
      default:
        return '#9E9E9E';
    }
  }

  // 收款方式文本
  String get paymentTypeText {
    switch (paymentType) {
      case 0:
        return '银行卡';
      case 1:
        return '微信';
      case 2:
        return '支付宝';
      default:
        return '未知';
    }
  }

  // 是否可以取消
  bool get canCancel {
    return status == 0; // 只有待审核状态可以取消
  }
}