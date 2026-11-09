/// Lets `copyWith` distinguish "leave unchanged" (null argument) from
/// "set to null" (a closure that returns null).
///
/// Usage: `invoice.copyWith(vendorName: () => null)` clears the field.
typedef Nullable<T> = T? Function();
