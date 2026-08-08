/**
 * http_lib — 仓颉 HTTP 协议封装库。
 *
 * 导入所有子模块以触发编译。
 * 注意：http_lib.server 不可直接 import，否则会因双向依赖导致循环依赖。
 * 使用 server 功能时请单独 import http_lib.server.*。
 * 支持 HTTP/1.x、HTTP/2 和 HTTP/3 协议层。
 */
package http_lib

import http_lib.core.*
import http_lib.buffer.ByteBuffer
import http_lib.message.*
import http_lib.router.*
import http_lib.client.*
import http_lib.http2.*
import http_lib.http3.*
import http_lib.connection.*
import http_lib.utils.*
