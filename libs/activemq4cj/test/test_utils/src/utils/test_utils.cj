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

package activemq_sdk_test_utils.utils

internal import stdx.encoding.json.stream.*
internal import stdx.encoding.json.*
internal import stdx.encoding.url.URL
internal import stdx.encoding.url.Form
internal import std.fs.*
internal import std.collection.*
internal import std.convert.*
internal import std.math.MathExtension
internal import std.sync.ReentrantMutex
internal import activemq4cj.client.ActiveMQConnection
internal import activemq4cj.client.ActiveMQConnectionFactory
internal import activemq4cj.client.api.ActiveMQException
internal import activemq4cj.client.openwire.OpenWireFormat
internal import activemq4cj.client.openwire.OpenWireFormatFactory
internal import activemq4cj.client.wireformat.WireFormat
internal import activemq4cj.cjms.AcknowledgeMode
internal import activemq4cj.cjms.Connection
internal import activemq4cj.cjms.Destination

public class TestUtils {
    // Connection实例，可以发送openwire命令
    private static var connection: ?Connection = None
    //WireFormat实例，用以对openwire命令直接进行编解码
    private static var format: ?WireFormat = None

    private static var brokerURL: ?String = None
    private static var userName: String = "admin"
    private static var password: String = "admin"

    private static let mutex = ReentrantMutex()

    public static func getConnection(): Connection {
        if (let Some(connection) <- TestUtils.connection) {
            // 先使用缓存的connection
            return connection
        }

        synchronized(mutex) {
            if (let Some(connection) <- TestUtils.connection) {
                return connection
            }

            // 没有缓存Connection，创建新的Connection
            let createdConnection = createConnection()
            TestUtils.connection = createdConnection
            return createdConnection
        }
    }

    public static func getWireFormat(): WireFormat {
        if (let Some(format) <- TestUtils.format) {
            // 先使用缓存的connection
            return format
        }

        synchronized(mutex) {
            if (let Some(format) <- TestUtils.format) {
                return format
            }

            // 没有缓存Connection，创建新的Connection
            let createdFormat = buildWireFormat()
            TestUtils.format = createdFormat
            return createdFormat
        }
    }

    public static func buildWireFormat(): WireFormat {
        let wireFormatFactory = OpenWireFormatFactory()
        let path = findEnvironmentConfigFile(Path("."))
        let jsonObj = getConfigJsonValue(path)
        if (let Some(wireformat) <- jsonObj.get("wireformat")) {
            configWireFormatFactory(wireFormatFactory, wireformat.asObject())
        }
        let format = wireFormatFactory.createWireFormat()
        if (let Some(openWireFormat) <- (format as OpenWireFormat)) {
            if (let Some(preferedWireFormatInfo) <- openWireFormat.getPreferedWireFormatInfo()) {
                openWireFormat.renegotiateWireFormat(preferedWireFormatInfo)
            }
        }
        return format
    }

    private static func configWireFormatFactory(wireFormatFactory: OpenWireFormatFactory, jsonObj: JsonObject) {
        if (let Some(jsonValue) <- jsonObj.get("stackTraceEnabled")) {
            wireFormatFactory.stackTraceEnabled = Bool.parse(getValue(jsonValue))
        }

        if (let Some(jsonValue) <- jsonObj.get("cacheEnabled")) {
            wireFormatFactory.cacheEnabled = Bool.parse(getValue(jsonValue))
        }

        if (let Some(jsonValue) <- jsonObj.get("tightEncodingEnabled")) {
            wireFormatFactory.tightEncodingEnabled = Bool.parse(getValue(jsonValue))
        }
    }

    /**
     * 新建Connection
     */
    public static func createConnection(): Connection {
        let brokerURL = getBrokerURL()
        let connectionFactory = ActiveMQConnectionFactory(TestUtils.userName, TestUtils.password, brokerURL)
        let connection = connectionFactory.createConnection()
        return connection
    }

