///|
/// Serialized adapter contract. This describes the reference accelerator, not
/// the currently programmed image or evidence of full-model execution.
pub fn device_contract_json() -> String {
  let manifest = default_manifest()
  let value : Json = {
    "schema": "lunachip.pblaze3-device/v1",
    "target": manifest.target,
    "control_abi": manifest.abi_version,
    "device_id": 1346515760,
    "ddr_bytes": manifest.capacity_bytes,
    "descriptor_words": 16,
    "program_descriptors": 2048,
    "scratch_words": 32768,
    "vector_limit": 4096,
    "matrix_k_multiple": 64,
    "matrix_alignment_bytes": 128,
    "numeric_profile": "qwen-layer-ordered-fp32-approx-v1",
    "weight_layout": "bf16-row-major-or-packed16-v1",
  }
  value.stringify(indent=2) + "\n"
}
