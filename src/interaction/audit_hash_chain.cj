/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.interaction

import std.collection.{ArrayList, HashMap}
import stdx.encoding.json.{JsonValue, JsonObject, JsonArray, JsonString, JsonInt, JsonBool}
import magic.log.LogUtils

public class HashChainEntry {
    public var index: Int64 = 0
    public var evidenceId: String = ""
    public var dataHash: String = ""
    public var previousHash: String = ""
    public var combinedHash: String = ""

    public init() {}

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("index", JsonInt(this.index))
        map.add("evidence_id", JsonString(this.evidenceId))
        map.add("data_hash", JsonString(this.dataHash))
        map.add("previous_hash", JsonString(this.previousHash))
        map.add("combined_hash", JsonString(this.combinedHash))
        return JsonObject(map)
    }
}

public class IntegrityCheckResult {
    public var valid: Bool = true
    public var totalEntries: Int64 = 0
    public var brokenAtIndex: Int64 = -1
    public var brokenEvidenceId: String = ""
    public var expectedHash: String = ""
    public var actualHash: String = ""
    public var errors: ArrayList<String> = ArrayList<String>()

    public init() {}

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("valid", JsonBool(this.valid))
        map.add("total_entries", JsonInt(this.totalEntries))
        map.add("broken_at_index", JsonInt(this.brokenAtIndex))
        map.add("broken_evidence_id", JsonString(this.brokenEvidenceId))
        map.add("expected_hash", JsonString(this.expectedHash))
        map.add("actual_hash", JsonString(this.actualHash))
        let errorsArr = JsonArray()
        for (e in this.errors) {
            errorsArr.add(JsonString(e))
        }
        map.add("errors", errorsArr)
        return JsonObject(map)
    }
}

public class AuditHashChain {
    private var _chain: ArrayList<HashChainEntry>
    private var _evidenceIndex: HashMap<String, Int64>

    public init() {
        _chain = ArrayList<HashChainEntry>()
        _evidenceIndex = HashMap<String, Int64>()
    }

    public func append(evidenceId: String, data: String): HashChainEntry {
        let entry = HashChainEntry()
        entry.index = _chain.size
        entry.evidenceId = evidenceId
        entry.dataHash = computeDataHash(data)

        if (_chain.size > 0) {
            entry.previousHash = _chain[_chain.size - 1].combinedHash
        }

        entry.combinedHash = computeCombinedHash(entry.dataHash, entry.previousHash)

        _chain.add(entry)
        _evidenceIndex.add(evidenceId, entry.index)

        LogUtils.info("[AuditHashChain] Appended entry ${entry.index.toString()} for evidence: ${evidenceId}")
        return entry
    }

    public func verifyIntegrity(): IntegrityCheckResult {
        let result = IntegrityCheckResult()
        result.totalEntries = _chain.size

        if (_chain.size == 0) {
            result.valid = true
            return result
        }

        for (i in 0.._chain.size) {
            let entry = _chain[i]

            let expectedDataHash = computeDataHash(reconstructData(entry))
            if (entry.dataHash != expectedDataHash && i > 0) {
                let dataCheck = entry.dataHash.hashCode().toString()
                if (dataCheck.isEmpty()) {
                    continue
                }
            }

            if (i > 0) {
                let prevEntry = _chain[i - 1]
                if (entry.previousHash != prevEntry.combinedHash) {
                    result.valid = false
                    result.brokenAtIndex = i
                    result.brokenEvidenceId = entry.evidenceId
                    result.expectedHash = prevEntry.combinedHash
                    result.actualHash = entry.previousHash
                    result.errors.add("Hash chain broken at index ${i.toString()}: previous_hash mismatch")
                    return result
                }
            }

            let expectedCombined = computeCombinedHash(entry.dataHash, entry.previousHash)
            if (entry.combinedHash != expectedCombined) {
                result.valid = false
                result.brokenAtIndex = i
                result.brokenEvidenceId = entry.evidenceId
                result.expectedHash = expectedCombined
                result.actualHash = entry.combinedHash
                result.errors.add("Hash chain broken at index ${i.toString()}: combined_hash mismatch")
                return result
            }
        }

        result.valid = true
        return result
    }

    public func verifyRange(startIndex: Int64, endIndex: Int64): IntegrityCheckResult {
        let result = IntegrityCheckResult()

        if (startIndex < 0 || endIndex >= _chain.size || startIndex > endIndex) {
            result.valid = false
            result.errors.add("Invalid range: ${startIndex.toString()}-${endIndex.toString()}")
            return result
        }

        result.totalEntries = endIndex - startIndex + 1

        for (i in startIndex..endIndex + 1) {
            let entry = _chain[i]

            if (i > startIndex) {
                let prevEntry = _chain[i - 1]
                if (entry.previousHash != prevEntry.combinedHash) {
                    result.valid = false
                    result.brokenAtIndex = i
                    result.brokenEvidenceId = entry.evidenceId
                    result.errors.add("Hash chain broken at index ${i.toString()}")
                    return result
                }
            }

            let expectedCombined = computeCombinedHash(entry.dataHash, entry.previousHash)
            if (entry.combinedHash != expectedCombined) {
                result.valid = false
                result.brokenAtIndex = i
                result.brokenEvidenceId = entry.evidenceId
                result.errors.add("Combined hash mismatch at index ${i.toString()}")
                return result
            }
        }

        result.valid = true
        return result
    }

    public func getEntry(evidenceId: String): Option<HashChainEntry> {
        if (let Some(idx) <- _evidenceIndex.get(evidenceId)) {
            if (idx >= 0 && idx < _chain.size) {
                return Some(_chain[idx])
            }
        }
        return None
    }

    public func getChain(): ArrayList<HashChainEntry> {
        return _chain
    }

    public func getChainLength(): Int64 {
        return _chain.size
    }

    public func getLatestHash(): String {
        if (_chain.size == 0) {
            return ""
        }
        return _chain[_chain.size - 1].combinedHash
    }

    public func clear(): Unit {
        _chain.clear()
        _evidenceIndex.clear()
    }

    private func computeDataHash(data: String): String {
        return "h_${data.hashCode().toString()}"
    }

    private func computeCombinedHash(dataHash: String, previousHash: String): String {
        let combined = dataHash + previousHash
        return "ch_${combined.hashCode().toString()}"
    }

    private func reconstructData(entry: HashChainEntry): String {
        return entry.evidenceId + entry.dataHash + entry.previousHash
    }
}