// E0079 显式挂载声明，说明见根包 `extends.mbt`。

///|
pub extend ReferenceNull with @debug.Debug::{to_repr}

///|
pub extend ReferenceNull with Eq::{equal, not_equal}

///|
pub extend ReferenceNull with @conformance.FormatUnderTest::{
  name,
  format_number,
}
