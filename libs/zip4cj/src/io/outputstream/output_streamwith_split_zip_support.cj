/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.io.outputstream

public interface OutputStreamWithSplitZipSupport {
    func getFilePointer(): Int64

    func getCurrentSplitFileCounter(): Int32
}
