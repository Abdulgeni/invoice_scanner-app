/// Injected time source so domain logic never calls `DateTime.now`.
/// Implementations must return UTC.
typedef Clock = DateTime Function();

/// Injected id source. Each call returns a new UUID v4 string.
typedef IdGenerator = String Function();
