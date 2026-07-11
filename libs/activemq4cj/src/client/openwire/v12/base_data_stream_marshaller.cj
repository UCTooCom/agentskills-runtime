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
package activemq4cj.client.openwire.v12

public abstract class BaseDataStreamMarshaller <: DataStreamMarshaller {
    private var contextVal: ThreadLocal<OpenWireContext> = ThreadLocal<OpenWireContext>()

    public mut prop openWireContext: OpenWireContext {
        get() {
            if (let Some(context) <- contextVal.get()) {
                return context
            }
            throw ActiveMQException("OpenWireContext not available")
        }
        set(value) {
            this.contextVal.set(value)
        }
    }

    public open func looseMarshal(object: Any, dataOut: ByteBuffer): Unit {
        if (let Some(object) <- (object as DataStructure)) {
            dataOut.putByte(object.getDataStructureType())
        }
    }

    public open func looseUnmarshal(object: DataStructure, dataIn: ByteBuffer) {
    }

    public open func tightMarshal(object: Any, dataOut: ByteBuffer, bs: BoolStream): Unit {
    }

    public open func tightUnmarshal(data: DataStructure, dataIn: ByteBuffer, bs: BoolStream): Unit {
    }

    protected func looseMarshalNestedObject<T>(object: ?T, dataOut: ByteBuffer): Unit where T <: DataStructure {
        MarshallingSupport.putBool(object.isSome(), dataOut)
        if (let Some(object) <- object) {
            openWireContext.getDataStreamMarshaller(object.getDataStructureType()).looseMarshal(object, dataOut)
        }
    }

    protected func looseUnmarsalNestedObject<T>(dataIn: ByteBuffer): ?T where T <: DataStructure {
        if (MarshallingSupport.getBool(dataIn)) {
            let commandType = dataIn.getByte()
            let dsm = openWireContext.getDataStreamMarshaller(commandType)
            let data = dsm.createObject()
            dsm.looseUnmarshal(data, dataIn)
            return data as T
        }
        return None
    }

    /**
     * 缓存命令编码
     */
    protected func looseMarshalCachedObject<T>(object: ?T, dataOut: ByteBuffer): Unit where T <: DataStructure {
        var data: ?DataStructure = toDataStructure<T>(object)
        if (isCacheEnabled()) {
            let cacheManager = openWireContext.cacheManager
            var index = cacheManager.getMarshallCacheIndex(data)
            MarshallingSupport.putBool(index.isNone(), dataOut)
            if (let Some(index) <- index) {
                dataOut.putInt16(index)
            } else {
                let newIndex = cacheManager.addToMarshallCache(data)
                dataOut.putInt16(newIndex)
                looseMarshalNestedObject(data, dataOut)
            }
        } else {
            looseMarshalNestedObject(data, dataOut)
        }
    }

    protected func looseUnmarsalCachedObject<T>(dataIn: ByteBuffer): ?T where T <: DataStructure {
        //开启缓存
        if (isCacheEnabled()) {
            let cacheManager = openWireContext.cacheManager
            //缓存里还没有该命令
            if (MarshallingSupport.getBool(dataIn)) {
                //缓存索引
                let index = dataIn.getInt16()
                let object: ?T = looseUnmarsalNestedObject(dataIn)
                //把命令存储到指定的缓存索引里面
                cacheManager.setInUnmarshallCache(index, toDataStructure<T>(object))
                return object
            } else {
                //缓存里面已经有该命令了，直接从指定的缓存索引取值
                let index = dataIn.getInt16()
                if (let Some(object) <- cacheManager.getFromUnmarshallCache(index)) {
                    return object as T
                }
                return None
            }
        } else {
            return looseUnmarsalNestedObject(dataIn)
        }
    }

    protected func looseUnmarshalString(dataIn: ByteBuffer): ?String {
        if (MarshallingSupport.getBool(dataIn)) {
            return MarshallingSupport.readUTF(dataIn)
        }
        return None
    }

    protected func looseMarshalString(value: ?String, byteBuffer: ByteBuffer) {
        MarshallingSupport.putBool(value.isSome(), byteBuffer)
        if (let Some(str) <- value) {
            MarshallingSupport.writeUTF(str, byteBuffer)
        }
    }

    protected func looseUnmarshalByteArray(dataIn: ByteBuffer): ?Array<Byte> {
        if (MarshallingSupport.getBool(dataIn)) {
            let size = dataIn.getInt32()
            let byteArray = Array<Byte>(Int64(size), repeat: 0)
            dataIn.get(byteArray)
            return byteArray
        }
        return None
    }

