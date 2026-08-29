///|
/// Errors raised while decoding the LunaChip canonical IR text format.
///
/// Line numbers are one-based. `NonCanonical` means the document could be
/// decoded, but its bytes were not the one canonical encoding of that design.
pub(all) suberror CodecError {
  UnexpectedEnd(expected~ : String)
  UnexpectedLine(line~ : Int, expected~ : String, actual~ : String)
  UnsupportedVersion(String)
  InvalidInteger(line~ : Int, field~ : String, value~ : String)
  InvalidEncodedName(line~ : Int, value~ : String)
  InvalidUtf8Name(line~ : Int)
  InvalidCount(line~ : Int, field~ : String, value~ : Int)
  IrRejected(reason~ : String)
  NonCanonical
} derive(Debug, Eq)

///|
/// A deterministic 64-bit content digest of canonical IR bytes.
///
/// The bootstrap algorithm is FNV-1a-64. It is suitable for cache keys,
/// reproducibility checks, and golden fixtures, but is not cryptographic and
/// must not be used as a signature or adversarial collision boundary.
pub struct ContentDigest64(UInt64) derive(Debug, Eq, Compare)

///|
/// Return the raw unsigned digest value.
pub fn ContentDigest64::value(self : ContentDigest64) -> UInt64 {
  let ContentDigest64(value) = self
  value
}

///|
/// Return the fixed-width, lowercase hexadecimal digest.
pub fn ContentDigest64::to_hex(self : ContentDigest64) -> String {
  let raw = self.value().to_string(radix=16)
  let builder = StringBuilder()
  for _ in 0..<(16 - raw.length()) {
    builder.write_char('0')
  }
  builder.write_string(raw)
  builder.to_string()
}

///|
/// Return the stable name of the bootstrap digest algorithm.
pub fn ContentDigest64::algorithm(self : ContentDigest64) -> String {
  ignore(self)
  "fnv1a-64"
}
