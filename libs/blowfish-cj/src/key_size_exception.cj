/*
 * Copyright 2010 The Go Authors. All rights reserved.
 *
 * Portions of this file are derived from golang.org/x/crypto/blowfish,
 * which is licensed under a BSD-style license.
 * The original license can be found in the LICENSE.BSD file in this repository.
 * 
 * Copyright 2025 Dacec
 *
 * The remainder of this file, and the project as a whole (unless otherwise noted),
 * is licensed under the MIT License.
 * The full MIT License text can be found in the LICENSE.MIT file in this repository.
 */
package blowfish

public class KeySizeException <: Exception {
    public init(keySize: Int64) {
        super("Invalid key size: ${keySize}")
    }
}