    protected func looseMarshalByteArray(byteArray: ?Array<Byte>, byteBuffer: ByteBuffer) {
        MarshallingSupport.putBool(byteArray.isSome(), byteBuffer)
        if (let Some(byteArray) <- byteArray) {
            byteBuffer.putInt32(Int32(byteArray.size))
            MarshallingSupport.putByteArray(byteArray, byteBuffer)
        }
    }

    /**
     * 嵌套命令数组编码
     */
    protected func looseMarshalObjectArray<T>(objectArray: ?Array<T>, dataOut: ByteBuffer): Unit where T <: DataStructure {
        if (let Some(objectArray) <- objectArray) {
            MarshallingSupport.putBool(true, dataOut)
            dataOut.putInt16(Int16(objectArray.size))
            if (objectArray.size > 0) {
                for (object in objectArray) {
                    looseMarshalNestedObject<T>(object, dataOut)
                }
            }
        } else {
            MarshallingSupport.putBool(false, dataOut)
        }
    }

    protected func looseMarshalThrowable(throwable: ?Throwable, dataOut: ByteBuffer): Unit {
        if (let Some(throwable) <- throwable) {
            MarshallingSupport.putBool(true, dataOut)
            looseMarshalString(throwable.className, dataOut)
            looseMarshalString(throwable.message, dataOut)
            if (isStackTraceEnabled()) {
                if (let Some(stackTrace) <- throwable.stackTrace) {
                    dataOut.putInt16(Int16(stackTrace.size))
                    for (element in stackTrace) {
                        looseMarshalString(element.declaringClass, dataOut)
                        looseMarshalString(element.methodName, dataOut)
                        looseMarshalString(element.fileName, dataOut)
                        dataOut.putInt32(Int32(element.lineNumber))
                    }
                } else {
                    dataOut.putInt16(0)
                }
                looseMarshalThrowable(throwable.cause, dataOut)
            }
        } else {
            MarshallingSupport.putBool(false, dataOut)
        }
    }

    protected func looseUnmarsalThrowable(dataIn: ByteBuffer): ?Throwable {
        if (MarshallingSupport.getBool(dataIn)) {
            let exception = Throwable()
            exception.className = looseUnmarshalString(dataIn)
            exception.message = looseUnmarshalString(dataIn)
            if (isStackTraceEnabled()) {
                let len = dataIn.getInt16()
                if (len > 0) {
                    let array = Array<StackTraceElement>(
                            Int64(len),
                            repeat: StackTraceElement("None", "None", "None", 0)
                    )
                    for (i in 0..len) {
                        let declaringClass = looseUnmarshalString(dataIn).getOrDefault({=> "None"})
                        let methodName = looseUnmarshalString(dataIn).getOrDefault({=> "None"})
                        let fileName = looseUnmarshalString(dataIn).getOrDefault({=> "None"})
                        let lineNumber = Int64(dataIn.getInt32())
                        let s = StackTraceElement(declaringClass, methodName, fileName, lineNumber)
                        array[Int64(i)] = s
                    }
                    exception.stackTrace = array
                }
                exception.cause = looseUnmarsalThrowable(dataIn)
            }
            return exception
        }
        return None
    }

    protected func tightMarshalCachedObject<T>(object: ?T, dataOut: ByteBuffer, bs: BoolStream): Unit where T <: DataStructure {
        var data: ?DataStructure = toDataStructure<T>(object)
        if (isCacheEnabled()) {
            let cacheManager = openWireContext.cacheManager
            var index = cacheManager.getMarshallCacheIndex(data)
            bs.writeBool(index.isNone())
            if (let Some(index) <- index) {
                dataOut.putInt16(index)
            } else {
                let newIndex = cacheManager.addToMarshallCache(data)
                dataOut.putInt16(newIndex)
                tightMarshalNestedObject(data, dataOut, bs)
            }
        } else {
            tightMarshalNestedObject(data, dataOut, bs)
        }
    }

    protected func tightUnmarsalCachedObject<T>(dataIn: ByteBuffer, bs: BoolStream): ?T where T <: DataStructure {
        if (isCacheEnabled()) {
            let cacheManager = openWireContext.cacheManager
            if (bs.readBool()) {
                let index: Int16 = dataIn.getInt16()
                let object: ?T = tightUnmarshalNestedObject<T>(dataIn, bs)
                //把命令存储到指定的缓存索引里面
                cacheManager.setInUnmarshallCache(index, toDataStructure<T>(object))
                return object
            } else {
                let index: Int16 = dataIn.getInt16()
                if (let Some(object) <- cacheManager.getFromUnmarshallCache(index)) {
                    return object as T
                }
                return None
            }
        } else {
            return tightUnmarshalNestedObject<T>(dataIn, bs)
        }
    }

