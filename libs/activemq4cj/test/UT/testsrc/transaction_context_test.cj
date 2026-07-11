/**
 * Copyright 2024 Beijing Baolande Software Corporation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * Runtime Library Exception to the Apache 2.0 License:
 *
 * As an exception, if you use this Software to compile your source code and
 * portions of this Software are embedded into the binary product as a result,
 * you may redistribute such product without providing attribution as would
 * otherwise be required by Sections 4(a), 4(b) and 4(d) of the License.
 */
package activemq_client_unit_test

@Test
public class TransactionContextTest {
    private var connection: ?ActiveMQConnection = None
    private var underTest: ?TransactionContext = None

    @BeforeAll
    protected func beforeAll(): Unit {
        connection = TestUtils.createConnection() as ActiveMQConnection
        connection.getOrThrow().start()
        underTest = TransactionContext(connection.getOrThrow())
    }

    @TestCase
    public func testSyncBeforeEndCalledOnceOnRollback(): Unit {
        let underTest = underTest.getOrThrow()

        let beforeEndCountA: AtomicInt32 = AtomicInt32(0)
        let rollbackCountA: AtomicInt32 = AtomicInt32(0)
        let beforeEndCountB: AtomicInt32 = AtomicInt32(0)
        let rollbackCountB: AtomicInt32 = AtomicInt32(0)

        underTest.addSynchronization(SynchronizationA(beforeEndCountA, rollbackCountA))

        underTest.addSynchronization(SynchronizationB(beforeEndCountB, rollbackCountB))

        try {
            underTest.commit()
        } catch (expected: TransactionRolledBackException) {
        }

        @Assert(1, beforeEndCountA.load())
        @Assert(1, beforeEndCountB.load())
        @Assert(1, rollbackCountB.load())
        @Assert(rollbackCountA.load(), rollbackCountB.load())
    }

    @TestCase
    public func testSyncIndexCleared(): Unit {
        let underTest = underTest.getOrThrow()

        let beforeEndCount: AtomicInt32 = AtomicInt32(0)
        let rollbackCount: AtomicInt32 = AtomicInt32(0)

        let sync = SynchronizationC(beforeEndCount, rollbackCount)

        underTest.begin()
        underTest.addSynchronization(sync)
        underTest.rollback()

        @Assert(1, beforeEndCount.load())
        @Assert(1, rollbackCount.load())

        // do it again
        underTest.begin()
        underTest.addSynchronization(sync)
        underTest.rollback()

        @Assert(2, beforeEndCount.load())
        @Assert(2, rollbackCount.load())
    }

    @AfterAll
    public func afterAll() {
        if (let Some(connection) <- connection) {
            connection.close()
        }
    }
}

public class SynchronizationA <: Synchronization {
    private let beforeEndCount: AtomicInt32
    private let rollbackCount: AtomicInt32

    public init(beforeEndCount: AtomicInt32, rollbackCount: AtomicInt32) {
        this.beforeEndCount = beforeEndCount
        this.rollbackCount = rollbackCount
    }

    public func beforeEnd(): Unit {
        if (beforeEndCount.fetchAdd(1) == 0) {
            throw TransactionRolledBackException("force rollback")
        }
    }

    public func afterCommit(): Unit {
    }

    public func afterRollback(): Unit {
        rollbackCount.fetchAdd(1)
    }
}

public class SynchronizationB <: Synchronization {
    private let beforeEndCount: AtomicInt32
    private let rollbackCount: AtomicInt32

    public init(beforeEndCount: AtomicInt32, rollbackCount: AtomicInt32) {
        this.beforeEndCount = beforeEndCount
        this.rollbackCount = rollbackCount
    }

    public func beforeEnd(): Unit {
        if (beforeEndCount.fetchAdd(1) == 0) {
            throw TransactionRolledBackException("force rollback")
        }
    }

    public func afterCommit(): Unit {
    }

    public func afterRollback(): Unit {
        rollbackCount.fetchAdd(1)
    }
}

public class SynchronizationC <: Synchronization {
    private let beforeEndCount: AtomicInt32
    private let rollbackCount: AtomicInt32

    public init(beforeEndCount: AtomicInt32, rollbackCount: AtomicInt32) {
        this.beforeEndCount = beforeEndCount
        this.rollbackCount = rollbackCount
    }

    public func beforeEnd(): Unit {
        beforeEndCount.fetchAdd(1)
    }

    public func afterCommit(): Unit {
    }

    public func afterRollback(): Unit {
        rollbackCount.fetchAdd(1)
    }
}
