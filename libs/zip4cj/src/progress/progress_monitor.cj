/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.progress

public enum ProgressMonitorState <: Equatable<ProgressMonitorState> & ToString{
    | READY
    | BUSY

    public operator func ==(that: ProgressMonitorState): Bool {
        return match ((this, that)) {
            case (READY, READY) => true
            case (BUSY, BUSY) => true
            case _ => false
        }
    }

    public operator func !=(that: ProgressMonitorState): Bool {
        !(this == that)
    }

    public func toString(): String {
        return match(this) {
            case READY => "READY"
            case BUSY => "BUSY"
        }
    }

}

public enum ProgressMonitorResult {
    | SUCCESS
    | WORK_IN_PROGRESS
    | ERROR
    | CANCELLED
}

public enum ProgressMonitorTask {
    | NONE
    | ADD_ENTRY
    | REMOVE_ENTRY
    | CALCULATE_CRC
    | EXTRACT_ENTRY
    | MERGE_ZIP_FILES
    | SET_COMMENT
    | RENAME_FILE
}
/* 
 *  If Zip4j is set to run in thread mode, this class helps retrieve current progress
 */
public class ProgressMonitor {
    public var state: ProgressMonitorState
    private var currentTask: ProgressMonitorTask
    private var totalWork: Int64 = 0
    private var workCompleted: Int64 = 0
    private var percentDone: Int32 = 0
    private var fileName: ?String = None
    private var result: ProgressMonitorResult = SUCCESS
    private var exception: ?Exception = None
    private var cancelAllTasks: Bool = false
    private var pause: Bool = false

    public init() {
        currentTask = ProgressMonitorTask.NONE
        state = ProgressMonitorState.READY
    }

    @OverflowWrapping
    public func updateWorkCompleted(workCompleted: Int64): Unit {
        this.workCompleted += workCompleted
        if (totalWork > 0) {
            percentDone = Int32(this.workCompleted * 100 / totalWork)
            if (percentDone > 100) {
                percentDone = 100
            }
        }
    }

    public func endProgressMonitor(): Unit {
        result = ProgressMonitorResult.SUCCESS
        percentDone = 100
        reset()
    }

    public func endProgressMonitor(e: Exception) {
        result = ProgressMonitorResult.ERROR
        exception = e
        reset()
    }

    public func fullReset(): Unit {
        reset()
        fileName = None
        totalWork = 0
        workCompleted = 0
        percentDone = 0
    }

    private func reset(): Unit {
        currentTask = ProgressMonitorTask.NONE
        state = ProgressMonitorState.READY
    }

    public func getState(): ProgressMonitorState {
        return state
    }

    public func setState(state: ProgressMonitorState): Unit {
        this.state = state
    }

    public func setTotalWork(totalWork: Int64): Unit {
        this.totalWork = totalWork
    }

    public func getPercentDone(): Int32 {
        return percentDone
    }

    public func getCurrentTask(): ProgressMonitorTask {
        return currentTask
    }

    public func setCurrentTask(currentTask: ProgressMonitorTask): Unit {
        this.currentTask = currentTask
    }

    public func getFileName(): String {
        return fileName.getOrThrow()
    }

    public func setFileName(fileName: String): Unit {
        this.fileName = fileName
    }

    public func getResult(): ProgressMonitorResult {
        return result
    }

    public func setResult(result: ProgressMonitorResult): Unit {
        this.result = result
    }

    public func getException(): Exception {
        return exception.getOrThrow()
    }

    public func setException(exception: Exception): Unit {
        this.exception = exception
    }

    public func isCancelAllTasks(): Bool {
        return cancelAllTasks
    }

    public func setCancelAllTasks(cancelAllTasks: Bool) {
        this.cancelAllTasks = cancelAllTasks
    }

    public func isPause(): Bool {
        return pause
    }

    public func setPause(pause: Bool) {
        this.pause = pause
    }
}
