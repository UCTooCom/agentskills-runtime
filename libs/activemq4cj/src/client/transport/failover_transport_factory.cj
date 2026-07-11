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
package activemq4cj.client.transport

public class FailoverTransportFactory <: TransportFactory {
    public override func doConnect(location: URL): Transport {
        var transport = createTransport(URLSupport.parseComposite(location))
        transport = ResponseCorrelator(transport)
        return transport
    }

    public func createTransport(compositeData: CompositeData): Transport {
        let transport: FailoverTransport = FailoverTransport()

        if (let Some(params) <- compositeData.parameters) {
            //抽取nested.前缀参数
            let nestedOptions = IntrospectionSupport.extractProperties<?String>(params, "nested.")
            transport.nestedExtraQueryOptions = URLSupport.createQueryString(nestedOptions)

            var options = TypeConversionSupport.convertMap<String>(params)

            if (let Some(value) <- options.get("updateURIsURL")) {
                if (let Some(url) <- (value as Option<String>)) {
                    transport.updateURIsURL = url
                }
                options.remove("updateURIsURL")
            }
            if (let Some(value) <- options.get("priorityURIs")) {
                if (let Some(url) <- (value as Option<String>)) {
                    if (let Some(url) <- url) {
                        transport.setPriorityURIs(url)
                    }
                }
                options.remove("priorityURIs")
            }

            IntrospectionSupport.setProperties(transport, options)

            if (!options.isEmpty()) {
                throw ActiveMQException(
                    "There are ${options.size} options that couldn't be set on the FailoverTransport.Check the options are spelled correctly"
                )
            }
        }
        transport.add(false, compositeData.components)
        return transport
    }
}