    protected func tightUnmarshalString(dataIn: ByteBuffer, bs: BoolStream): ?String {
        if (bs.readBool()) {
            bs.readBool()
            return MarshallingSupport.readUTF(dataIn)
        } else {
            return None
        }
    }

    protected func tightMarshalString(value: ?String, dataOut: ByteBuffer, bs: BoolStream): Unit {
        bs.writeBool(value.isSome())
        if (let Some(value) <- value) {
            bs.writeBool(value.isAscii())
            MarshallingSupport.writeUTF(value, dataOut)
        }
    }

    protected func tightMarshalLong(value: Int64, dataOut: ByteBuffer, bs: BoolStream): Unit {
        //16位无符号数掩码
        var u16Mask: UInt64 = 0xFFFFFFFFFFFF0000
        //32位无符号数掩码
        var u32Mask: UInt64 = 0xFFFFFFFF00000000
        //用无符号数与掩码计算将要写出的数值真正占用的字节数
        var u64 = Convert.convertToUInt64(value)

        if (value == 0) {
            bs.writeBool(false)
            bs.writeBool(false)
        } else if ((u64 & u16Mask) == 0) {
            //所有的占2字节数字都用UInt16写出，使用Int16可能会溢出
            bs.writeBool(false)
            bs.writeBool(true)
            dataOut.putUInt16(UInt16(value & 0xFFFF))
        } else if ((u64 & u32Mask) == 0) {
            //所有的占4字节数字都用UInt32写出，使用Int32可能会溢出
            bs.writeBool(true)
            bs.writeBool(false)
            dataOut.putUInt32(UInt32(value & 0xFFFFFFFF))
        } else {
            bs.writeBool(true)
            bs.writeBool(true)
            dataOut.putInt64(value)
        }
    }

    protected func tightUnmarshalLong(dataIn: ByteBuffer, bs: BoolStream): Int64 {
        if (bs.readBool()) {
            if (bs.readBool()) {
                return dataIn.getInt64()
            } else {
                //直接读无符号数，有符号数可能会溢出出现负数
                return Int64(dataIn.getUInt32())
            }
        } else {
            if (bs.readBool()) {
                //直接读无符号数，有符号数可能会溢出出现负数
                return Int64(dataIn.getUInt16())
            } else {
                return 0
            }
        }
    }

    /**
     * 嵌套命令数组编码
     */
    protected func tightMarshalObjectArray<T>(objectArray: ?Array<T>, dataOut: ByteBuffer, bs: BoolStream): Unit where T <: DataStructure {
        if (let Some(objectArray) <- objectArray) {
            bs.writeBool(true)
            dataOut.putInt16(Int16(objectArray.size))
            if (objectArray.size > 0) {
                for (object in objectArray) {
                    tightMarshalNestedObject(object, dataOut, bs)
                }
            }
        } else {
            bs.writeBool(false)
        }
    }

    protected func tightMarshalByteArray(data: ?Array<Byte>, dataOut: ByteBuffer, bs: BoolStream): Unit {
        bs.writeBool(data.isSome())
        if (let Some(data) <- data) {
            dataOut.putInt32(Int32(data.size))
            MarshallingSupport.putByteArray(data, dataOut)
        }
    }

    protected func tightUnmarshalByteArray(dataIn: ByteBuffer, bs: BoolStream): ?Array<Byte> {
        if (bs.readBool()) {
            let size = dataIn.getInt32()
            let rc = Array<Byte>(Int64(size), repeat: 0)
            dataIn.get(rc)
            return rc
        }
        return None
    }

    public func tightMarshalNestedObject<T>(object: ?T, dataOut: ByteBuffer, bs: BoolStream): Unit where T <: DataStructure {
        bs.writeBool(object.isSome())
        if (let Some(object) <- object) {
            if (object.isMarshallAware()) {
                bs.writeBool(false)
            }
            let dataType = object.getDataStructureType()
            let dsm: DataStreamMarshaller = openWireContext.getDataStreamMarshaller(dataType)
            if (dsm is DefaultDataStreamMarshaller) {
                throw ActiveMQException("Unknown data type: ${dataType}")
            }
            dataOut.putByte(dataType)
            dsm.tightMarshal(object, dataOut, bs)
        }
    }

