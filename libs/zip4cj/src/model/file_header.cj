/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.model

public class FileHeader <: AbstractFileHeader & ToString & Hashable & Equatable<FileHeader> {
    private var versionMadeBy: Int32 = 0

    private var fileCommentLength: Int32 = 0

    private var diskNumberStart: Int64 = 0

    private var internalFileAttributes: ?Array<Byte> = None

    private var externalFileAttributes: ?Array<Byte> = None

    private var offsetLocalHeader: Int64 = 0

    private var fileComment: ?String = None

    public init() {
        setSignature(HeaderSignature.CENTRAL_DIRECTORY)
    }

    public func getVersionMadeBy(): Int32 {
        return versionMadeBy
    }

    public func setVersionMadeBy(versionMadeBy: Int32): Unit {
        this.versionMadeBy = versionMadeBy
    }

    public func getFileCommentLength(): Int32 {
        return fileCommentLength
    }

    public func setFileCommentLength(fileCommentLength: Int32): Unit {
        this.fileCommentLength = fileCommentLength
    }

    public func getDiskNumberStart(): Int64 {
        return diskNumberStart
    }

    public func setDiskNumberStart(diskNumberStart: Int64): Unit {
        this.diskNumberStart = diskNumberStart
    }

    public func getInternalFileAttributes(): ?Array<Byte> {
        return internalFileAttributes
    }

    public func setInternalFileAttributes(internalFileAttributes: Array<Byte>): Unit {
        this.internalFileAttributes = internalFileAttributes
    }

    public func getExternalFileAttributes(): ?Array<Byte> {
        return externalFileAttributes
    }

    public func setExternalFileAttributes(externalFileAttributes: ?Array<Byte>): Unit {
        this.externalFileAttributes = externalFileAttributes
    }

    public func getOffsetLocalHeader(): Int64 {
        return offsetLocalHeader
    }

    public func setOffsetLocalHeader(offsetLocalHeader: Int64): Unit {
        this.offsetLocalHeader = offsetLocalHeader
    }

    public func getFileComment(): ?String {
        return fileComment
    }

    public func setFileComment(fileComment: ?String): Unit {
        this.fileComment = fileComment
    }

    public override func toString(): String {
        return getFileName().toString()
    }

    public operator func ==(that: FileHeader): Bool {
        return equals(that)
    }

    public operator func !=(that: FileHeader): Bool {
        return !(this == that)
    }

    public func equals(that: FileHeader): Bool {
        if (refEq(this, that)) {
            return true
        }
        if (!super.equals(that)) {
            return false
        }
        return determineOffsetOfLocalFileHeader(this) == determineOffsetOfLocalFileHeader(that)
    }

    public override func hashCode(): Int64 {
        var result: Int64 = 1
        result = 31 * result + getFileName().hashCode()
        result = 31 * result + determineOffsetOfLocalFileHeader(this).hashCode()
        return result
    }

    private func determineOffsetOfLocalFileHeader(fileHeader: FileHeader): Int64 {
        if (fileHeader.getZip64ExtendedInfo() != None) {
            return fileHeader.getZip64ExtendedInfo().getOrThrow().getOffsetLocalHeader()
        }
        return fileHeader.getOffsetLocalHeader()
    }
}
