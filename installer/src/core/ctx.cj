package uc_installer.core

import uc_installer.cli.CliArgs
import uc_installer.util.Logger

/// 进程级共享上下文：解析后的参数、安装路径、状态仓库、日志器。
///
/// 构造一次，贯穿所有 HTTP handler（设计依据：design.md §4.2.2 `buildRouter(paths, ctx)`）。
/// handler 通过闭包捕获 ctx，无需每次请求重建。
///
/// 说明：本类型从 `uc_installer.http` 迁至 `uc_installer.core`，
/// 以打破 `uc_installer.http` ↔ `uc_installer.http.handlers` 的循环包依赖
/// （R-04 衍生的构建约束：跨包反向 import 会被拒绝构建）。
public class AppContext {
    public var args: CliArgs
    public var paths: InstallPaths
    public var state: StateStore
    public var log: Logger

    public init(args!: CliArgs, paths!: InstallPaths, state!: StateStore, log!: Logger) {
        this.args = args
        this.paths = paths
        this.state = state
        this.log = log
    }
}
