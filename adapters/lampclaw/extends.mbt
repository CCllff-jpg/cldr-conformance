// E0079 显式挂载声明，说明见根包 `extends.mbt`。

///|
pub extend LampclawMf2Adapter with @debug.Debug::{to_repr}

///|
pub extend LampclawMf2Adapter with Eq::{equal, not_equal}

///|
pub extend LampclawMf2Adapter with @conformance.MessageFormat2Adapter::{
  name,
  format_message,
}

///|
pub extend LampclawMf2AdapterError with @debug.Debug::{to_repr}
