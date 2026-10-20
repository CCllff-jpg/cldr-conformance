// E0079 显式挂载声明，说明见根包 `extends.mbt`。

///|
pub extend MoonL10nPluralAdapter with @debug.Debug::{to_repr}

///|
pub extend MoonL10nPluralAdapter with Eq::{equal, not_equal}

///|
pub extend MoonL10nPluralAdapter with @conformance.PluralAdapter::{
  name,
  plural_category,
}

///|
pub extend MoonL10nPluralAdapterError with @debug.Debug::{to_repr}
