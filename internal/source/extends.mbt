// E0079 显式挂载声明，说明见根包 `extends.mbt`。

///|
pub extend FetchResult with @debug.Debug::{to_repr}

///|
pub extend FetchResult with Eq::{equal, not_equal}

///|
pub extend FetchError with @debug.Debug::{to_repr}
