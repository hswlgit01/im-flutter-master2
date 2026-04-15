class OrgListData {
  int? total;
  List<OrgData>? data;

  OrgListData({this.total, this.data});

  OrgListData.fromJson(Map<String, dynamic> json) {
    total = json['total'];
    if (json['data'] != null) {
      data = <OrgData>[];
      json['data'].forEach((v) {
        data!.add(new OrgData.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['total'] = this.total;
    if (this.data != null) {
      data['data'] = this.data!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class OrgData {
  String? id;
  String? organizationId;
  String? thirdUserId;
  String? userId;
  String? role;
  String? status;
  Organization? organization;
  String? createdAt;
  String? updatedAt;

  OrgData(
      {this.id,
      this.organizationId,
      this.thirdUserId,
      this.userId,
      this.role,
      this.status,
      this.organization,
      this.createdAt,
      this.updatedAt});

  OrgData.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    organizationId = json['organization_id'];
    thirdUserId = json['third_user_id'];
    userId = json['user_id'];
    role = json['role'];
    status = json['status'];
    organization = json['organization'] != null
        ? new Organization.fromJson(json['organization'])
        : null;
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['organization_id'] = this.organizationId;
    data['third_user_id'] = this.thirdUserId;
    data['user_id'] = this.userId;
    data['role'] = this.role;
    data['status'] = this.status;
    if (this.organization != null) {
      data['organization'] = this.organization!.toJson();
    }
    data['created_at'] = this.createdAt;
    data['updated_at'] = this.updatedAt;
    return data;
  }
}

class Organization {
  String? id;
  String? name;
  String? type;
  String? email;
  String? phone;
  String? description;
  String? contacts;
  String? invitationCode;
  String? creatorId;
  String? status;
  String? logo;
  String? createdAt;
  String? updatedAt;

  Organization(
      {this.id,
      this.name,
      this.type,
      this.email,
      this.phone,
      this.description,
      this.contacts,
      this.invitationCode,
      this.creatorId,
      this.status,
      this.logo,
      this.createdAt,
      this.updatedAt});

  Organization.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    type = json['type'];
    email = json['email'];
    phone = json['phone'];
    description = json['description'];
    contacts = json['contacts'];
    invitationCode = json['invitation_code'];
    creatorId = json['creator_id'];
    status = json['status'];
    logo = json['logo'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['name'] = this.name;
    data['type'] = this.type;
    data['email'] = this.email;
    data['phone'] = this.phone;
    data['description'] = this.description;
    data['contacts'] = this.contacts;
    data['invitation_code'] = this.invitationCode;
    data['creator_id'] = this.creatorId;
    data['status'] = this.status;
    data['logo'] = this.logo;
    data['created_at'] = this.createdAt;
    data['updated_at'] = this.updatedAt;
    return data;
  }
}
