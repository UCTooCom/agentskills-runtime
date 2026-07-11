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

package hyperion.logadapter

/**
 * 支持委托的Logger实现
 * 
 * @author yangfuping
 */
public abstract class AbstractDelegateLogger <: Logger {
    public open func getDelegate(): Logger

    public open func isTraceEnabled(): Bool {
        return getDelegate().isTraceEnabled()
    }

    public open func isDebugEnabled(): Bool {
        return getDelegate().isDebugEnabled()
    }

    public open func isInfoEnabled(): Bool {
        return getDelegate().isInfoEnabled()
    }

    public open func isWarnEnabled(): Bool {
        return getDelegate().isWarnEnabled()
    }

    public open func isErrorEnabled(): Bool {
        return getDelegate().isErrorEnabled()
    }

    public open func isFatalEnabled(): Bool {
        return getDelegate().isErrorEnabled()
    }

    public open func trace(message: String): Unit {
        return getDelegate().trace(message)
    }

    public open func trace(message: String, exception: Exception): Unit {
        return getDelegate().trace(message, exception)
    }

    public open func debug(message: String): Unit {
        return getDelegate().debug(message)
    }

    public open func debug(message: String, exception: Exception): Unit {
        return getDelegate().debug(message, exception)
    }

    public open func info(message: String): Unit {
        return getDelegate().info(message)
    }

    public open func info(message: String, exception: Exception): Unit {
        return getDelegate().info(message, exception)
    }

    public open func warn(message: String): Unit {
        return getDelegate().warn(message)
    }

    public open func warn(message: String, exception: Exception): Unit {
        return getDelegate().warn(message, exception)
    }

    public open func error(message: String): Unit {
        return getDelegate().error(message)
    }

    public open func error(message: String, exception: Exception): Unit {
        return getDelegate().error(message, exception)
    }

    public open func fatal(message: String): Unit {
        return getDelegate().error(message)
    }

    public open func fatal(message: String, exception: Exception): Unit {
        return getDelegate().error(message, exception)
    }

    public open func setLevel(level: LogLevel): Unit {
        return getDelegate().setLevel(level)
    }

    public open func getLevel(): LogLevel {
        return getDelegate().getLevel()
    }

    public open func isLoggable(level: LogLevel): Bool {
        return getDelegate().isLoggable(level)
    }

    public open func log(level: LogLevel, message: String): Unit {
        return getDelegate().log(level, message)
    }

    public open func log(level: LogLevel, message: String, exception: Exception): Unit {
        return getDelegate().log(level, message, exception)
    }

    public open func setOutput(outputstream: OutputStream): Unit {
        getDelegate().setOutput(outputstream)
    }
}

/**
 * 默认的支持委托的Logger实现
 *
 * @author yangfuping
 */
public open class DelegateLogger <: AbstractDelegateLogger {
    private let delegate: Logger

    public init(delegate: Logger) {
        this.delegate = delegate
    }

    public open func getDelegate(): Logger {
        return delegate
    }
}

/**
 * 委托到工厂的Logger实现
 * 支持延迟初始化Logger，并且可以替换Logger的LoggerFactory。
 *
 *
 * @author yangfuping
 */
public open class FactoryDelegateLogger <: AbstractDelegateLogger {
    private let name: String

    private var level: LogLevel

    private var factory: ILoggerFactory

    private var delegate: ?Logger = None

    private let mutex = Mutex()

    public init(factory: ILoggerFactory, name: String, level: LogLevel) {
        this.factory = factory
        this.name = name
        this.level = level
    }

    public open func setFactory(factory: ILoggerFactory) {
        this.factory = factory
        // 重新初始化delegate
        this.delegate = None
    }

    public open func setLevel(level: LogLevel): Unit {
        this.level = level
        if (let Some(delegate) <- delegate) {
            // 如果delegate已经初始化，则更新delegate的LogLevel
            delegate.setLevel(level)
        }
    }

    public open func getDelegate(): Logger {
        if (let Some(delegate) <- delegate) {
            return delegate
        }

        synchronized(mutex) {
            if (let Some(delegate) <- delegate) {
                return delegate
            }

            let logInstance = factory.getInstance(name)
            logInstance.setLevel(level)
            delegate = logInstance
            return logInstance
        }
    }

    public open func setOutput(outputstream: OutputStream): Unit {
        if (let Some(delegate) <- delegate) {
            // 如果delegate已经初始化，则更新OutputStream
            delegate.setOutput(outputstream)
        }
    }
}
