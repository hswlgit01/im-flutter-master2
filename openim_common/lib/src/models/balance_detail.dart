class BalanceDetail {
  String? id;
  String? ownerId;
  String? ownerType;
  String? createdAt;
  String? updatedAt;
  String? totalBalanceUsd;
  List<WalletBalance>? walletBalance;

  BalanceDetail(
      {this.id,
      this.ownerId,
      this.ownerType,
      this.createdAt,
      this.updatedAt,
      this.totalBalanceUsd,
      this.walletBalance});

  BalanceDetail.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    ownerId = json['owner_id'];
    ownerType = json['owner_type'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    totalBalanceUsd = json['total_balance_usd'];
    if (json['wallet_balance'] != null) {
      walletBalance = <WalletBalance>[];
      json['wallet_balance'].forEach((v) {
        walletBalance!.add(new WalletBalance.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['owner_id'] = this.ownerId;
    data['owner_type'] = this.ownerType;
    data['created_at'] = this.createdAt;
    data['updated_at'] = this.updatedAt;
    data['total_balance_usd'] = this.totalBalanceUsd;
    if (this.walletBalance != null) {
      data['wallet_balance'] =
          this.walletBalance!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class WalletBalance {
  String? id;
  String? walletId;
  String? currencyId;
  String? availableBalance;
  String? redPacketFrozenBalance;
  String? transferFrozenBalance;
  String? balanceToUsd;
  String? createdAt;
  String? updatedAt;
  WalletCurrency? walletCurrency;

  WalletBalance(
      {this.id,
      this.walletId,
      this.currencyId,
      this.availableBalance,
      this.redPacketFrozenBalance,
      this.transferFrozenBalance,
      this.balanceToUsd,
      this.createdAt,
      this.updatedAt,
      this.walletCurrency});

  WalletBalance.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    walletId = json['wallet_id'];
    currencyId = json['currency_id'];
    availableBalance = json['available_balance'];
    redPacketFrozenBalance = json['red_packet_frozen_balance'];
    transferFrozenBalance = json['transfer_frozen_balance'];
    balanceToUsd = json['balance_to_usd'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    walletCurrency = json['wallet_currency'] != null
        ? new WalletCurrency.fromJson(json['wallet_currency'])
        : null;
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
    data['created_at'] = this.createdAt;
    data['updated_at'] = this.updatedAt;
    if (this.walletCurrency != null) {
      data['wallet_currency'] = this.walletCurrency!.toJson();
    }
    return data;
  }
}

class WalletCurrency {
  String? id;
  String? name;
  String? icon;
  int? order;
  int? exchangeRate;
  int? minAvailableAmount;
  String? creatorId;
  String? createdAt;
  String? updatedAt;

  WalletCurrency(
      {this.id,
      this.name,
      this.icon,
      this.order,
      this.exchangeRate,
      this.minAvailableAmount,
      this.creatorId,
      this.createdAt,
      this.updatedAt});

  WalletCurrency.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    icon = json['icon'];
    order = _parseInt(json['order']);
    exchangeRate = _parseInt(json['exchange_rate']);
    minAvailableAmount = _parseInt(json['min_available_amount']);
    creatorId = json['creator_id'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
  }
  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['name'] = this.name;
    data['icon'] = this.icon;
    data['order'] = this.order;
    data['exchange_rate'] = this.exchangeRate;
    data['min_available_amount'] = this.minAvailableAmount;
    data['creator_id'] = this.creatorId;
    data['created_at'] = this.createdAt;
    data['updated_at'] = this.updatedAt;
    return data;
  }
}