    /**
     * 清空Destination中的消息
     */
    public static func purgeQueue(connection: Connection, queue: Destination): Unit {
        try (session = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)) {
            try (consumer = session.createConsumer(queue)) {
                while (consumer.receive(Duration.millisecond * 1000).isSome()) {
                }
            }
        }
    }

    private static func getConfigJsonValue(path: Path): JsonObject {
        let file = File(path, OpenMode.Read)
        let size = file.length

        try {
            let buffer = Array<Byte>(size, repeat:  0)

            var readCount = 0
            var totalReadCount = 0
            while (totalReadCount <= size) {
                readCount = file.read(buffer)
                totalReadCount += size
            }

            let jsonExp = String.fromUtf8(buffer)
            let jsonVal = JsonValue.fromStr(jsonExp)
            let jsonObj = jsonVal.asObject()
            return jsonObj
        } finally {
            file.close()
        }
    }

    public static func getBrokerURL(): String {
        if (let Some(brokerURL) <- TestUtils.brokerURL) {
            return brokerURL
        }

        synchronized(mutex) {
            if (let Some(brokerURL) <- TestUtils.brokerURL) {
                return brokerURL
            }
            let brokerURL = buildBrokerURL()
            TestUtils.brokerURL = brokerURL
            return brokerURL
        }
    }

    private static func buildBrokerURL(): String {
        let path = findEnvironmentConfigFile(Path("."))
        let jsonObj = getConfigJsonValue(path)

        var brokerURL = URL.parse("tcp://127.0.0.1:61616")

        if (let Some(jsonValue) <- jsonObj.get("host")) {
           brokerURL =  brokerURL.replace(hostName: getValue(jsonValue))
        }

        if (let Some(jsonValue) <- jsonObj.get("port")) {
           brokerURL = brokerURL.replace(port: getValue(jsonValue))
        }

        if (let Some(jsonValue) <- jsonObj.get("userName")) {
            let userName = getValue(jsonValue)
            if (!userName.isAsciiBlank()) {
                TestUtils.userName = userName
            }
        }

        if (let Some(jsonValue) <- jsonObj.get("password")) {
            let password = getValue(jsonValue)
            if (!password.isAsciiBlank()) {
                TestUtils.password = password
            }
        }

        let form: Form = Form()

        if (let Some(wireformat) <- jsonObj.get("wireformat")) {
            setWireFormatProps(form, wireformat.asObject())
        }

        if (let Some(jsonValue) <- jsonObj.get("threadPoolName")) {
            form.set("threadPoolName", getValue(jsonValue))
        }

        if (let Some(jsonValue) <- jsonObj.get("queueSize")) {
            form.set("queueSize", getValue(jsonValue))
        }

        if (let Some(jsonValue) <- jsonObj.get("maxThreads")) {
            form.set("maxThreads", getValue(jsonValue))
        }

        if (let Some(jsonValue) <- jsonObj.get("minThreads")) {
            form.set("minThreads", getValue(jsonValue))
        }

        if (let Some(jsonValue) <- jsonObj.get("threadIdleTimeoutInSeconds")) {
            form.set("threadIdleTimeoutInSeconds", getValue(jsonValue))
        }
        return brokerURL.toString() + "?" + form.toEncodeString()
    }

    private static func setWireFormatProps(form: Form, jsonObj: JsonObject) {
        if (let Some(jsonValue) <- jsonObj.get("stackTraceEnabled")) {
            form.set("wireFormat.stackTraceEnabled", getValue(jsonValue))
        }

        if (let Some(jsonValue) <- jsonObj.get("platformDetails")) {
            form.set("wireFormat.platformDetails", getValue(jsonValue))
        }

        if (let Some(jsonValue) <- jsonObj.get("cacheEnabled")) {
            form.set("wireFormat.cacheEnabled", getValue(jsonValue))
        }

        if (let Some(jsonValue) <- jsonObj.get("host")) {
            form.set("wireFormat.host", getValue(jsonValue))
        }

        if (let Some(jsonValue) <- jsonObj.get("tcpNoDelayEnabled")) {
            form.set("wireFormat.tcpNoDelayEnabled", getValue(jsonValue))
        }

        if (let Some(jsonValue) <- jsonObj.get("sizePrefixDisabled")) {
            form.set("wireFormat.sizePrefixDisabled", getValue(jsonValue))
        }

        if (let Some(jsonValue) <- jsonObj.get("cacheSize")) {
            form.set("wireFormat.cacheSize", getValue(jsonValue))
        }

        if (let Some(jsonValue) <- jsonObj.get("providerName")) {
            form.set("wireFormat.providerName", getValue(jsonValue))
        }

        if (let Some(jsonValue) <- jsonObj.get("tightEncodingEnabled")) {
            form.set("wireFormat.tightEncodingEnabled", getValue(jsonValue))
        }

        if (let Some(jsonValue) <- jsonObj.get("maxFrameSize")) {
            form.set("wireFormat.maxFrameSize", getValue(jsonValue))
        }

        if (let Some(jsonValue) <- jsonObj.get("maxInactivityDuration")) {
            form.set("wireFormat.maxInactivityDuration", getValue(jsonValue))
        }

        if (let Some(jsonValue) <- jsonObj.get("maxInactivityDurationInitalDelay")) {
            form.set("wireFormat.maxInactivityDurationInitalDelay", getValue(jsonValue))
        }

        if (let Some(jsonValue) <- jsonObj.get("maxFrameSizeEnabled")) {
            form.set("wireFormat.maxFrameSizeEnabled", getValue(jsonValue))
        }
    }

    private static func findEnvironmentConfigFile(currentDir: Path): Path {
        let environmentPath = currentDir.join("environment.json")
        try {
            if (exists(environmentPath)) {
                return environmentPath
            }
        } catch (ex: FSException) {
            ex.printStackTrace()
        }

        var checkDirInfo = FileInfo(currentDir)
        while (let Some(parentInfo) <- checkDirInfo.parentDirectory) {
            let environmentPath = parentInfo.path.join("environment.json")
            try {
                if (exists(environmentPath)) {
                    return environmentPath
                }
            } catch (ex: FSException) {
                ex.printStackTrace()
            }

            checkDirInfo = parentInfo
        }

        throw Exception("Could not find file: environment.json")
    }

    public static func getHost(): String {
        let path = findEnvironmentConfigFile(Path("."))
        let jsonObj = getConfigJsonValue(path)
        if (let Some(jsonValue) <- jsonObj.get("host")) {
            return getValue(jsonValue)
        }
        return "localhost"
    }

    private static func getValue(jsonValue: JsonValue): String {
        match (jsonValue.kind()) {
            case JsString => if (let Some(jsonStr) <- (jsonValue as JsonString)) {
                return jsonStr.getValue()
            } else {
                throw ActiveMQException("Only JsString type is accept")
            }

            case _ => throw ActiveMQException("Only JsString type is accept")
        }
    }
}
