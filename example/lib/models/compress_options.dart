/// Top-level compression intent — target size and quality are mutually
/// exclusive (only one drives the encoder).
enum SizeMode { targetSize, quality }

/// Within quality mode, a preset tier and a custom percentage are also
/// mutually exclusive.
enum QualityMode { preset, percent }
