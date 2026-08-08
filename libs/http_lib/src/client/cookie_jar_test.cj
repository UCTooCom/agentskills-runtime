package http_lib.client

import http_lib.core.{assertTrue, assertFalse}
import http_lib.core.{HttpHeaders, HttpStatus}
import http_lib.message.{HttpRequest, HttpResponse}

@Test
public class CookieJarUnitTest {
    @TestCase public func test01_Init(): Unit { let j=HttpClientCookieJar(); assertTrue(j.getCookieHeader("h","/",false)=="") }

    @TestCase public func test02_ExtractCookies(): Unit { let j=HttpClientCookieJar(); let h=HttpHeaders(); h.add("Set-Cookie","k=v; Path=/"); j.extractCookies("h","/",false,HttpResponse(status:HttpStatus.OK,headers:h)); assertTrue(j.getCookieHeader("h","/",false).contains("k=v")) }

    @TestCase public func test03_ApplyCookies(): Unit { let j=HttpClientCookieJar(); let h=HttpHeaders(); h.add("Set-Cookie","x=1; Path=/"); j.extractCookies("h","/",false,HttpResponse(status:HttpStatus.OK,headers:h)); let r=HttpRequest(); j.applyCookies("h","/",false,r); match(r.headers.get("cookie")){case Some(v)=>assertTrue(v.contains("x=1"));case None=>assertTrue(false)} }

    @TestCase public func test04_Clear(): Unit { let j=HttpClientCookieJar(); let h=HttpHeaders(); h.add("Set-Cookie","z=2; Path=/"); j.extractCookies("h","/",false,HttpResponse(status:HttpStatus.OK,headers:h)); j.clear(); assertTrue(j.getCookieHeader("h","/",false)=="") }

    @TestCase public func test05_GetCookieHeaderEmpty(): Unit { let j=HttpClientCookieJar(); assertTrue(j.getCookieHeader("ex.com","/",false)=="") }

    @TestCase public func test06_ExtractMultipleCookies(): Unit { let j=HttpClientCookieJar(); let h=HttpHeaders(); h.add("Set-Cookie","a=1; Path=/"); h.add("Set-Cookie","b=2; Path=/"); let resp=HttpResponse(status:HttpStatus.OK,headers:h); j.extractCookies("ex.com","/",false,resp); let ch=j.getCookieHeader("ex.com","/",false); assertTrue(ch.contains("a=1") && ch.contains("b=2")) }

    @TestCase public func test07_NoSetCookieHeaders(): Unit { let j=HttpClientCookieJar(); j.extractCookies("ex.com","/",false,HttpResponse(status:HttpStatus.OK)); assertTrue(j.getCookieHeader("ex.com","/",false)=="") }

    @TestCase public func test08_EmptyResponseHeaders(): Unit { let j=HttpClientCookieJar(); j.extractCookies("ex.com","/",false,HttpResponse(status:HttpStatus.OK,headers:HttpHeaders())); assertTrue(j.getCookieHeader("ex.com","/",false)=="") }

    @TestCase public func test09_SecureCookieOverHttp(): Unit { let j=HttpClientCookieJar(); let h=HttpHeaders(); h.add("Set-Cookie","secret=top; Path=/; Secure"); j.extractCookies("ex.com","/",false,HttpResponse(status:HttpStatus.OK,headers:h)); let ch=j.getCookieHeader("ex.com","/",false); assertTrue(!ch.contains("secret")) }

    @TestCase public func test10_SecureCookieOverHttps(): Unit { let j=HttpClientCookieJar(); let h=HttpHeaders(); h.add("Set-Cookie","secret=top; Path=/; Secure"); j.extractCookies("ex.com","/",true,HttpResponse(status:HttpStatus.OK,headers:h)); let ch=j.getCookieHeader("ex.com","/",true); assertTrue(ch.contains("secret")) }

