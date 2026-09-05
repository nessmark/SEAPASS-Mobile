class ManilaClock {
  static String toQueryDate(DateTime date) {
    return date.toIso8601String().split('T').first;
  }
}
