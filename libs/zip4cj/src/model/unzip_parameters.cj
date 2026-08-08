/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.model

public class UnzipParameters {
    private var extractSymbolicLinks: Bool = true

    public func isExtractSymbolicLinks(): Bool {
        return extractSymbolicLinks
    }

    public func setExtractSymbolicLinks(extractSymbolicLinks: Bool): Unit {
        this.extractSymbolicLinks = extractSymbolicLinks
    }
}
