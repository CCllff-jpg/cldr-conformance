// E0079 显式挂载声明，说明见根包 `extends.mbt`。

///|
pub extend MoonlocaleAdapter with @debug.Debug::{to_repr}

///|
pub extend MoonlocaleAdapter with Eq::{equal, not_equal}

///|
pub extend MoonlocaleAdapter with @conformance.NumberAdapter::{
  name,
  format_number,
}

///|
pub extend MoonlocaleAdapterError with @debug.Debug::{to_repr}
