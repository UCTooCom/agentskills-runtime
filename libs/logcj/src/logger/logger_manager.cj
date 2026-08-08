/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */

/**
 * @file
 * This file defines LoggerManager class.
 */

package logcj.logger

// public var Logger_Appender_Factory = LoggerAppenderFactory()
// public var Logger_Manager = LoggerManager("")

/**
 * Log management class, load and parse log file to get a specific configuration item.
 */
public class LoggerManager {
    // Logger appender factory, mainly register logger appender.
    private var loggerAppenderFactory: LoggerAppenderFactory = LoggerAppenderFactory()

    // Logger multiple appenders, multiple registers logger appender. 
    public var LoggerAppenderFactoryHashMap: HashMap<String, LoggerAppenderFactory> = HashMap<String, LoggerAppenderFactory>()

    // Root configuation variable.
    private var rootLogger: LoggerAppenderReference = LoggerAppenderReference()

    // Logger configuration map, mainly stores configurtion items related to logger configuration.
    private var loggerNameArr: ArrayList<String> = ArrayList<String>()
    private var loggerAttrArr: ArrayList<LoggerAppenderReference> = ArrayList<LoggerAppenderReference>()
    private var loggerArr: HashMap<String, LoggerAppenderReference> = HashMap<String, LoggerAppenderReference>()

    /**
     * Constructor, load and parse xml file.
     *
     * @param jsonPath log file path.
     */
    public static func createManager(jsonPath: String): LoggerManager {
        return LoggerManager(jsonPath)
    }
    
    init(jsonPath: String) {
        initWithDefaultConfig(jsonPath)
    }

    public func getLoggerAppenderFactory(): LoggerAppenderFactory {
        return this.loggerAppenderFactory
    }

    public func getRootLogger(): LoggerAppenderReference {
        return this.rootLogger
    }

    public func getLoggerNameArr(): ArrayList<String> {
        return this.loggerNameArr
    }

    public func getLoggerAttrArr(): ArrayList<LoggerAppenderReference> {
        return this.loggerAttrArr
    }

    public func getLoggerArr(): HashMap<String, LoggerAppenderReference> {
        return this.loggerArr
    }

    /**
     * Get the specific logger based on the logger name.
     *
     * @param name logger name.
     * @return logger object.
     */
    public func getLogger(name: String): Logger {
        var logger = Logger(name, this)
        return logger
    }

    /**
     * Initialize default configurations of log file.
     *
     * @param jsonPath log file path.
     */
    private func initWithDefaultConfig(jsonPath: String): Unit {
        // Register the LoggerAppender provided by the system.
        loggerAppenderFactory.registryType("console", ConsoleLoggerAppender())
        loggerAppenderFactory.registryType("file", FileLoggerAppender())

        var loggerConfiguration: LoggerConfiguration = parseJson(jsonPath)
        if (loggerConfiguration.getAppenders().size == 0) {
            println("can not find any appender!")
            return
        }
        initWithConfig(loggerConfiguration)
    }