    @TestCase public func test11_CookiePathFiltering(): Unit { let j=HttpClientCookieJar(); let h=HttpHeaders(); h.add("Set-Cookie","token=xyz; Path=/api"); j.extractCookies("ex.com","/",false,HttpResponse(status:HttpStatus.OK,headers:h)); let chMatch=j.getCookieHeader("ex.com","/api",false); assertTrue(chMatch.contains("token")); let chNoMatch=j.getCookieHeader("ex.com","/other",false); assertTrue(!chNoMatch.contains("token")) }

    @TestCase public func test12_DomainFiltering(): Unit { let j=HttpClientCookieJar(); let h=HttpHeaders(); h.add("Set-Cookie","user=john; Path=/; Domain=example.com"); j.extractCookies("example.com","/",false,HttpResponse(status:HttpStatus.OK,headers:h)); assertTrue(j.getCookieHeader("example.com","/",false).contains("user")); assertTrue(!j.getCookieHeader("other.com","/",false).contains("user")) }

    @TestCase public func test13_ApplyCookiesSetsHeader(): Unit { let j=HttpClientCookieJar(); let h=HttpHeaders(); h.add("Set-Cookie","applied=yes; Path=/"); j.extractCookies("ex.com","/",false,HttpResponse(status:HttpStatus.OK,headers:h)); let r=HttpRequest(); j.applyCookies("ex.com","/",false,r); match(r.headers.get("cookie")){case Some(v)=>assertTrue(v.contains("applied=yes"));case None=>assertTrue(false)} }

    @TestCase public func test14_ApplyCookiesNoMatch(): Unit { let j=HttpClientCookieJar(); let h=HttpHeaders(); h.add("Set-Cookie","x=1; Path=/a"); j.extractCookies("ex.com","/a",false,HttpResponse(status:HttpStatus.OK,headers:h)); let r=HttpRequest(); j.applyCookies("ex.com","/b",false,r); match(r.headers.get("cookie")){case Some(v)=>assertTrue(v=="");case None=>assertTrue(true)} }

    @TestCase public func test15_ClearAfterExtract(): Unit { let j=HttpClientCookieJar(); let h=HttpHeaders(); h.add("Set-Cookie","x=1; Path=/"); j.extractCookies("ex.com","/",false,HttpResponse(status:HttpStatus.OK,headers:h)); j.clear(); assertTrue(j.getCookieHeader("ex.com","/",false)=="") }

    @TestCase public func test16_GetCookieHeaderSameSite(): Unit { let j=HttpClientCookieJar(); let h=HttpHeaders(); h.add("Set-Cookie","ss=1; Path=/; SameSite=Lax"); j.extractCookies("ex.com","/",false,HttpResponse(status:HttpStatus.OK,headers:h)); let ch=j.getCookieHeader("ex.com","/",false,isSameSite:true); assertTrue(ch.contains("ss=1")) }

    @TestCase public func test17_MultipleExtractCalls(): Unit { let j=HttpClientCookieJar(); let h1=HttpHeaders(); h1.add("Set-Cookie","a=1; Path=/"); j.extractCookies("ex.com","/",false,HttpResponse(status:HttpStatus.OK,headers:h1)); let h2=HttpHeaders(); h2.add("Set-Cookie","b=2; Path=/"); j.extractCookies("ex.com","/",false,HttpResponse(status:HttpStatus.OK,headers:h2)); let ch=j.getCookieHeader("ex.com","/",false); assertTrue(ch.contains("a=1") && ch.contains("b=2")) }

    @TestCase public func test18_ClearIdempotent(): Unit { let j=HttpClientCookieJar(); j.clear(); j.clear(); assertTrue(true) }

    @TestCase public func test19_SameCookieOverwrite(): Unit { let j=HttpClientCookieJar(); let h=HttpHeaders(); h.add("Set-Cookie","x=old; Path=/"); j.extractCookies("ex.com","/",false,HttpResponse(status:HttpStatus.OK,headers:h)); h.add("Set-Cookie","x=new; Path=/"); j.extractCookies("ex.com","/",false,HttpResponse(status:HttpStatus.OK,headers:h)); assertTrue(j.getCookieHeader("ex.com","/",false).contains("x=new")) }
}
