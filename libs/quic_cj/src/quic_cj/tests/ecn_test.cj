 package quic_cj.tests
 
 import quic_cj.protocol.{ECN}
 
 @Test
 public class EcnTestSuite {
     @TestCase
     public func testAllEcnVariants(): Unit {
         let ecns: Array<ECN> = [ECN.Unsupported, ECN.Non, ECN.ECT1, ECN.ECT0, ECN.CE]
         @Assert(ecns.size, 5)
     }
 
     @TestCase
     public func testEcnUnsupported(): Unit {
         let e = ECN.Unsupported
         let isUnsupported = match (e) { case ECN.Unsupported => true; case _ => false }
         @Assert(isUnsupported, true)
     }
 
     @TestCase
     public func testEcnNon(): Unit {
         let e = ECN.Non
         let isNon = match (e) { case ECN.Non => true; case _ => false }
         @Assert(isNon, true)
     }
 
     @TestCase
     public func testEcnEct1(): Unit {
         let e = ECN.ECT1
         let isEct1 = match (e) { case ECN.ECT1 => true; case _ => false }
         @Assert(isEct1, true)
     }
 
     @TestCase
     public func testEcnEct0(): Unit {
         let e = ECN.ECT0
         let isEct0 = match (e) { case ECN.ECT0 => true; case _ => false }
         @Assert(isEct0, true)
     }
 
     @TestCase
     public func testEcnCe(): Unit {
         let e = ECN.CE
         let isCe = match (e) { case ECN.CE => true; case _ => false }
         @Assert(isCe, true)
     }
 
     @TestCase
     public func testEcnMatchExclusive(): Unit {
         let ecns: Array<ECN> = [ECN.Unsupported, ECN.Non, ECN.ECT1, ECN.ECT0, ECN.CE]
         var i: Int64 = 0
         while (i < ecns.size) {
             var j: Int64 = 0
             while (j < ecns.size) {
                 if (i != j) {
                     let isSame = match (ecns[i]) {
                         case ECN.Unsupported => match (ecns[j]) { case ECN.Unsupported => true; case _ => false }
                         case ECN.Non => match (ecns[j]) { case ECN.Non => true; case _ => false }
                         case ECN.ECT1 => match (ecns[j]) { case ECN.ECT1 => true; case _ => false }
                         case ECN.ECT0 => match (ecns[j]) { case ECN.ECT0 => true; case _ => false }
                         case ECN.CE => match (ecns[j]) { case ECN.CE => true; case _ => false }
                     }
                     @Assert(isSame, false)
                 }
                 j += 1
             }
             i += 1
         }
     }
 }
