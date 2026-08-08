package sample_server

import http_lib.core.*
import http_lib.message.*
import http_lib.router.Router
import http_lib.server.{HttpServer, HttpServerConfig}
import std.collection.{HashMap, ArrayList}
import kaca_json.JsonValue

/**
 * 使用 kaca_json 库构建 JSON 响应的辅助函数
 */
func jsonObject(): HashMap<String, JsonValue> {
    HashMap<String, JsonValue>()
}



func handleRoot(req: HttpRequest): HttpResponse {
    let obj = jsonObject()
    obj["service"] = JsonValue.JsonString("http_lib")
    obj["version"] = JsonValue.JsonString("0.1.0")
    HttpResponse.json(HttpStatus.OK, JsonHelper.stringify(JsonValue.JsonObject(obj)))
}

func handleListUsers(req: HttpRequest): HttpResponse {
    let user1 = jsonObject()
    user1["id"] = JsonValue.JsonNumber(1.0)
    user1["name"] = JsonValue.JsonString("Alice")
    let user2 = jsonObject()
    user2["id"] = JsonValue.JsonNumber(2.0)
    user2["name"] = JsonValue.JsonString("Bob")
    let obj = jsonObject()
    let usersList = ArrayList<JsonValue>()
    usersList.add(JsonValue.JsonObject(user1))
    usersList.add(JsonValue.JsonObject(user2))
    obj["users"] = JsonValue.JsonArray(usersList)
    obj["total"] = JsonValue.JsonNumber(2.0)
    HttpResponse.json(HttpStatus.OK, JsonHelper.stringify(JsonValue.JsonObject(obj)))
}

func handleGetUser(req: HttpRequest): HttpResponse {
    let obj = jsonObject()
    obj["id"] = JsonValue.JsonNumber(1.0)
    obj["name"] = JsonValue.JsonString("Alice")
    obj["email"] = JsonValue.JsonString("alice@example.com")
    HttpResponse.json(HttpStatus.OK, JsonHelper.stringify(JsonValue.JsonObject(obj)))
}

func handleCreateUser(req: HttpRequest): HttpResponse {
    let body = req.bodyAsString()
    let parsed = JsonHelper.parseOrNull(body)
    let obj = jsonObject()
    obj["id"] = JsonValue.JsonNumber(3.0)
    obj["created"] = JsonValue.JsonBool(true)
    match (parsed) {
        case Some(v) => obj["body"] = v
        case None => obj["body"] = JsonValue.JsonString(body)
    }
    HttpResponse.json(HttpStatus.CREATED, JsonHelper.stringify(JsonValue.JsonObject(obj)))
}

func handleLogin(req: HttpRequest): HttpResponse {
    let form = parseFormBody(req)
    let u = match (form.get("username")) { case Some(x) => x case None => "?" }
    let obj = jsonObject()
    obj["token"] = JsonValue.JsonString("jwt-${u}")
    obj["role"] = JsonValue.JsonString("user")
    HttpResponse.json(HttpStatus.OK, JsonHelper.stringify(JsonValue.JsonObject(obj)))
}

func handleUpload(req: HttpRequest): HttpResponse {
    let fields = parseMultipartBody(req)
    let obj = jsonObject()
    match (fields.get("file")) {
        case Some(f) =>
            let fileObj = jsonObject()
            fileObj["name"] = JsonValue.JsonString(f.fileName)
            fileObj["size"] = JsonValue.JsonNumber(Float64(f.data.size))
            obj["file"] = JsonValue.JsonObject(fileObj)
        case None => obj["file"] = JsonValue.JsonNull
    }
    obj["uploaded"] = JsonValue.JsonBool(true)
    HttpResponse.json(HttpStatus.OK, JsonHelper.stringify(JsonValue.JsonObject(obj)))
}

func handleUpdateUser(req: HttpRequest): HttpResponse {
    let obj = jsonObject()
    obj["updated"] = JsonValue.JsonBool(true)
    obj["id"] = JsonValue.JsonNumber(1.0)
    let body = req.bodyAsString()
    let parsed = JsonHelper.parseOrNull(body)
    match (parsed) {
        case Some(v) => obj["body"] = v
        case None => obj["body"] = JsonValue.JsonString(body)
    }
    HttpResponse.json(HttpStatus.OK, JsonHelper.stringify(JsonValue.JsonObject(obj)))
}

func handlePatchUser(req: HttpRequest): HttpResponse {
    let obj = jsonObject()
    obj["patched"] = JsonValue.JsonBool(true)
    obj["id"] = JsonValue.JsonNumber(1.0)
    let body = req.bodyAsString()
    let parsed = JsonHelper.parseOrNull(body)
    match (parsed) {
        case Some(v) => obj["body"] = v
        case None => obj["body"] = JsonValue.JsonString(body)
    }
    HttpResponse.json(HttpStatus.OK, JsonHelper.stringify(JsonValue.JsonObject(obj)))
}

func handleDeleteUser(req: HttpRequest): HttpResponse {
    let obj = jsonObject()
    obj["deleted"] = JsonValue.JsonBool(true)
    obj["id"] = JsonValue.JsonNumber(42.0)
    HttpResponse.json(HttpStatus.OK, JsonHelper.stringify(JsonValue.JsonObject(obj)))
}

func handleEcho(req: HttpRequest): HttpResponse {
    let obj = jsonObject()
    obj["method"] = JsonValue.JsonString(req.method.toString())
    obj["url"] = JsonValue.JsonString(req.url)
    obj["body"] = JsonValue.JsonString(req.bodyAsString())
    HttpResponse.json(HttpStatus.OK, JsonHelper.stringify(JsonValue.JsonObject(obj)))
}

main(): Int64 {
    let router = Router()
        .get("/", handleRoot).get("/users", handleListUsers).get("/users/:id", handleGetUser)
        .post("/users", handleCreateUser).post("/login", handleLogin).post("/upload", handleUpload).post("/echo", handleEcho)
        .put("/users/:id", handleUpdateUser).patch("/users/:id", handlePatchUser).delete("/users/:id", handleDeleteUser)

    println("═══════════════════════════════════════════")
    println("  http_lib HTTP Server 示例")
    println("  监听 http://127.0.0.1:8080")
    println("═══════════════════════════════════════════")
    println("  GET    /, /users, /users/:id")
    println("  POST   /users(JSON), /login(Form), /upload(Multipart), /echo")
    println("  PUT    /users/:id")
    println("  PATCH  /users/:id")
    println("  DELETE /users/:id")
    println("")

    let server = HttpServer(handler: router.handler())
    try { server.listenAndServe("127.0.0.1", 8080) }
    catch (e: Exception) { println("错误: ${e.message}") }
    0
}