    /**
     * Initialize the log configurtion obtained by loading the xml file.
     *
     * @param configuration log configuration obtained by loading the xml file.
     */
    private func initWithConfig(configuration: LoggerConfiguration): Unit {
        this.loggerAppenderFactory = loggerAppenderFactory.new()

        for( i in 0..configuration.getLogger().size){
            var loggerFactory = LoggerAppenderFactory().new()
            loggerFactory.registryType("console", ConsoleLoggerAppender())
            loggerFactory.registryType("file", FileLoggerAppender())
            var name: String = configuration.getLogger().get(i).getOrThrow().getName()
            LoggerAppenderFactoryHashMap.add(name, loggerFactory)
        }

        this.loggerNameArr = ArrayList<String>()
        this.loggerAttrArr = ArrayList<LoggerAppenderReference>()
        this.rootLogger = LoggerAppenderReference(DEFAULT_LOG_LEVEL, ArrayList<LoggerAppender>())

        var nameArr: ArrayList<String> = ArrayList<String>()
        var enabledArr: ArrayList<String> = ArrayList<String>()

        // Register appenders.
        if (configuration.getAppenders().size > 0) {
            var i: Int64 = 0
            var appenders: ArrayList<AppenderConfig> = configuration.getAppenders()
            while (i < appenders.size) {
                nameArr.add(appenders.get(i).getOrThrow().getName().toAsciiLower())
                enabledArr.add(appenders.get(i).getOrThrow().getEnabled().toAsciiLower().trimAscii())
                i++
            }
        }

        // Initialize root configuration.
        let rootConfig = configuration.getRoot()

        this.rootLogger.setLevel(LogLevel.getLevelByString(rootConfig.getLevel()))

        if (rootConfig.getAppenderRefList().size > 0) {
            var j: Int64 = 0
            var appenderRefList: ArrayList<AppenderRef> = rootConfig.getAppenderRefList()
            while (j < appenderRefList.size) {
                var appenderRef = appenderRefList.get(j).getOrThrow()
                var index: Int64 = 0
                while (index < nameArr.size) {
                    if (nameArr.get(index).getOrThrow() == (appenderRef.getRef().toAsciiLower()) &&
                        enabledArr.get(index).getOrThrow().contains("true")) {
                        var appenders: ArrayList<AppenderConfig> = configuration.getAppenders()
                        this.loggerAppenderFactory.registerLoggerAppender(
                            appenders.get(index).getOrThrow().getName(),
                            appenders.get(index).getOrThrow().getAppenderType(),
                            appenders.get(index).getOrThrow().getPattern(),
                            appenders.get(index).getOrThrow().getProperties()
                        )
                        let ap = this.loggerAppenderFactory.getAppenderByName(appenderRef.getRef().toAsciiLower())
                        this.rootLogger.getAppenderList().add(ap)
                    }
                    index++
                }
                j++
            }
        }
 
        // Initialize logger configuration.
        if (configuration.getLogger().size > 0) {
            var k: Int64 = 0
            var loggers: ArrayList<LoggerConfig> = configuration.getLogger()
            while (k < loggers.size) {
                var logger: LoggerConfig = loggers.get(k).getOrThrow()
                let oneLogger = LoggerAppenderReference(
                    LogLevel.getLevelByString(logger.getLevel()),
                    ArrayList<LoggerAppender>()
                )
                this.loggerAppenderFactory = LoggerAppenderFactoryHashMap[logger.getName()]
                var m: Int64 = 0
                while (m < logger.getAppenderRefList().size) {
                    var appenderRef: AppenderRef = logger.getAppenderRefList().get(m).getOrThrow()
                    var index: Int64 = 0
                    var appenders: ArrayList<AppenderConfig> = configuration.getAppenders()
                    while (index < nameArr.size) {
                        if (nameArr.get(index).getOrThrow() == (appenderRef.getRef().toAsciiLower()) &&
                            enabledArr.get(index).getOrThrow().contains("true")) {
                            this.loggerAppenderFactory.registerLoggerAppender(
                                appenders.get(index).getOrThrow().getName(),
                                appenders.get(index).getOrThrow().getAppenderType(),
                                appenders.get(index).getOrThrow().getPattern(),
                                appenders.get(index).getOrThrow().getProperties()
                            )
                            let oneAppender = this.loggerAppenderFactory.getAppenderByName(
                                appenderRef.getRef().toAsciiLower()
                            )
                            oneLogger.getAppenderList().add(oneAppender)
                        }
                        index++
                    }
                    m++
                }
                if (oneLogger.getAppenderList().size > 0) {
                    this.loggerNameArr.add(logger.getName())
                    this.loggerAttrArr.add(oneLogger)
                    this.loggerArr.add(logger.getName(), oneLogger)
                }
                k++
            }
        }
    }

