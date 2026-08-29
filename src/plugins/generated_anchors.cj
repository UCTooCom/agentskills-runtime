// 本文件由 build-sync 自动生成（勿手改、不入库，见 build.cj 锚点说明）
// L1 反射锚点：确保静态链接保留插件类，运行时 ClassTypeInfo.get 可发现
package magic.plugins

import magic.plugins.entity.EntityPlugin
import magic.plugins.entity.EntityRoute
import magic.plugins.feedback.FeedbackPlugin
import magic.plugins.feedback.FeedbackRoute

public class GeneratedPluginAnchors {
    public static func touch(): Unit {
        let _anchor_0 = EntityPlugin()
        let _anchor_1 = EntityRoute()
        let _anchor_2 = FeedbackPlugin()
        let _anchor_3 = FeedbackRoute()
    }
}
