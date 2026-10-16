// E0079 显式挂载声明，说明见根包 `extends.mbt`。

///|
pub extend EngineConfig with @debug.Debug::{to_repr}

///|
pub extend EngineConfig with Eq::{equal, not_equal}

///|
pub extend AttributionContext with @debug.Debug::{to_repr}

///|
pub extend AttributionContext with Eq::{equal, not_equal}

///|
pub extend MutationKind with @debug.Debug::{to_repr}

///|
pub extend MutationKind with Eq::{equal, not_equal}

///|
pub extend MutationOutcome with @debug.Debug::{to_repr}

///|
pub extend MutationOutcome with Eq::{equal, not_equal}

///|
pub extend CompoundOutcome with @debug.Debug::{to_repr}

///|
pub extend CompoundOutcome with Eq::{equal, not_equal}
