// E0079（implicit_impl_as_method）迁移声明。
//
// `derive(Debug, Eq)` 生成的 impl 会把方法隐式挂到类型上，新工具链要求显式声明
// （`moon explain --diagnostics implicit_impl_as_method`）。本文件集中放置这些声明，
// 与标准库的做法一致（见 core/*/extends.mbt），避免散落到各个源文件里。

///|
pub extend Suite with @debug.Debug::{to_repr}

///|
pub extend Suite with Eq::{equal, not_equal}

///|
pub extend NumberStyle with @debug.Debug::{to_repr}

///|
pub extend NumberStyle with Eq::{equal, not_equal}

///|
pub extend NumberLength with @debug.Debug::{to_repr}

///|
pub extend NumberLength with Eq::{equal, not_equal}

///|
pub extend FailReason with @debug.Debug::{to_repr}

///|
pub extend FailReason with Eq::{equal, not_equal}

///|
pub extend CaseOutcome with @debug.Debug::{to_repr}

///|
pub extend CaseOutcome with Eq::{equal, not_equal}

///|
pub extend AdapterCapability with @debug.Debug::{to_repr}

///|
pub extend AdapterCapability with Eq::{equal, not_equal}

///|
pub extend AdapterCapabilities with @debug.Debug::{to_repr}

///|
pub extend AdapterCapabilities with Eq::{equal, not_equal}

///|
pub extend DatetimeFormatInput with @debug.Debug::{to_repr}

///|
pub extend DatetimeFormatInput with Eq::{equal, not_equal}

///|
pub extend MessageFormat2Input with @debug.Debug::{to_repr}

///|
pub extend MessageFormat2Input with Eq::{equal, not_equal}

///|
pub extend MessageFormat2Result with @debug.Debug::{to_repr}

///|
pub extend MessageFormat2Result with Eq::{equal, not_equal}

///|
pub extend DecimalCase with @debug.Debug::{to_repr}

///|
pub extend DecimalCase with Eq::{equal, not_equal}

///|
pub extend DecimalCorpus with @debug.Debug::{to_repr}

///|
pub extend DecimalCorpus with Eq::{equal, not_equal}

///|
pub extend SkeletonCase with @debug.Debug::{to_repr}

///|
pub extend SkeletonCase with Eq::{equal, not_equal}

///|
pub extend DatetimeCase with @debug.Debug::{to_repr}

///|
pub extend DatetimeCase with Eq::{equal, not_equal}

///|
pub extend DatetimeCorpus with @debug.Debug::{to_repr}

///|
pub extend DatetimeCorpus with Eq::{equal, not_equal}

///|
pub extend MessageCase with @debug.Debug::{to_repr}

///|
pub extend MessageCase with Eq::{equal, not_equal}

///|
pub extend MessageCorpus with @debug.Debug::{to_repr}

///|
pub extend MessageCorpus with Eq::{equal, not_equal}

///|
pub extend CaseResult with @debug.Debug::{to_repr}

///|
pub extend CaseResult with Eq::{equal, not_equal}

///|
pub extend RunSummary with @debug.Debug::{to_repr}

///|
pub extend RunSummary with Eq::{equal, not_equal}

///|
pub extend CharDiff with @debug.Debug::{to_repr}

///|
pub extend CharDiff with Eq::{equal, not_equal}

///|
pub extend SuiteSummary with @debug.Debug::{to_repr}

///|
pub extend SuiteSummary with Eq::{equal, not_equal}

///|
pub extend ReasonCount with @debug.Debug::{to_repr}

///|
pub extend ReasonCount with Eq::{equal, not_equal}

///|
pub extend FailureDetail with @debug.Debug::{to_repr}

///|
pub extend FailureDetail with Eq::{equal, not_equal}

///|
pub extend ErrorDetail with @debug.Debug::{to_repr}

///|
pub extend ErrorDetail with Eq::{equal, not_equal}

///|
pub extend AdapterReport with @debug.Debug::{to_repr}

///|
pub extend AdapterReport with Eq::{equal, not_equal}

///|
pub extend Report with @debug.Debug::{to_repr}

///|
pub extend Report with Eq::{equal, not_equal}

///|
pub extend PluralCase with @debug.Debug::{to_repr}

///|
pub extend PluralCase with Eq::{equal, not_equal}

///|
pub extend PluralCorpus with @debug.Debug::{to_repr}

///|
pub extend PluralCorpus with Eq::{equal, not_equal}

///|
pub extend Disagreement with @debug.Debug::{to_repr}

///|
pub extend Disagreement with Eq::{equal, not_equal}
