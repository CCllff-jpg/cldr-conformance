// E0079 显式挂载声明，说明见根包 `extends.mbt`。

///|
pub extend EngineConfig with @debug.Debug::{to_repr}

///|
pub extend EngineConfig with Eq::{equal, not_equal}
