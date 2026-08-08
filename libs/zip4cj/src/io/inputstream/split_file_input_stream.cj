/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.io.inputstream

// Even though this abstract class has only abstract method definitions, it is not implemented as an interface because
// implementations of this class has to be used as an inputstream to ZipInputStream
public abstract class SplitFileInputStream <: InputStream & Resource {
    public func prepareExtractionForFileHeader(fileHeader: FileHeader): Unit
}
