
class Captcha {
  String? captcha;
  int? expiration;
  String? id;

  Captcha({this.captcha, this.expiration, this.id});

  Captcha.fromJson(Map<String, dynamic> json) {
    if(json["captcha"] is String) {
      captcha = json["captcha"];
    }
    if(json["expiration"] is int) {
      expiration = json["expiration"];
    }
    if(json["id"] is String) {
      id = json["id"];
    }
  }

  static List<Captcha> fromList(List<Map<String, dynamic>> list) {
    return list.map(Captcha.fromJson).toList();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> _data = <String, dynamic>{};
    _data["captcha"] = captcha;
    _data["expiration"] = expiration;
    _data["id"] = id;
    return _data;
  }
}