    /**
     * This function is used to parse the XML file into the LoggerConfiguration object.
     *
     * @param jsonPath log file path.
     * @return logger configuration object.
     */
    private func parseJson(jsonPath: String): LoggerConfiguration {
        if (jsonPath == "") {
            return loadDefaultConfiguration()
        }

        var filePath: Path = Path(jsonPath)
        var isFileExist: Bool = exists(filePath)

        if (!isFileExist) {
            println("can not find config file, use default config")
            return loadDefaultConfiguration()
        }

        // read file.
        let allBytes: Array<Byte> = File.readFrom(jsonPath)
        if (allBytes.size == 0) {
            println("can not find any element in json file!")
            return LoggerConfiguration()
        }

        var jsonValue: JsonValue = JsonValue.fromStr(String.fromUtf8(allBytes))

        // Get appender configuration.
        var appenderList: ArrayList<AppenderConfig> = getAppenderConfiguration(jsonValue)

        if (appenderList.size == 0) {
            println("can not find any appender in xml file!")
            return LoggerConfiguration()
        }

        // Get logger configuration.
        var loggerList: ArrayList<LoggerConfig> = getLoggerConfiguration(jsonValue)
        if (loggerList.size == 0) {
            println("can not find any logger in xml file!")
        }

        // Get root configuration.
        var root: RootLoggerConfig = getRootConfiguration(jsonValue)
        if (root.getLevel().size == 0 || root.getAppenderRefList().size == 0) {
            println("root configuration has mistakes!")
            return LoggerConfiguration()
        }

        return LoggerConfiguration(appenderList, root, loggerList)
    }

    /**
     * Parse the built-in log configuration.
     *
     * @return logger configuration object.
     */
    public func loadDefaultConfiguration(): LoggerConfiguration {
        println("enter default...")
        var str =
            ##"{"appenders":[{"enabled":"true","name":"console","type":"console","pattern":"[%D %T %m] [%L] [%l] (%S) %M"},{"enabled":"true","name":"file","type":"file","pattern":"[%D %T %m] [%L] [%l] (%S) %M","properties":[{"name":"filename","value":"root.log"},{"name":"rotate","value":"true"},{"name":"maxsize","value":"20M"},{"name":"daily","value":"false"}]}],"loggers":[{"name":"Demo","level":"info","appender-refs":[{"ref":"console"},{"ref":"file"}]}],"root":{"level":"info","appender-refs":[{"ref":"console"},{"ref":"file"}]}}"##
        var jsonValue: JsonValue = JsonValue.fromStr(str)
        var appenderList: ArrayList<AppenderConfig> = getAppenderConfiguration(jsonValue)
        var loggerList: ArrayList<LoggerConfig> = getLoggerConfiguration(jsonValue)
        var root: RootLoggerConfig = getRootConfiguration(jsonValue)
        return LoggerConfiguration(appenderList, root, loggerList)
    }

    /**
     * Get appender configuarations.
     *
     * @param jsonValue basic configuration elements by parsing json file.
     * @return appender configuration list.
     */
    private func getAppenderConfiguration(jsonValue: JsonValue): ArrayList<AppenderConfig> {
        var configList: ArrayList<AppenderConfig> = ArrayList<AppenderConfig>()
        let appenders = jsonValue.asObject().get("appenders").getOrThrow()
        var jsArr: JsonArray = JsonValue.fromStr(appenders.toJsonString()).asArray()

        for (o in 0..jsArr.size()) {
            var appender: AppenderConfig = AppenderConfig()
            if (jsArr.get(o).getOrThrow().asObject().containsKey("enabled")) {
                appender.setEnabled(jsArr.get(o).getOrThrow().asObject().get("enabled").getOrThrow().asString().getValue())
            }
            if (jsArr.get(o).getOrThrow().asObject().containsKey("enabled")) {
                appender.setName(jsArr.get(o).getOrThrow().asObject().get("name").getOrThrow().asString().getValue())
            }
            if (jsArr.get(o).getOrThrow().asObject().containsKey("type")) {
                appender.setAppenderType(jsArr.get(o).getOrThrow().asObject().get("type").getOrThrow().asString().getValue())
            }
            if (jsArr.get(o).getOrThrow().asObject().containsKey("pattern")) {
                appender.setPattern(jsArr.get(o).getOrThrow().asObject().get("pattern").getOrThrow().asString().getValue())
            }
            if (jsArr.get(o).getOrThrow().asObject().containsKey("properties")) {
                var propertyList: ArrayList<AppenderProperty> = ArrayList<AppenderProperty>()
                var proArr: JsonArray = jsArr.get(o).getOrThrow().asObject().get("properties").getOrThrow().asArray()
                for (i in 0..proArr.size()) {
                    var property: AppenderProperty = AppenderProperty()
                    property.setName(proArr.get(i).getOrThrow().asObject().get("name").getOrThrow().asString().getValue())
                    property.setValue(proArr.get(i).getOrThrow().asObject().get("value").getOrThrow().asString().getValue())
                    propertyList.add(property)
                }
                appender.setProperties(propertyList)
            }
            configList.add(appender)
        }
        return configList
    }

