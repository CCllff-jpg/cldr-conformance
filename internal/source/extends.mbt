// E0079 显式挂载声明，说明见根包 `extends.mbt`。

///|
pub extend FetchResult with @debug.Debug::{to_repr}

///|
pub extend FetchResult with Eq::{equal, not_equal}

///|
pub extend FetchError with @debug.Debug::{to_repr}

///|
pub extend Tier with @debug.Debug::{to_repr}

///|
pub extend Tier with Eq::{equal, not_equal}

///|
pub extend SourceFile with @debug.Debug::{to_repr}

///|
pub extend SourceFile with Eq::{equal, not_equal}

///|
pub extend Manifest with @debug.Debug::{to_repr}

///|
pub extend Manifest with Eq::{equal, not_equal}

///|
pub extend SourceError with @debug.Debug::{to_repr}

///|
pub extend VerifyOutcome with @debug.Debug::{to_repr}

///|
pub extend VerifyOutcome with Eq::{equal, not_equal}

///|
pub extend VerifyEntry with @debug.Debug::{to_repr}

///|
pub extend VerifyEntry with Eq::{equal, not_equal}

///|
pub extend Tier with ToJson::{to_json}

///|
pub extend Tier with @json.FromJson::{from_json}

///|
pub extend SourceFile with ToJson::{to_json}

///|
pub extend SourceFile with @json.FromJson::{from_json}

///|
pub extend Manifest with ToJson::{to_json}

///|
pub extend Manifest with @json.FromJson::{from_json}

///|
pub extend RetryPolicy with @debug.Debug::{to_repr}

///|
pub extend RetryPolicy with Eq::{equal, not_equal}

///|
pub extend CatalogEntry with @debug.Debug::{to_repr}

///|
pub extend CatalogEntry with Eq::{equal, not_equal}

///|
pub extend SyncOutcome with @debug.Debug::{to_repr}

///|
pub extend SyncOutcome with Eq::{equal, not_equal}

///|
pub extend SyncEntry with @debug.Debug::{to_repr}

///|
pub extend SyncEntry with Eq::{equal, not_equal}
