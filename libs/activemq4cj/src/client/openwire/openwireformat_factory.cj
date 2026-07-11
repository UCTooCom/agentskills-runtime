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
package activemq4cj.client.openwire

public class OpenWireFormatFactory <: WireFormatFactory {
    private var versionVal: Int32 = OpenWireContext.DEFAULT_WIRE_VERSION
    private var stackTraceEnabledVal: Bool = true
    private var tcpNoDelayEnabledVal: Bool = true
    private var cacheEnabledVal: Bool = true
    private var tightEncodingEnabledVal: Bool = true
    private var sizePrefixDisabledVal: Bool = false
    private var maxInactivityDurationVal: Int64 = 30 * 1000
    private var maxInactivityDurationInitalDelayVal: Int64 = 10 * 1000
    private var cacheSizeVal: Int32 = 1024
    private var maxFrameSizeVal: Int64 = OpenWireContext.DEFAULT_MAX_FRAME_SIZE
    private var maxFrameSizeEnabledVal: Bool = true
    private var hostVal: ?String = None
    private var providerNameVal: ?String = CommandTypes.PROVIDER_NAME
    private var providerVersionVal: ?String = None
    private var platformDetailsVal: ?String = CommandTypes.DEFAULT_PLATFORM_DETAILS

    /**
     * 创建wireFormatInfo命令和OpenwireFormat
     */
    public override func createWireFormat(): WireFormat {
        let info: WireFormatInfo = WireFormatInfo()
        info.version = version

        try {
            info.setStackTraceEnabled(stackTraceEnabled)
            info.setPlatformDetails(platformDetailsVal)
            info.setCacheEnabled(cacheEnabledVal)
            info.setTcpNoDelayEnabled(tcpNoDelayEnabledVal)
            info.setTightEncodingEnabled(tightEncodingEnabledVal)
            info.setSizePrefixDisabled(sizePrefixDisabledVal)
            info.setMaxInactivityDuration(maxInactivityDurationVal)
            info.setMaxInactivityDurationInitalDelay(maxInactivityDurationInitalDelayVal)
            info.setCacheSize(cacheSizeVal)
            info.setMaxFrameSize(maxFrameSizeVal)
            info.setMaxFrameSizeEnabled(maxFrameSizeEnabledVal)
            if (let Some(host) <- host) {
                info.setHost(host)
            }
            info.setProviderName(providerNameVal)
            info.setProviderVersion(providerVersionVal)
        } catch (e: Exception) {
            let ise: CJMSIllegalStateException = CJMSIllegalStateException("Could not configure WireFormatInfo")
            ise.linkedException = e
            throw ise
        }

        let f: OpenWireFormat = OpenWireFormat(version)
        f.setMaxFrameSize(maxFrameSize)
        f.setPreferedWireFormatInfo(info)
        f.setMaxFrameSizeEnabled(maxFrameSizeEnabled)
        return f
    }

    public mut prop version: Int32 {
        get() {
            return this.versionVal
        }
        set(value) {
            this.versionVal = value
        }
    }

    public mut prop stackTraceEnabled: Bool {
        get() {
            return this.stackTraceEnabledVal
        }
        set(value) {
            this.stackTraceEnabledVal = value
        }
    }

    public mut prop tcpNoDelayEnabled: Bool {
        get() {
            return this.tcpNoDelayEnabledVal
        }
        set(value) {
            this.tcpNoDelayEnabledVal = value
        }
    }

    public mut prop cacheEnabled: Bool {
        get() {
            return this.cacheEnabledVal
        }
        set(value) {
            this.cacheEnabledVal = value
        }
    }

    public mut prop tightEncodingEnabled: Bool {
        get() {
            return this.tightEncodingEnabledVal
        }
        set(value) {
            this.tightEncodingEnabledVal = value
        }
    }

    public mut prop sizePrefixDisabled: Bool {
        get() {
            return this.sizePrefixDisabledVal
        }
        set(value) {
            this.sizePrefixDisabledVal = value
        }
    }

    public mut prop maxInactivityDuration: Int64 {
        get() {
            return this.maxInactivityDurationVal
        }
        set(value) {
            this.maxInactivityDurationVal = value
        }
    }

    public mut prop maxInactivityDurationInitalDelay: Int64 {
        get() {
            return this.maxInactivityDurationInitalDelayVal
        }
        set(value) {
            this.maxInactivityDurationInitalDelayVal = value
        }
    }

    public mut prop cacheSize: Int32 {
        get() {
            return this.cacheSizeVal
        }
        set(value) {
            this.cacheSizeVal = value
        }
    }

    public mut prop maxFrameSize: Int64 {
        get() {
            return this.maxFrameSizeVal
        }
        set(value) {
            this.maxFrameSizeVal = value
        }
    }

    public mut prop maxFrameSizeEnabled: Bool {
        get() {
            return this.maxFrameSizeEnabledVal
        }
        set(value) {
            this.maxFrameSizeEnabledVal = value
        }
    }

    public mut prop host: ?String {
        get() {
            return this.hostVal
        }
        set(value) {
            this.hostVal = value
        }
    }

    public mut prop providerName: ?String {
        get() {
            return this.providerNameVal
        }
        set(value) {
            this.providerNameVal = value
        }
    }

    public mut prop providerVersion: ?String {
        get() {
            return this.providerVersionVal
        }
        set(value) {
            this.providerVersionVal = value
        }
    }

    public mut prop platformDetails: ?String {
        get() {
            return this.platformDetailsVal
        }
        set(value) {
            this.platformDetailsVal = value
        }
    }
}
