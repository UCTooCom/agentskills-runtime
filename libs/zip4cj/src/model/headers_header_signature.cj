/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.model

public enum HeaderSignature <: Equatable<HeaderSignature> {
    | LOCAL_FILE_HEADER
    | EXTRA_DATA_RECORD
    | CENTRAL_DIRECTORY
    | END_OF_CENTRAL_DIRECTORY
    | TEMPORARY_SPANNING_MARKER
    | DIGITAL_SIGNATURE
    | ARCEXTDATREC
    | SPLIT_ZIP
    | ZIP64_END_CENTRAL_DIRECTORY_LOCATOR
    | ZIP64_END_CENTRAL_DIRECTORY_RECORD
    | ZIP64_EXTRA_FIELD_SIGNATURE
    | AES_EXTRA_DATA_RECORD

    public operator func !=(that: HeaderSignature): Bool {
        return !(this == that)
    }

    public operator func ==(that: HeaderSignature): Bool {
        return match ((this, that)) {
            case (LOCAL_FILE_HEADER, LOCAL_FILE_HEADER) => true
            case (EXTRA_DATA_RECORD, EXTRA_DATA_RECORD) => true
            case (CENTRAL_DIRECTORY, CENTRAL_DIRECTORY) => true
            case (END_OF_CENTRAL_DIRECTORY, END_OF_CENTRAL_DIRECTORY) => true
            case (TEMPORARY_SPANNING_MARKER, TEMPORARY_SPANNING_MARKER) => true
            case (DIGITAL_SIGNATURE, DIGITAL_SIGNATURE) => true
            case (ARCEXTDATREC, ARCEXTDATREC) => true
            case (SPLIT_ZIP, SPLIT_ZIP) => true
            case (ZIP64_END_CENTRAL_DIRECTORY_LOCATOR, ZIP64_END_CENTRAL_DIRECTORY_LOCATOR) => true
            case (ZIP64_END_CENTRAL_DIRECTORY_RECORD, ZIP64_END_CENTRAL_DIRECTORY_RECORD) => true
            case (ZIP64_EXTRA_FIELD_SIGNATURE, ZIP64_EXTRA_FIELD_SIGNATURE) => true
            case (AES_EXTRA_DATA_RECORD, AES_EXTRA_DATA_RECORD) => true
            case _ => false
        }
    }

    public static func values(): Array<HeaderSignature> {
        [
            LOCAL_FILE_HEADER,
            EXTRA_DATA_RECORD,
            CENTRAL_DIRECTORY,
            END_OF_CENTRAL_DIRECTORY,
            TEMPORARY_SPANNING_MARKER,
            DIGITAL_SIGNATURE,
            ARCEXTDATREC,
            SPLIT_ZIP,
            ZIP64_END_CENTRAL_DIRECTORY_LOCATOR,
            ZIP64_END_CENTRAL_DIRECTORY_RECORD,
            ZIP64_EXTRA_FIELD_SIGNATURE,
            AES_EXTRA_DATA_RECORD
        ]
    }

    public func getValue(): Int64 {
        return match (this) {
            case LOCAL_FILE_HEADER => 0x04034b50
            case EXTRA_DATA_RECORD => 0x08074b50
            case CENTRAL_DIRECTORY => 0x02014b50
            case END_OF_CENTRAL_DIRECTORY => 0x06054b50
            case TEMPORARY_SPANNING_MARKER => 0x30304b50
            case DIGITAL_SIGNATURE => 0x05054b50
            case ARCEXTDATREC => 0x08064b50
            case SPLIT_ZIP => 0x08074b50
            case ZIP64_END_CENTRAL_DIRECTORY_LOCATOR => 0x07064b50
            case ZIP64_END_CENTRAL_DIRECTORY_RECORD => 0x06064b50
            case ZIP64_EXTRA_FIELD_SIGNATURE => 0x0001
            case _ => 0x9901
        }
    }
}
