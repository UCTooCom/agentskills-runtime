package http_lib.client

import http_lib.core.{assertTrue, assertFalse}

@Test
public class SSEClientTest {

    @TestCase
    public func testSSEEventDefaults(): Unit {
        let event = SSEEvent()
        assertTrue(event.eventType == "message")
        assertTrue(event.data == "")
        assertTrue(event.eventId == "")
        assertTrue(event.lastEventId == "")
    }

    @TestCase
    public func testSSEEventCustom(): Unit {
        let event = SSEEvent(eventType: "update", data: "hello", eventId: "42", lastEventId: "41")
        assertTrue(event.eventType == "update")
        assertTrue(event.data == "hello")
        assertTrue(event.eventId == "42")
        assertTrue(event.lastEventId == "41")
    }

    @TestCase
    public func testCreateSSEClient(): Unit {
        let client = SSEClient("http://example.com/events")
        assertFalse(client.onMessage.isSome())
        assertFalse(client.onError.isSome())
        assertFalse(client.onOpen.isSome())
    }

    @TestCase
    public func testSetOnMessage(): Unit {
        let client = SSEClient("http://example.com/events")
        client.onMessage = {event => ()}
        assertTrue(client.onMessage.isSome())
    }

    @TestCase
    public func testSetOnError(): Unit {
        let client = SSEClient("http://example.com/events")
        client.onError = {msg => ()}
        assertTrue(client.onError.isSome())
    }

    @TestCase
    public func testSetOnOpen(): Unit {
        let client = SSEClient("http://example.com/events")
        client.onOpen = {=> ()}
        assertTrue(client.onOpen.isSome())
    }

    @TestCase
    public func testOnEventRegistration(): Unit {
        let client = SSEClient("http://example.com/events")
        client.on("custom", {event => ()})
        match (client.onEvent.get("custom")) {
            case Some(_) => assertTrue(true)
            case None => assertTrue(false, message: "custom event should be registered")
        }
    }

    @TestCase
    public func testCloseWithoutConnect(): Unit {
        let client = SSEClient("http://example.com/events")
        client.close()  // close() 不应抛出异常
        assertTrue(true)
    }
}
