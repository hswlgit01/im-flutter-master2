import 'package:openim_common/openim_common.dart';

class NotifyContent {
  String notificationName;
  String notificationFaceURL;
  int notificationType;
  String text;
  String externalUrl;
  int mixType;
  NotifyPictureElem pictureElem;
  NotifySoundElem soundElem;
  NotifyVideoElem videoElem;
  NotifyFileElem fileElem;
  NotifyBannerElem bannerElem;
  RefundDataDetails? refundElem;
  String ex;

  NotifyContent({
    required this.notificationName,
    required this.notificationFaceURL,
    required this.notificationType,
    required this.text,
    required this.externalUrl,
    required this.mixType,
    required this.pictureElem,
    required this.soundElem,
    required this.videoElem,
    required this.fileElem,
    required this.bannerElem,
    this.refundElem,
    required this.ex,
  });

  factory NotifyContent.fromJson(Map<String, dynamic> json) {
    var refundElemMap = json['refundElem'];
    RefundDataDetails? refundElem;
    if (refundElemMap != null) {
      refundElem = RefundDataDetails.fromJson(json['refundElem']);
    }
    return NotifyContent(
      notificationName: json['notificationName'] ?? '',
      notificationFaceURL: json['notificationFaceURL'] ?? '',
      notificationType: json['notificationType'] ?? 0,
      text: json['text'] ?? '',
      externalUrl: json['externalUrl'] ?? '',
      mixType: json['mixType'] ?? 0,
      pictureElem: NotifyPictureElem.fromJson(json['pictureElem'] ?? {}),
      soundElem: NotifySoundElem.fromJson(json['soundElem'] ?? {}),
      videoElem: NotifyVideoElem.fromJson(json['videoElem'] ?? {}),
      fileElem: NotifyFileElem.fromJson(json['fileElem'] ?? {}),
      bannerElem: NotifyBannerElem.fromJson(json['bannerElem'] ?? {}),
      refundElem: refundElem,
      ex: json['ex'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'notificationName': notificationName,
      'notificationFaceURL': notificationFaceURL,
      'notificationType': notificationType,
      'text': text,
      'externalUrl': externalUrl,
      'mixType': mixType,
      'pictureElem': pictureElem.toJson(),
      'soundElem': soundElem.toJson(),
      'videoElem': videoElem.toJson(),
      'fileElem': fileElem.toJson(),
      'bannerElem': bannerElem.toJson(),
      'ex': ex,
    };
  }
}

class NotifyPictureElem {
  String sourcePath;
  NotifyPicture sourcePicture;
  NotifyPicture bigPicture;
  NotifyPicture snapshotPicture;

  NotifyPictureElem({
    required this.sourcePath,
    required this.sourcePicture,
    required this.bigPicture,
    required this.snapshotPicture,
  });

