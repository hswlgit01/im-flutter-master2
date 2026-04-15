class Urls {
  static const String baseUrl = '/api/v1';
  
  // 钱包相关
  static const String walletCreate = '/api/v1/wallet/create';
  static const String walletExists = '/api/v1/wallet/exists';
  static const String walletBalance = '/api/v1/wallet/balance';
  static const String walletTsRecord = '/api/v1/wallet/ts_record';
  static const String transactionCreate = '/api/v1/transaction/create';
  static const String transactionReceive = '/api/v1/transaction/receive';
  static const String transactionCheckReceived = '/api/v1/transaction/check_received';
  
  // 直播相关
  static const String uploadStreamCover = '/api/v1/stream/cover/upload';
} 