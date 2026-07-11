# ActiveMQ仓颉语言客户端用户手册

## 第1章 ActiveMQ仓颉语言客户端介绍

### 1.1 简介
仓颉原生ActiveMQ客户端。 <br>
依赖库为[Hyperion TCP框架](https://gitcode.com/Cangjie-TPC/hyperion.git)，由[北京宝兰德软件股份有限公司](https://www.bessystem.com)实现。<br>
API设计参考如下项目： <br>
https://github.com/apache/activemq <br>

### 1.2 特性
1. 完全实现JMS2.0规范，支持点对点和发布订阅模式，支持事务消息
2. 消息头和自定义属性支持，支持StreamMessage、MapMessage、BytesMessage、ObjectMessage、TextMessage
3. 支持OpenWire协议，支持OpenWire协议所支持的loose encoding和tight encoding两种序列化方式，支持使用命令缓存
4. 支持失效转移
5. 支持TLS通信
6. 支持单连接多线程模式
7. 完备的单元测试覆盖
8. 架构简洁，易于扩展

### 1.3 获取ActiveMQ仓颉语言客户端
ActiveMQ仓颉语言客户端项目托管在gitcode上，项目地址为：<br>
[https://gitcode.com/Cangjie-TPC/activemq4cj/](https://gitcode.com/Cangjie-TPC/activemq4cj/)

使用git下载ActiveMQ仓颉语言客户端：<br/>
`> git clone https://gitcode.com/Cangjie-TPC/activemq4cj.git`

### 1.4 通过源码方式引入ActiveMQ客户端依赖
仓颉0.53.4以上版本：在项目的cjpm.toml中添加dependencies引入activemq_sdk依赖：

```
[dependencies]
  activemq4cj = {git = "https://gitcode.com/Cangjie-TPC/activemq4cj.git", branch = "main", version = "1.0.0"}
```

更新依赖，运行cjpm update会自动下载依赖activemq4cj项目到~/.cjpm目录下<br>
`$> cjpm update`

### 1.5 编译ActiveMQ仓颉语言客户端
更新依赖，运行cjpm update会自动下载依赖Hyperion TCP框架<br>
`$> cjpm update`

如果更新依赖失败可以参考"1.6 手动下载依赖"

清理工程，在工程根目录下运行：<br>
`$> cjpm clean`

编译工程，在工程根目录下运行：<br>
`$> cjpm build`

编译生成的静态库文件存放在 `./target/release/activemq4cj`和`./target/release/hyperion`目录下

### 1.6 手动下载依赖
在activemq4cj工程的根目录下执行：<br/>
`> git clone https://gitcode.com/Cangjie-TPC/hyperion.git`

仓颉0.53.4以上版本：修改cjpm.toml中的dependencies使用本地依赖：

```
[dependencies]
hyperion = { path = "./hyperion"}
```

### 1.7 在项目中引入ActiveMQ仓颉客户端的静态库依赖

引入编译好的静态库依赖和通过源码方式引入依赖，任意选取一种方式即可。 参考"1.4 通过源码方式引入ActiveMQ客户端依赖"。

仓颉0.53.4以上版本，需要先确定平台对应的target-name：<br>

例如Windows X64平台执行`cjc -v`命令返回如下：

```
$cjc -v
Cangjie Compiler: 0.53.4 (cjnative)
Target: x86_64-w64-mingw32
```

例如Linux X64平台执行`cjc -v`命令返回如下：

```
$cjc -v
Cangjie Compiler: 0.53.4 (cjnative)
Target: x86_64-unknown-linux-gnu
```

在工程的cjpm.toml中添加平台对应的二进制依赖，以Linux X64为例：

```
[target.x86_64-unknown-linux-gnu.bin-dependencies]
  path-option = ["${path_to_activemq4cj}/target/release/hyperion", "${path_to_activemq4cj}/target/release/activemq4cj"]
```

### 1.8 单元测试

修改test/environment.json，将根节点下的host和port更改为ActiveMQ服务的监听地址和端口：<br>
```
    {
        "host": "127.0.0.1",
        "port": "61616",
        "userName": "admin",
        "password": "admin",
    }
```
其余参数根据需要进行修改。

在工程test/UT目录下运行：<br>
`$> cjpm test`

## 第2章 使用JMS规范的经典API收发消息

### 2.1 创建连接工厂

ActiveMQConnectionFactory是用于创建连接的工厂类，封装了诸多JMS配置参数，客户端使用它创建与ActiveMQ服务的连接。<br>
ActiveMQConnectionFactory提供了多个构造函数来获取实例：

| 构造函数                                                                                                        | 作用                                                           |
|---------------------------------------------------------------------------------------------------|----------------------------------------------------------------|
| init()                                 | 无参构造函数，使用默认的host和port           |
| init(brokerURL: String)                | 需要用户提供一个字符串类型的ActiveMQ服务URL       |
| init(brokerURL: URL)                   | 接受一个由仓颉标准库的URL类构造的ActiveMQ服务URL |
| init(userName: String, password: String, brokerURL: String) | 需要用户提供名称密码和一个字符串类型的ActiveMQ服务URL |
| init(userName: String, password: String, brokerURL: URL) | 需要用户提供名称密码和一个URL类型的ActiveMQ服务URL |

按需选择一个构造函数完成ActiveMQConnectionFactory实例的创建，例如：
```
let connectionFactory = ActiveMQConnectionFactory("admin", "admin", "tcp://localhost:61616")
```

同时ActiveMQConnectionFactory还提供了相当完善的JMS属性配置，使用ActiveMQConnectionFactory进行一个或多个属性配置后，这些属性会传递到后续使用该工厂创建的连接上。例如：

```cangjie
//启用异步发送
connectionFactory.useAsyncSend = true
//启用优化确认
connectionFactory.optimizeAcknowledge = true
```

除此之外，客户端还提供了在连接URL上设置JMS属性的方法，例如：
```cangjie
tcp://localhost:61616?jms.useCompression=true
```
记得要使用jms.前缀，否则无法生效。更多参数及其含义请看第6章第2节的介绍。

### 2.2 创建连接

前文已经介绍了ActiveMQConnectionFactory，现在我们使用ActiveMQConnectionFactory来创建一个连接。
```cangjie
let connectionFactory = ActiveMQConnectionFactory("admin", "admin", "tcp://localhost:61616")
var connection = connectionFactory.createConnection()
//或者使用自己提供的用户凭据来创建连接
connection = connectionFactory.createConnection("admin", "admin")
```
这里所创建的连接是CJMS标准接口提供的Connection接口，它是严格实现JMS规范的。还可以把connection对象转换为ActiveMQConnection类型（ActiveMQConnection是Connection接口的默认实现），这样我们就可以使用连接来进行一些JMS属性的配置。
```cangjie
if (let Some(connection) <- connection as ActiveMQConnection) {
    // 禁用异步发送
    connection.useAsyncSend = false
    // 禁用优化确认
    connection.optimizeAcknowledge = false
    // 启用消息体压缩
    connection.useCompression = true
}
```
当一个连接刚刚被创建时，它还处于stopped mode，即此时消息无法到达连接，需要调用start方法来启动连接，此后消息可以抵达由该连接创建的消费者们。值得一提的是，stopped mode仅仅影响消息的接收，而不影响消息的发送。
```cangjie
//启动连接
connection.start()
```

最后，在不需要使用连接时应调用close方法将其关闭，或者在创建连接时使用try-with-resources， 这样连接在代码块执行完成后将自动关闭而无需调用close方法。<br>
```cangjie
// 使用try-with-resources创建连接
let connectionFactory = ActiveMQConnectionFactory("admin", "admin", "tcp://127.0.0.1:61616")
try (connection = connectionFactory.createConnection()) {
    connection.start()
    //其它业务代码
}
```

### 2.3 创建会话

会话由连接创建，我们可以选择一个会话模式 <br>
```cangjie
//使用try-with-resources创建一个使用自动确认模式的会话
try (session = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)) {
    //其它业务代码           
}
```

会话提供了一系列的工厂方法来方便用户创建消息、目的地、生产者和消费者。<br>

| 方法                                                                                                        | 作用                                                           |
|----------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------|
| createMessage(): CJMSMessage                                 | 创建一个符合JMS规范的消息          |
| createObjectMessage(): ObjectMessage                | 创建一个对象消息       |
| createBrowser(queue: Queue): QueueBrowser                   | 创建一个队列的浏览者 |
| createQueue(queueName: String): Queue | 创建一个队列 |
| createTopic(topicName: String): Topic | 创建一个主题 |
| createDurableConsumer(topic: Topic, name: String): MessageConsumer | 创建一个持久订阅消费者 |
| createConsumer(destination: Destination): MessageConsumer | 创建一个消费者 |
| createProducer(destination: Destination): MessageProducer | 创建一个生产者 |

此外，会话还支持事务模式，可以使用以下方法进行事务操作 <br>

| 方法                                                                                                        | 作用                                                           |
|-------------------------------------------------------------------|----------------------------------------------------------------|
| commit(): Unit                                 | 提交事务          |
| rollback(): Unit               | 回滚提交的消息       |
| recover(): Unit                    | 停止并使用第一条未确认的消息重新启动会话 |
 
### 2.4 创建生产者

客户端使用生产者向ActiveMQ服务发送消息，现在使用会话创建生产者并尝试发送一些消息。<br>

```cangjie
let connectionFactory = ActiveMQConnectionFactory("admin", "admin", "tcp://127.0.0.1:61616")
try (connection = connectionFactory.createConnection()) {
    connection.start()
    //创建会话
    try (session = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)) {
        //使用会话创建一条文本消息
        let textMsg = session.createTextMessage()
        //设置文本消息的内容
        textMsg.text = "Hello"
        //使用会话创建一个队列
        let queue = session.createQueue("TEST")
        //使用队列创建生产者
        try (producer = session.createProducer(queue)) {
            //发送消息
            producer.send(textMsg)
        }
    }
}
```

在事务模式下发送消息需要配合使用会话的commit方法，否则消息将无法生效。相反的是，如需要撤回发送的消息，调用rollback方法即可。使用例子： <br>
```cangjie
let connectionFactory = ActiveMQConnectionFactory("admin", "admin", "tcp://127.0.0.1:61616")
try (connection = connectionFactory.createConnection()) {
    connection.start()
    //创建会话
    try (session = connection.createSession(true, AcknowledgeMode.SESSION_TRANSACTED)) {
        //使用会话创建一个队列
        let queue = session.createQueue("TEST")
        //创建生产者
        try (producer = session.createProducer(queue)) {
            //发送10条消息
            for(i in 0..10) {
                let textMsg = session.createTextMessage("Hello${i}")
                producer.send(textMsg)
            }
            //提交事务
            session.commit()
        }
    }
}
```

生产者支持发送持久化或非持久化消息，也可以设置消息的存活时间，禁用时间戳等。
```cangjie
//消息存活时间（毫秒）
producer.timeToLive = 3000
//禁用时间戳
producer.disableMessageTimestamp = true
//非持久化消息
producer.deliveryMode = DeliveryMode.NON_PERSISTENT
//设置消息的优先级
producer.priority = 9
```

### 2.5 创建消费者

客户端使用消费者接收消息，可以使用会话创建消费者，以下是三种同步接收消息的方法：<br>

```cangjie
let connectionFactory = ActiveMQConnectionFactory("admin", "admin", "tcp://127.0.0.1:61616")
try (connection = connectionFactory.createConnection()) {
    connection.start()
    //创建会话，使用自动确认模式
    try (session = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)) {
        //使用会话创建一个队列
        let queue = session.createQueue("TEST")
        //创建消费者
        try (consumer = session.createConsumer(queue)) {
            //以下三种receive方法按照需要选择一种即可

            //在指定的超时时间内接收消息
            var msg: ?CJMSMessage = consumer.receive(Duration.second * 1)
            //阻塞直到接收消息
            msg = consumer.receive()
            //立即接收一条消息，如果客户端没有消息可供接收则返回None
            msg = consumer.receiveNoWait()
        }
    }
}
```

使用MessageListener实例异步接收消息：

```cangjie
import serialization.serialization.*
import std.time.Duration
import activemq4cj.client.*
import activemq4cj.client.command.*
import activemq4cj.cjms.*
import activemq4cj.cjms.Message as CJMSMessage

main(): Unit {
    let connectionFactory = ActiveMQConnectionFactory("admin", "admin", "tcp://127.0.0.1:61616")
    try (connection = connectionFactory.createConnection()) {
        connection.start()
        //创建会话，使用自动确认模式
        try (session = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)) {
            //使用会话创建一个队列
            let queue = session.createQueue("TEST")
            //创建消费者
            try (consumer = session.createConsumer(queue)) {
                //使用MessageListener异步消费消息
                consumer.messageListener = MyMessageListener()
            }
        }
    }
}

class MyMessageListener <: MessageListener {
    public func onMessage(message: CJMSMessage): Unit {
    }
}
```

在事务模式下消费消息： <br>

```cangjie
import serialization.serialization.*
import std.time.Duration
import activemq4cj.client.*
import activemq4cj.client.command.*
import activemq4cj.cjms.*
import activemq4cj.cjms.Message as CJMSMessage

main(): Unit {
    let connectionFactory = ActiveMQConnectionFactory("admin", "admin", "tcp://127.0.0.1:61616")
    try (connection = connectionFactory.createConnection()) {
        connection.start()
        //创建会话，使用事务模式
        try (session = connection.createSession(true, AcknowledgeMode.SESSION_TRANSACTED)) {
            //使用会话创建一个队列
            let queue = session.createQueue("TEST")
            //创建消费者
            try (consumer = session.createConsumer(queue)) {
                //接收多条消息
                for (i in 0..10) {
                    var msg = consumer.receive(Duration.millisecond * 1000)
                }
                //使用commit提交确认
                session.commit()
            }
        }
    }
}
```

使用手动确认模式消费消息：
```cangjie
import serialization.serialization.*
import std.time.Duration
import activemq4cj.client.*
import activemq4cj.client.command.*
import activemq4cj.cjms.*
import activemq4cj.cjms.Message as CJMSMessage

main(): Unit {
    let connectionFactory = ActiveMQConnectionFactory("admin", "admin", "tcp://127.0.0.1:61616")
    try (connection = connectionFactory.createConnection()) {
        connection.start()
        //创建会话，使用手动确认模式
        try (session = connection.createSession(false, AcknowledgeMode.CLIENT_ACKNOWLEDGE)) {
            //使用会话创建一个队列
            let queue = session.createQueue("TEST")
            //创建消费者
            try (consumer = session.createConsumer(queue)) {
                //接收多条消息
                for (i in 0..10) {
                    var msg = consumer.receive(Duration.millisecond * 1000)
                }
                //使用acknowledge批量提交确认
                session.acknowledge()
            }
        }
    }
}
```

### 2.6 创建持久订阅消费者

客户端支持持久订阅，使用持久订阅时需要连接有唯一的clientID，如下：

```cangjie
import serialization.serialization.*
import std.time.Duration
import activemq4cj.client.*
import activemq4cj.client.command.*
import activemq4cj.cjms.*
import activemq4cj.cjms.Message as CJMSMessage

main(): Unit {
    let connectionFactory = ActiveMQConnectionFactory("admin", "admin", "tcp://127.0.0.1:61616")
    try (connection = connectionFactory.createConnection("admin", "admin")) {
        //设置一个客户端ID
        connection.setClientID("CLIENT:1")
        connection.start()

        try (session = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)) {
            //创建一个主题
            let topic = session.createTopic("TEST.TOPIC")
            //创建生产者和持久订阅消费者
            try (producer = session.createProducer(topic), consumer = session.createDurableConsumer(topic, "SUB")) {
                for (i in 0..50) {
                    producer.send(session.createTextMessage("${i}"))
                }

                for (i in 0..50) {
                    var msg: ?CJMSMessage = consumer.receive(Duration.second)
                    if (let Some(msg) <- msg) {
                        if (let Some(textMsg) <- msg as TextMessage) {
                            println(textMsg.text)
                        }
                    }
                }
            }
        }
    }
}
```


## 第3章 使用JMS规范的简化API收发消息

### 3.1 创建CJMSContext

CJMSContext是JMS简化API中的核心概念，它合并了连接和会话的行为，在简化API中不再使用连接和会话。<br>

连接工厂提供了四种方法来创建CJMSContext：

| 方法                                                                                                        | 作用                                                           |
|---------------------------------------------------------------------------------------------------|----------------------------------------------------------------|
| createContext(): CJMSContext                            | 创建新的context           |
| createContext(userName: String, password: String): CJMSContext                | 用给定的用户名和密码创建新的context      |
| createContext(userName: String, password: String, sessionMode: AcknowledgeMode): CJMSContext   | 用给定的用户名、密码和ackMode创建新的context |
| createContext(sessionMode: AcknowledgeMode): CJMSContext | 用给定的ackMode创建新的context |

按需选择一个方法创建CJMSContext，例如： <br>

```cangjie
let connectionFactory = ActiveMQConnectionFactory("admin", "admin", "tcp://127.0.0.1:61616")
try (context = connectionFactory.createContext("admin", "admin", AcknowledgeMode.CLIENT_ACKNOWLEDGE)) {
    let queue = context.createQueue("TEST")
}
```

### 3.2 创建CJMSProducer
CJMSProducer是简化API中的消息生产者，可以向ActiveMQ发送消息。   <br>

```cangjie
let connectionFactory = ActiveMQConnectionFactory("admin", "admin", "tcp://127.0.0.1:61616")
try (context = connectionFactory.createContext("admin", "admin", AcknowledgeMode.AUTO_ACKNOWLEDGE)) {
    let queue = context.createQueue("TEST")
    let producer: CJMSProducer = context.createProducer()
    producer.send(queue, "TEST")
}
```

### 3.3 创建CJMSConsumer
CJMSConsumer是简化API中的消息消费者，可以从ActiveMQ接收消息，CJMSConsumer的使用方法与MessageConsumer一致。   <br>

```cangjie
let connectionFactory = ActiveMQConnectionFactory("admin", "admin", "tcp://127.0.0.1:61616")
try (context = connectionFactory.createContext("admin", "admin", AcknowledgeMode.AUTO_ACKNOWLEDGE)) {
    let queue = context.createQueue("TEST")
    //创建消费者
    try (consumer: CJMSConsumer = context.createConsumer(queue)) {
        var msg: ?CJMSMessage = consumer.receive(Duration.second)
        if (let Some(msg) <- msg) {
            if (let Some(textMsg) <- msg as TextMessage) {
                println(textMsg.text)
            }
        }
    }
}
```

### 3.4 CJMSContext使用事务收发消息

```cangjie
let connectionFactory = ActiveMQConnectionFactory("admin", "admin", "tcp://127.0.0.1:61616")
try (context = connectionFactory.createContext("admin", "admin", AcknowledgeMode.SESSION_TRANSACTED)) {
    let queue = context.createQueue("TEST")
    //创建生产者
    let producer: CJMSProducer = context.createProducer()
    for (i in 0..10) {
        producer.send(queue, "SESSION_TEST${i}")
    }
    //使用CJMSContext提交事务
    context.commit()

    //创建消费者
    try (consumer: CJMSConsumer = context.createConsumer(queue)) {
        while (consumer.receive(Duration.second).isSome()) {
        }
        //使用CJMSContext撤销接收到的消息
        context.rollback()
    }
}
```

## 第4章 使用失效转移模式

失效转移是在其它传输层之上的重连逻辑，配置语法允许用户指定任意数量的URI。失效转移随机选择一个URI，并尝试建立与它的连接。如果失败或随后失败，则从列表中随机选择其他URI之一建立新的连接。<br>

配置语法：
```
failover:(uri1,...,uriN)?transportOptions&nestedURIOptions
```

配置例子：
```
failover:(tcp://localhost:61616,tcp://remotehost:61616)?initialReconnectDelay=100
```

使用示例：

```
import std.time.Duration
import activemq4cj.client.*
import activemq4cj.client.command.*
import activemq4cj.cjms.*

main(): Unit {
    //创建连接工厂，注意：URI要使用failover语法
    let connectionFactory: ConnectionFactory = ActiveMQConnectionFactory("admin", "admin",
        "failover:(tcp://127.0.0.1:61616,127.0.0.1:61626)?maxReconnectAttempts=5&timeout=3000&nested.wireFormat.cacheEnabled=true&nested.wireFormat.cacheSize=10240")

    //创建连接
    try (connection: Connection = connectionFactory.createConnection()) {
        //启动连接，避免无法接收消息
        connection.start()
        //创建session，模式为自动确认
        try (session: Session = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)) {

            //使用会话创建一个文本消息
            let textMessage: TextMessage = session.createTextMessage()
            textMessage.text = "Hello"

            //创建一个队列
            let queue: Destination = ActiveMQQueue("TEST")

            //创建消息生产者和消息消费者
            try (producer: MessageProducer = session.createProducer(queue), consumer: MessageConsumer = session.createConsumer(queue)) {
                //使用生产者发送刚刚创建的文本消息
                producer.send(textMessage)
                //接收刚才发送的消息
                let message = consumer.receive(Duration.millisecond * 1000)
                if (let Some(msg) <- message) {
                    if (let Some(msg) <- msg as ActiveMQTextMessage) {
                        println(msg.text)
                    }
                }
            }
        }
    }
}
```

## 第5章 使用TLS通信

首先需要使用TLS证书创建TlsClientConfig
```
let pem = String.fromUtf8(File("~/user.pem", OpenOption.Open(true, false)).readToEnd())
let keyPem = String.fromUtf8(File("~/user.key", OpenOption.Open(true, false)).readToEnd())
var config = TlsClientConfig()
config.verifyMode = TrustAll
config.alpnProtocolsList = ["h2"]
config.clientCertificate = (X509Certificate.decodeFromPem(pem), PrivateKey.decodeFromPem(keyPem))
```

使用支持TLS通信的ActiveMQTlsConnectionFactory创建连接即可使用TLS收发消息

```
//创建连接工厂
let connectionFactory = ActiveMQTlsConnectionFactory("admin", "admin", "tcp://127.0.0.1:61616")

//使用刚刚创建的TlsClientConfig
connectionFactory.setTlsClientConfig(config)

try (connection = connectionFactory.createConnection()) {
    connection.start()

    try (session = connection.createSession(false, AcknowledgeMode.AUTO_ACKNOWLEDGE)) {
        let textMessage = session.createTextMessage()
        textMessage.text = "TLS_TEST"

        let queue: Destination = session.createQueue("TEST")

        try (producer = session.createProducer(queue), consumer = session.createConsumer(queue)) {
            producer.send(textMessage)

            let message = consumer.receive()
            if (let Some(msg) <- message) {
                if (let Some(msg) <- msg as ActiveMQTextMessage) {
                    println(msg.text)
                }
            }
        }
    }
}
```

## 第6章 客户端详细配置

### 6.1 客户端支持的协议

| 协议                          | 示例                                                           | 描述                     |
|-------------------------------|----------------------------------------------------------------| -------------------------|
| TCP                           | tcp://host:port                                                | 客户端通过给定的URI连接到Broker                         |
| Failover                      | failover:(Uri1,Uri2,Uri3,…,UriN)                              | 给定一个连接URI的列表，在连接时随机选择一个，在失败后自动选择其它的连接进行消息传输          |

### 6.2 连接URI配置

可以通过URI语法显式地设置ActiveMQConnection、ActiveMQConnectionFactory对象的属性来配置连接。<br>
使用jms.前缀在连接URI上设置jms属性，参考这个例子：

```
tcp://localhost:61616?jms.useAsyncSend=true
```

以下是客户端支持的jms属性列表，需要注意的是必须要使用jms.前缀，否则无效。

| 属性名                        | 默认值                                                           | 描述                     |
|-------------------------------|----------------------------------------------------------------| -------------------------|
| alwaysSessionAsync            | true                                                | 为true时Session会启用额外的线程为消费者调度消息                         |
| alwaysSyncSend                | false                            | 为true时生产者总是使用同步的方式发送消息          |
| auditDepth                    | 2048                           | 对重复和无序消息进行审核的消息窗口的大小          |
| auditMaximumProducerNumber    | 64                           | 被审核的生产者的最大数量          |
| checkForDuplicates            | true                           | 为true时对消息进行幂等处理          |
| clientID                      | None                           | 为连接设置一个客户端ID          |
| closeTimeout                  | 15000                           | 设置连接关闭的超时时间（毫秒数）          |
| consumerExpiryCheckEnabled    | true                           | 为true时消费者会对消息进行过期检查，关闭此选项可能会收到过期消息          |
| copyMessageOnSend             | true                           | 发送时使用复制的消息以防止消息被更改          |
| disableTimeStampsByDefault    | false                           | 为true时禁用消息时间戳          |
| dispatchAsync                 | false                           | 为true时Broker使用异步的方式向消费者发送消息          |
| optimizeAcknowledge           | false                           | 为true时启用优化确认，消息分批确认而不是单独确认          |
| optimizeAcknowledgeTimeOut    | 300                           | 优化确认的批量确认之间的最大间隔          |
| optimizedAckScheduledAckInterval    | 0                           | 大于0时周期性地发送消息确认          |
| optimizedMessageDispatch    | true                           | 为true时为持久订阅使用更大的预取大小          |
| useAsyncSend                 | false                           | 为true时强制使用异步发送，可能会导致消息丢失          |
| useCompression                 | false                           | 为true时启用消息体压缩          |
| useRetroactiveConsumer                 | false                           | 为true时允许非持久订阅者接收订阅前的消息          |
| nonBlockingRedelivery                 | false                           | 为true时允许消息乱序传递         |

还可以在连接URI上使用jms.redeliveryPolicy.前缀进行嵌套的RedeliveryPolicy对象配置，使用如下：

```
tcp://localhost:61616?jms.redeliveryPolicy.maximumRedeliveries=5
```

RedeliveryPolicy所有可用的参数见下表：

| 属性名                        | 默认值                                                           | 描述                     |
|-------------------------------|----------------------------------------------------------------| -------------------------|
| backOffMultiplier             | 5                                                | 重连时间间隔递增倍数，只有大于1和启用useExponentialBackOff参数时才生效                         |
| collisionAvoidanceFactor      | 0.15                             | 设置防止冲突范围的正负百分比，只有启用useCollisionAvoidance参数时，才生效，在延迟时间上再加一个时间的波动范围          |
| initialRedeliveryDelay        | 1000                             | 初始重发延迟时间          |
| maximumRedeliveries           | 6                             | 最大重试次数，达到最大重连次数后抛出异常，-1表示不限制次数，0表示不进行重传          |
| maximumRedeliveryDelay        | -1                             | 最大传送延迟，只在useExponentialBackOff为true时有效。假设重连间隔10ms，倍数为2，第二次重连间隔为20ms，第三次重连间隔是40ms，当重连最大时间间隔达到直达重连时间间隔时，以后每次重连时间间隔都为最大重连时间间隔          |
| redeliveryDelay               | 1000                             | 重发延迟时间，当initialRedeliveryDelay=0时生效          |
| useCollisionAvoidance               | false                             | 启用防止冲突功能          |
| useExponentialBackOff               | false                             | 启用指数倍数递增的方式增加延迟时间          |

### 6.3 WireFormat参数配置

客户端使用OpenWire协议与ActiveMQ服务进行通信，可以通过设置OpenWire选项来自定义消息的传输方式。<br>

配置例子：
```
var cf = ActiveMQConnectionFactory("tcp://localhost:61616?wireFormat.cacheEnabled=false&wireFormat.tightEncodingEnabled=false")
```

需要注意的是，必须要使用wireFormat.前缀，否则设置无效。以下是客户端支持的OpenWire参数列表：

| 属性名                        | 默认值                                                           | 描述                     |
|-------------------------------|----------------------------------------------------------------| -------------------------|
| cacheEnabled            | true                                                | 为经常使用的命令启用缓存                         |
| cacheSize                | 1024                            | 当启用缓存时，指定要缓存的命令数量          |
| maxInactivityDuration                    | 30000                           | 最大非活跃时间，超过此时间没有命令收发则连接会被关闭，用于保持心跳          |
| maxInactivityDurationInitalDelay    | 10000                           | 检查心跳前的延迟         |
| maxFrameSize            | 64位有符号数的最大值                           | 最大数据帧的大小          |
| maxFrameSizeEnabled                      | true                           | 是否检查数据帧的大小          |
| stackTraceEnabled                  | true                           | 开启后服务端会把异常栈发送给客户端          |
| tcpNoDelayEnabled    | true                           | 启用TCP_NODELAY          |
| tightEncodingEnabled             | true                           | 使用更紧凑的命令封装但是会增加cpu开销          |

### 6.4 失效转移参数配置

失效转移是在当前通信层的上层构建的重连逻辑，当连接失败后，失效转移会重新随机选择一个URI进行重连，恢复通信。

URI语法：

```
failover:(uri1,...,uriN)?transportOptions&nestedURIOptions
```

配置例子：

```
failover:(tcp://localhost:61616,tcp://remotehost:61616)?initialReconnectDelay=100
```

#### 6.4.1 连接参数

| 属性名                        | 默认值                                                           | 描述                     |
|-------------------------------|----------------------------------------------------------------| -------------------------|
| backup            | false                                                | 连接时创建备份连接，以方便快速失效转移                         |
| initialReconnectDelay                | 10                            | 表示第一次尝试重连之前等待的时间（毫秒）          |
| maxCacheSize                    | 131072                           | 如果trackMessages为true，该值表示缓存消息的最大大小，单位字节          |
| maxReconnectAttempts    | -1                           | -1代表无限重试，0代表禁止重连，正数代表重连次数         |
| maxReconnectDelay            | 3000                           | 第二次和后续重新连接尝试之间的最大延迟（毫秒）          |
| nested.*                      | None                           | 通用URI选项，应用在每个URI上          |
| randomize                  | true                           | 表示在URI列表中选择URI连接时是否采用随机策略          |
| reconnectDelayExponent    | 2.0                           | 重连时使用的避让指数          |
| reconnectSupported             | true                           | 客户端是否应使用重新连接来响应Broker的ConnectionControl事件         |
| startupMaxReconnectAttempts             | -1                           | 值-1表示启动时的连接尝试次数应该是无限的。值>=0表示启动时将进行的重新连接尝试的次数          |
| timeout             | -1                           | 是否允许在重连过程中设置超时时间来中断的正在阻塞的发送操作（毫秒）        |
| trackMessages             | false                           | 是否缓存在发送中的消息，以便重连时让新的Transport继续发送          |
| updateURIsSupported             | true                           | 表示重连时客户端新的连接是否从消息服务接受接受原来的URI列表的更新          |
| updateURIsURL             | None                           | ActiveMQ支持从文件中加载Failover的URI地址列表，URI以逗号分隔，updateURIsURL是文件路径         |
| useExponentialBackOff             | true                           | 表示重连时是否加入避让指数来避免高并发          |
| warnAfterReconnectAttempts             | 10                           | 表示每次重连该次数后会打印日志告警          |

#### 6.4.2 优先级备份

使用priorityBackup和priorityURIs两个参数指定优先的URI，默认情况下，只有列表中的第一个连接URI被认为是优先的，如下所示：

```
failover:(tcp://local:61616,tcp://remote:61616)?randomize=false&priorityBackup=true
```

如果需要有多个URI被视为优先，使用priorityURIs参数，例如：

```cangjie
failover:(tcp://local1:61616,tcp://local2:61616,tcp://remote:61616)?randomize=false&priorityBackup=true&priorityURIs=tcp://local1:61616,tcp://local2:61616
```

#### 6.4.3 配置嵌套URI选项

可以使用nested.前缀将通用的参数项追加到failoverURI的后面，这些通用配置会对每个连接生效。例如：

```
failover:(tcp://broker1:61616,tcp://broker2:61616,tcp://broker3:61616)?nested.wireFormat.maxInactivityDuration=1000
```

### 6.5 Destination参数配置

Destination参数使用URI语法配置在队列的名称中，这些参数会在消费者创建时应用。下面是一个使用例子：

```cangjie
let queue = ActiveMQQueue("TEST.QUEUE?consumer.dispatchAsync=false&consumer.prefetchSize=10")
```

所有受支持的消费者参数见下表：

| 属性名                        | 默认值                                                           | 描述                     |
|-------------------------------|----------------------------------------------------------------| -------------------------|
| consumer.dispatchAsync            | true                                                | Broker是否使用异步的方式将消息发送给消费者                         |
| consumer.exclusive                | false                            | 是否独占消费          |
| consumer.maximumPendingMessageLimit    | 0                           | 控制在慢消费的情况下是否删除非持久的主题消息          |
| consumer.noLocal    | false                           |          |
| consumer.prefetchSize            | n/a                           | 消费者预取消息的数量          |
| consumer.priority                      | 0                           | 消费者的优先级          |
| consumer.retroactive                 | false                           | 是否是回溯消费者          |
| consumer.selector    | None                           | 消息选择器          |