    /**
     * Get logger configuarations.
     *
     * @param jsonValue basic configuration elements by parsing json file.
     * @return logger configuration list.
     */
    private func getLoggerConfiguration(jsonValue: JsonValue): ArrayList<LoggerConfig> {
        var loggerList: ArrayList<LoggerConfig> = ArrayList<LoggerConfig>()
        let loggers = jsonValue.asObject().get("loggers").getOrThrow()
        var jsArr: JsonArray = JsonValue.fromStr(loggers.toJsonString()).asArray()
        for (o in 0..jsArr.size()) {
            var logger: LoggerConfig = LoggerConfig()
            if (jsArr.get(o).getOrThrow().asObject().containsKey("name")) {
                logger.setName(jsArr.get(o).getOrThrow().asObject().get("name").getOrThrow().asString().getValue())
            }
            if (jsArr.get(o).getOrThrow().asObject().containsKey("level")) {
                logger.setLevel(jsArr.get(o).getOrThrow().asObject().get("level").getOrThrow().asString().getValue())
            }
            if (jsArr.get(o).getOrThrow().asObject().containsKey("appender-refs")) {
                var refList: ArrayList<AppenderRef> = ArrayList<AppenderRef>()
                var refArr: JsonArray = jsArr.get(o).getOrThrow().asObject().get("appender-refs").getOrThrow().asArray()
                for (i in 0..refArr.size()) {
                    var ref: AppenderRef = AppenderRef(
                        refArr.get(i).getOrThrow().asObject().get("ref").getOrThrow().asString().getValue()
                    )
                    refList.add(ref)
                }
                logger.setAppenderRefList(refList)
            }
            loggerList.add(logger)
        }
        return loggerList
    }

    /**
     * Get root configuarations.
     *
     * @param jsonValue basic configuration elements by parsing json file.
     * @return root configuration list.
     */
    private func getRootConfiguration(jsonValue: JsonValue): RootLoggerConfig {
        var configList: ArrayList<AppenderConfig> = ArrayList<AppenderConfig>()
        let appenders = jsonValue.asObject().get("root").getOrThrow()
        var jsObj: JsonObject = JsonValue.fromStr(appenders.toJsonString()).asObject()
        var root: RootLoggerConfig = RootLoggerConfig()
        var refList: ArrayList<AppenderRef> = ArrayList<AppenderRef>()
        if (jsObj.containsKey("level")) {
            root.setLevel(jsObj.get("level").getOrThrow().asString().getValue())
        }
        if (jsObj.containsKey("appender-refs")) {
            var jsArr: JsonArray = jsObj.get("appender-refs").getOrThrow().asArray()
            for (j in 0..jsArr.size()) {
                var ref: AppenderRef = AppenderRef(
                    jsArr.get(j).getOrThrow().asObject().get("ref").getOrThrow().asString().getValue()
                )
                refList.add(ref)
            }
            root.setAppenderRefList(refList)
        }
        return root
    }
}
