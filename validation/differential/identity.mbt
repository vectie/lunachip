///|
/// Identity shared by a stimulus artifact and every result derived from it.
/// `design_sha256` is exactly 64 lowercase hexadecimal digits.
pub struct DesignIdentity {
  semantic_version : String
  design_sha256 : String
} derive(Debug, Eq)

///|
pub(all) enum DigestKind {
  DesignArtifactSha256
  StimulusArtifactSha256
} derive(Debug, Eq)

///|
fn validate_digest(
  kind : DigestKind,
  digest : String,
) -> Unit raise DifferentialError {
  if digest.length() != 64 {
    raise InvalidDigestLength(kind~, length=digest.length())
  }
  for index in 0..<digest.length() {
    let symbol = digest[index]
    let valid = (symbol >= '0' && symbol <= '9') ||
      (symbol >= 'a' && symbol <= 'f')
    if !valid {
      raise InvalidDigestSymbol(kind~, index~, symbol~)
    }
  }
}

///|
pub fn DesignIdentity::checked(
  semantic_version : String,
  design_sha256 : String,
) -> DesignIdentity raise DifferentialError {
  if semantic_version.length() == 0 {
    raise EmptySemanticVersion
  }
  validate_digest(DesignArtifactSha256, design_sha256)
  { semantic_version, design_sha256 }
}

///|
pub fn DesignIdentity::semantic_version(self : DesignIdentity) -> String {
  self.semantic_version
}

///|
pub fn DesignIdentity::design_sha256(self : DesignIdentity) -> String {
  self.design_sha256
}

///|
/// Identity attached to a normalized result artifact. `stimulus_sha256` is the
/// fixed lowercase SHA-256 of the stimulus bytes and remains external to those
/// bytes themselves, avoiding a recursive digest.
pub struct ResultIdentity {
  design : DesignIdentity
  stimulus_sha256 : String
} derive(Debug, Eq)

///|
pub fn ResultIdentity::checked(
  design : DesignIdentity,
  stimulus_sha256 : String,
) -> ResultIdentity raise DifferentialError {
  validate_digest(StimulusArtifactSha256, stimulus_sha256)
  { design, stimulus_sha256 }
}

///|
pub fn ResultIdentity::design(self : ResultIdentity) -> DesignIdentity {
  self.design
}

///|
pub fn ResultIdentity::stimulus_sha256(self : ResultIdentity) -> String {
  self.stimulus_sha256
}

///|
/// Stable fields checked before any observation is compared.
pub(all) enum IdentityField {
  SemanticVersion
  DesignSha256
  StimulusSha256
} derive(Debug, Eq)