    public func tightUnmarshalNestedObject<T>(dataIn: ByteBuffer, bs: BoolStream): ?T {
        if (bs.readBool()) {
            let dataType: Byte = dataIn.getByte()
            let dsm: DataStreamMarshaller = openWireContext.getDataStreamMarshaller(dataType)
            if (dsm is DefaultDataStreamMarshaller) {
                throw ActiveMQException("Unknown data type: ${dataType}")
            }
            let data: DataStructure = dsm.createObject()

            if (data.isMarshallAware() && bs.readBool()) {
                dataIn.getInt32()
                dataIn.getByte()

                let bs2: BoolStream = BoolStream()
                bs2.unmarshal(dataIn);
                dsm.tightUnmarshal(data, dataIn, bs2)
            } else {
                dsm.tightUnmarshal(data, dataIn, bs)
            }
            return data as T
        } else {
            return None
        }
    }

    protected func tightMarshalThrowable(throwable: ?Throwable, dataOut: ByteBuffer, bs: BoolStream): Unit {
        if (let Some(throwable) <- throwable) {
            bs.writeBool(true)
            tightMarshalString(throwable.className, dataOut, bs)
            tightMarshalString(throwable.message, dataOut, bs)
            if (isStackTraceEnabled()) {
                if (let Some(stackTrace) <- throwable.stackTrace) {
                    dataOut.putInt16(Int16(stackTrace.size))
                    for (element in stackTrace) {
                        tightMarshalString(element.declaringClass, dataOut, bs)
                        tightMarshalString(element.methodName, dataOut, bs)
                        tightMarshalString(element.fileName, dataOut, bs)
                        dataOut.putInt32(Int32(element.lineNumber))
                    }
                } else {
                    dataOut.putInt16(0)
                }
                tightMarshalThrowable(throwable.cause, dataOut, bs)
            }
        } else {
            bs.writeBool(false)
        }
    }

    protected func tightUnmarsalThrowable(dataIn: ByteBuffer, bs: BoolStream): ?Throwable {
        if (bs.readBool()) {
            let exception = Throwable()
            exception.className = tightUnmarshalString(dataIn, bs)
            exception.message = tightUnmarshalString(dataIn, bs)
            if (isStackTraceEnabled()) {
                let len = Int64(dataIn.getInt16())
                if (len > 0) {
                    let array = Array<StackTraceElement>(
                            Int64(len),
                            repeat: StackTraceElement("None", "None", "None", 0)
                    )
                    for (i in 0..len) {
                        let declaringClass = tightUnmarshalString(dataIn, bs).getOrDefault({=> "None"})
                        let methodName = tightUnmarshalString(dataIn, bs).getOrDefault({=> "None"})
                        let fileName = tightUnmarshalString(dataIn, bs).getOrDefault({=> "None"})
                        let lineNumber = Int64(dataIn.getInt32())
                        let s = StackTraceElement(declaringClass, methodName, fileName, lineNumber)
                        array[i] = s
                    }
                    exception.stackTrace = array
                }
                exception.cause = tightUnmarsalThrowable(dataIn, bs)
            }
            return exception
        }
        return None
    }

    public func toDataStructure<T>(object: ?T): ?DataStructure where T <: DataStructure {
        if (let Some(object) <- object) {
            return Option<DataStructure>.Some(object)
        }
        return None
    }

    protected func isCacheEnabled() {
        return this.openWireContext.cacheEnabled
    }

    protected func isStackTraceEnabled() {
        return this.openWireContext.stackTraceEnabled
    }
}

/**
 * 编解码组件的默认实现
 */
public class DefaultDataStreamMarshaller <: DataStreamMarshaller {
    private var contextVal: ?OpenWireContext = None

    public mut prop openWireContext: OpenWireContext {
        get() {
            throw UnsupportedException("Unsupported operation")
        }
        set(value) {
            throw UnsupportedException("Unsupported operation")
        }
    }

    public override func looseMarshal(object: Any, dataOut: ByteBuffer): Unit {
        throw UnsupportedException("Unsupported operation")
    }

    public override func looseUnmarshal(data: DataStructure, dataIn: ByteBuffer): Unit {
        throw UnsupportedException("Unsupported operation")
    }

    public override func tightMarshal(object: Any, dataOut: ByteBuffer, bs: BoolStream): Unit {
        throw UnsupportedException("Unsupported operation")
    }

    public override func tightUnmarshal(data: DataStructure, dataIn: ByteBuffer, bs: BoolStream): Unit {
        throw UnsupportedException("Unsupported operation")
    }

    public override func createObject(): DataStructure {
        throw UnsupportedException("Unsupported operation")
    }
}
