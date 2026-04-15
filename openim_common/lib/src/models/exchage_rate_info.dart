class ExchageRateInfo {
  String? base;
  int? timestamp;
  Rates? rates;

  ExchageRateInfo({this.base, this.timestamp, this.rates});

  ExchageRateInfo.fromJson(Map<String, dynamic> json) {
    base = json['base'];
    timestamp = json['timestamp'];
    rates = json['rates'] != null ? new Rates.fromJson(json['rates']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['base'] = this.base;
    data['timestamp'] = this.timestamp;
    if (this.rates != null) {
      data['rates'] = this.rates!.toJson();
    }
    return data;
  }
}

class Rates {
  Map<String, dynamic>? rates;

  Rates({this.rates});

  Rates.fromJson(Map<String, dynamic> json) {
    rates = json;
  }

  Map<String, dynamic> toJson() {
    return rates ?? {};
  }
}
