class Validators {
  Validators._();

  static bool isValidEmail(String value) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());

  static bool isValidRoomCode(String value) => RegExp(r'^\d{6}$').hasMatch(value.replaceAll('-', ''));
}