  factory NotifyPictureElem.fromJson(Map<String, dynamic> json) {
    return NotifyPictureElem(
      sourcePath: json['sourcePath'] ?? '',
      sourcePicture: NotifyPicture.fromJson(json['sourcePicture'] ?? {}),
      bigPicture: NotifyPicture.fromJson(json['bigPicture'] ?? {}),
      snapshotPicture: NotifyPicture.fromJson(json['snapshotPicture'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sourcePath': sourcePath,
      'sourcePicture': sourcePicture.toJson(),
      'bigPicture': bigPicture.toJson(),
      'snapshotPicture': snapshotPicture.toJson(),
    };
  }
}

class NotifyPicture {
  String uuid;
  String type;
  int size;
  int width;
  int height;
  String url;

  NotifyPicture({
    required this.uuid,
    required this.type,
    required this.size,
    required this.width,
    required this.height,
    required this.url,
  });

  factory NotifyPicture.fromJson(Map<String, dynamic> json) {
    return NotifyPicture(
      uuid: json['uuid'] ?? '',
      type: json['type'] ?? '',
      size: json['size'] ?? 0,
      width: json['width'] ?? 0,
      height: json['height'] ?? 0,
      url: json['url'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'type': type,
      'size': size,
      'width': width,
      'height': height,
      'url': url,
    };
  }
}

class NotifySoundElem {
  String uuid;
  String soundPath;
  String sourceUrl;
  int dataSize;
  int duration;

  NotifySoundElem({
    required this.uuid,
    required this.soundPath,
    required this.sourceUrl,
    required this.dataSize,
    required this.duration,
  });

  factory NotifySoundElem.fromJson(Map<String, dynamic> json) {
    return NotifySoundElem(
      uuid: json['uuid'] ?? '',
      soundPath: json['soundPath'] ?? '',
      sourceUrl: json['sourceUrl'] ?? '',
      dataSize: json['dataSize'] ?? 0,
      duration: json['duration'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'soundPath': soundPath,
      'sourceUrl': sourceUrl,
      'dataSize': dataSize,
      'duration': duration,
    };
  }
}

class NotifyVideoElem {
  String videoPath;
  String videoUUID;
  String videoUrl;
  String videoType;
  int videoSize;
  int duration;
  String snapshotPath;
  String snapshotUUID;
  int snapshotSize;
  String snapshotUrl;
  int snapshotWidth;
  int snapshotHeight;

  NotifyVideoElem({
    required this.videoPath,
    required this.videoUUID,
    required this.videoUrl,
    required this.videoType,
    required this.videoSize,
    required this.duration,
    required this.snapshotPath,
    required this.snapshotUUID,
    required this.snapshotSize,
    required this.snapshotUrl,
    required this.snapshotWidth,
    required this.snapshotHeight,
  });

  factory NotifyVideoElem.fromJson(Map<String, dynamic> json) {
    return NotifyVideoElem(
      videoPath: json['videoPath'] ?? '',
      videoUUID: json['videoUUID'] ?? '',
      videoUrl: json['videoUrl'] ?? '',
      videoType: json['videoType'] ?? '',
      videoSize: json['videoSize'] ?? 0,
      duration: json['duration'] ?? 0,
      snapshotPath: json['snapshotPath'] ?? '',
      snapshotUUID: json['snapshotUUID'] ?? '',
      snapshotSize: json['snapshotSize'] ?? 0,
      snapshotUrl: json['snapshotUrl'] ?? '',
      snapshotWidth: json['snapshotWidth'] ?? 0,
      snapshotHeight: json['snapshotHeight'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'videoPath': videoPath,
      'videoUUID': videoUUID,
      'videoUrl': videoUrl,
      'videoType': videoType,
      'videoSize': videoSize,
      'duration': duration,
      'snapshotPath': snapshotPath,
      'snapshotUUID': snapshotUUID,
      'snapshotSize': snapshotSize,
      'snapshotUrl': snapshotUrl,
      'snapshotWidth': snapshotWidth,
      'snapshotHeight': snapshotHeight,
    };
  }
}

class NotifyFileElem {
  String filePath;
  String uuid;
  String sourceUrl;
  String fileName;
  int fileSize;

  NotifyFileElem({
    required this.filePath,
    required this.uuid,
    required this.sourceUrl,
    required this.fileName,
    required this.fileSize,
  });

  factory NotifyFileElem.fromJson(Map<String, dynamic> json) {
    return NotifyFileElem(
      filePath: json['filePath'] ?? '',
      uuid: json['uuid'] ?? '',
      sourceUrl: json['sourceUrl'] ?? '',
      fileName: json['fileName'] ?? '',
      fileSize: json['fileSize'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'filePath': filePath,
      'uuid': uuid,
      'sourceUrl': sourceUrl,
      'fileName': fileName,
      'fileSize': fileSize,
    };
  }
}

class NotifyBannerElem {
  String description;
  String externalUrl;
  String imageUrl;
  String title;
  String articleId;

  NotifyBannerElem({
    required this.description,
    required this.externalUrl,
    required this.imageUrl,
    required this.title,
    required this.articleId,
  });

  factory NotifyBannerElem.fromJson(Map<String, dynamic> json) {
    return NotifyBannerElem(
      description: json['description'] ?? '',
      externalUrl: json['external_url'] ?? '',
      imageUrl: json['image_url'] ?? '',
      title: json['title'] ?? '',
      articleId: json['article_id'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'external_url': externalUrl,
      'image_url': imageUrl,
      'title': title,
      'article_id': articleId,
    };
  }
}
