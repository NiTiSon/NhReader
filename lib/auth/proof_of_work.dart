import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Finds a nonce whose SHA-256 hash has [difficulty] leading zero bits.
///
/// This is the exact scheme nhentai's web app uses for `/api/v2/pow`:
/// SHA-256(challenge + nonce.toString()), nonce starting at 0. Run it in an
/// isolate — at the live difficulty (17) it takes a noticeable amount of CPU.
String solveProofOfWork(String challenge, int difficulty) {
  for (var nonce = 0; ; nonce++) {
    final hash = sha256.convert(utf8.encode('$challenge$nonce')).bytes;
    if (_hasLeadingZeroBits(hash, difficulty)) return nonce.toString();
  }
}

bool _hasLeadingZeroBits(List<int> hash, int bits) {
  if (bits > hash.length * 8) return false;
  final fullBytes = bits ~/ 8;
  for (var i = 0; i < fullBytes; i++) {
    if (hash[i] != 0) return false;
  }
  final remainingBits = bits % 8;
  if (remainingBits == 0) return true;
  final mask = (0xFF << (8 - remainingBits)) & 0xFF;
  return (hash[fullBytes] & mask) == 0;
}
