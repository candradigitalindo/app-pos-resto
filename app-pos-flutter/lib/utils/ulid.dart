/// ULID generator - 26 character sortable unique ID
/// Compatible with the Go backend ULIDs
class Ulid {
  static String generate() {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch;

    // Encoding characters (Crockford's Base32)
    const encoding = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

    // Encode timestamp (10 chars)
    var ts = timestamp;
    final timeChars = <String>[];
    for (var i = 0; i < 10; i++) {
      timeChars.insert(0, encoding[ts & 0x1f]);
      ts >>= 5;
    }

    // Random part (16 chars)
    final random = DateTime.now().microsecondsSinceEpoch ^ timestamp;
    var r = random;
    final randomChars = <String>[];
    for (var i = 0; i < 16; i++) {
      randomChars.add(encoding[(r + i * 31 + timestamp) & 0x1f]);
      r = (r * 1103515245 + 12345) & 0x7fffffff;
    }

    return '${timeChars.join()}${randomChars.join()}';
  }
}
