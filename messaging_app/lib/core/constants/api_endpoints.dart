class ApiEndpoints {
  static const String register = '/auth/register';
  static const String sendOtp = '/auth/send-otp';
  static const String verifyOtp = '/auth/verify-otp';
  static const String registerWithOtp = '/auth/register-with-otp';
  static const String login = '/auth/login';
  static const String phoneLogin = '/auth/phone-login';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String logoutAll = '/auth/logout-all';
  static const String me = '/auth/me';
  static const String profile = '/users/me';


  // Future endpoints
  static const String userSearch = '/users/search';
  static const String conversations = '/conversations';
  static const String messages = '/messages';
}
