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
pub extend DecimalCase with @debug.Debug::{to_repr}

///|
pub extend DecimalCase with Eq::{equal, not_equal}

///|
pub extend DecimalCorpus with @debug.Debug::{to_repr}

///|
pub extend DecimalCorpus with Eq::{equal, not_equal}
