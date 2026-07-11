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
package activemq4cj.client

public class ActiveMQRESTMessagingClient {
    private var apiBaseUrl: URL
    private var userNameVal: ?String
    private var passwordVal: ?String
    private let clientIDVal: String
    private let clientVal: Client

    public init(userName: ?String, password: ?String, apiBaseUrl: String) {
        this(userName, password, URL.parse(apiBaseUrl))
    }

    public init(userName: ?String, password: ?String, apiBaseUrl: URL) {
        this.userNameVal = userName
        this.passwordVal = password
        this.apiBaseUrl = apiBaseUrl

        this.clientIDVal = IdGenerator().generateId()
        this.clientVal = ClientBuilder().cookieJar(CookieJar.createDefaultCookieJar(ArrayList<String>(), true)).build()
    }

    public func send(destination: Destination, body: String): ?String {
        let (form, name) = buildBaseFormAndName(destination)
        form.add("clientId", clientIDVal)

        if (let Some(name) <- name) {
            let requestURL = buildRequestURL(name, form.toEncodeString())

            let request = HttpRequestBuilder()
                .body("body=${body}")
                .url(requestURL.toString())
                .header("Content-Type", "application/x-www-form-urlencoded")
                .post()
                .build()
            var response = clientVal.send(request)
            if (let Some(bodySize) <- response.bodySize) {
                let reader = StringReader(response.body)
                return reader.readToEnd()
            }
        }
        return None
    }

    public func receive<T>(destination: Destination, selector!: ?String = None): ?T where T <: JsonDeserializable<T> {
        let (form, name) = buildBaseFormAndName(destination)
        form.add("json", "true")

        if (let Some(name) <- name) {
            let requestURL = buildRequestURL(name, form.toEncodeString())

            let requestBuilder = HttpRequestBuilder().url(requestURL.toString()).get()

            if (let Some(selector) <- selector) {
                requestBuilder.header("selector", selector)
            }

            try {
                let response = clientVal.send(requestBuilder.build())
                let jsonReader = JsonReader(response.body)
                return jsonReader.readValue<T>()
            } catch (e: HttpTimeoutException) {
                return None
            }
        }
        return None
    }

    private func buildBaseFormAndName(destination: Destination): (Form, ?String) {
        let form: Form = Form()
        var name: ?String = None

        if (let Some(queue) <- (destination as Queue)) {
            form.add("type", "queue")
            name = queue.getQueueName()
        } else if (let Some(topic) <- (destination as Topic)) {
            form.add("type", "topic")
            name = topic.getTopicName()
        }

        return (form, name)
    }

    private func buildRequestURL(pathComponent: String, query: String): URL {
        let userInfoString = getUserInfoString()
        return apiBaseUrl.replace(
            userInfo: userInfoString,
            path: apiBaseUrl.path + "/" + pathComponent,
            query: query
        )
    }

    private func getUserInfoString(): String {
        var userInfo: ?UserInfo = None
        if (let Some(userName) <- userNameVal) {
            userInfo = UserInfo(userName, passwordVal)
        }

        if (let Some(userInfo) <- userInfo) {
            return userInfo.toString()
        }
        return ""
    }

    public func close(): Unit {
        clientVal.close()
    }
}
