class BalanceData {
  String? id;
  String? name;
  String? type;
  String? status;
  String? logo;
  String? totalBalanceUsd;
  String? totalFrozenBalance;
  String? compensationBalance; // 补偿金总余额，与币种无关
  String? createdAt;
  String? updatedAt;
  List<Currency>? currency;

  BalanceData(
      {this.id,
      this.name,
      this.type,
      this.status,
      this.logo,
      this.totalBalanceUsd,
      this.totalFrozenBalance,
      this.compensationBalance,
      this.createdAt,
      this.updatedAt,
      this.currency});

  BalanceData.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    type = json['type'];
    status = json['status'];
    logo = json['logo'];
    totalBalanceUsd = json['total_balance_usd'];
    totalFrozenBalance = json['total_frozen_balance'];
    compensationBalance = json['compensation_balance']; // 解析补偿金总余额
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    if (json['currency'] != null) {
      currency = <Currency>[];
      json['currency'].forEach((v) {
        currency!.add(new Currency.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['name'] = this.name;
    data['type'] = this.type;
    data['status'] = this.status;
    data['logo'] = this.logo;
    data['total_balance_usd'] = this.totalBalanceUsd;
    data['total_frozen_balance'] = this.totalFrozenBalance;
    data['compensation_balance'] = this.compensationBalance; // 添加补偿金余额
    data['created_at'] = this.createdAt;
    data['updated_at'] = this.updatedAt;
    if (this.currency != null) {
      data['currency'] = this.currency!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Currency {
  CurrencyInfo? currencyInfo;
  BalanceInfo? balanceInfo;

  Currency({this.currencyInfo, this.balanceInfo});

  Currency.fromJson(Map<String, dynamic> json) {
    currencyInfo = json['currency_info'] != null
        ? new CurrencyInfo.fromJson(json['currency_info'])
        : null;
    balanceInfo = json['balance_info'] != null
        ? new BalanceInfo.fromJson(json['balance_info'])
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    if (this.currencyInfo != null) {
      data['currency_info'] = this.currencyInfo!.toJson();
    }
    if (this.balanceInfo != null) {
      data['balance_info'] = this.balanceInfo!.toJson();
    }
    return data;
  }
}

class CurrencyInfo {
  String? id;
  String? name;
  String? icon;
  int? order;
  String? exchangeRate;
  String? minAvailableAmount;
  int? maxTotalSupply;
  String? maxRedPacketAmount;
  String? creatorId;
  int? decimals;
  String? createdAt;
  String? updatedAt;

  CurrencyInfo(
      {this.id,
      this.name,
      this.icon,
      this.order,
      this.exchangeRate,
      this.minAvailableAmount,
      this.maxTotalSupply,
      this.maxRedPacketAmount,
      this.creatorId,
      this.decimals,
      this.createdAt,
      this.updatedAt});

  CurrencyInfo.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    icon = json['icon'];
    order = json['order'];
    exchangeRate = json['exchange_rate'];
    minAvailableAmount = json['min_available_amount'];
    maxTotalSupply = json['max_total_supply'];
    maxRedPacketAmount = json['max_red_packet_amount'];
    creatorId = json['creator_id'];
    decimals = json['decimals'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['name'] = this.name;
    data['icon'] = this.icon;
    data['order'] = this.order;
    data['exchange_rate'] = this.exchangeRate;
    data['min_available_amount'] = this.minAvailableAmount;
    data['max_total_supply'] = this.maxTotalSupply;
    data['max_red_packet_amount'] = this.maxRedPacketAmount;
    data['creator_id'] = this.creatorId;
    data['decimals'] = this.decimals;
    data['created_at'] = this.createdAt;
    data['updated_at'] = this.updatedAt;
    return data;
  }
}

class BalanceInfo {
  String? id;
  String? walletId;
  String? currencyId;
  String? availableBalance;
  String? redPacketFrozenBalance;
  String? transferFrozenBalance;
  String? balanceToUsd;
  String? frozenBalanceToUsd;

  BalanceInfo(
      {this.id,
      this.walletId,
      this.currencyId,
      this.availableBalance,
      this.redPacketFrozenBalance,
      this.transferFrozenBalance,
      this.balanceToUsd,
      this.frozenBalanceToUsd});

  BalanceInfo.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    walletId = json['wallet_id'];
    currencyId = json['currency_id'];
    availableBalance = json['available_balance'];
    redPacketFrozenBalance = json['red_packet_frozen_balance'];
    transferFrozenBalance = json['transfer_frozen_balance'];
    balanceToUsd = json['balance_to_usd'];
    frozenBalanceToUsd = json['frozen_balance_to_usd'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['wallet_id'] = this.walletId;
    data['currency_id'] = this.currencyId;
    data['available_balance'] = this.availableBalance;
    data['red_packet_frozen_balance'] = this.redPacketFrozenBalance;
    data['transfer_frozen_balance'] = this.transferFrozenBalance;
    data['balance_to_usd'] = this.balanceToUsd;
    data['frozen_balance_to_usd'] = this.frozenBalanceToUsd;
    return data;
  }
}
