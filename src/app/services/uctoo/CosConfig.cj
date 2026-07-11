package magic.app.services.uctoo

// ========== 自定义引入区域 ==========
import cos.{CosClient, CosClientConfig}
import cos.model.{PutObjectRequest, PutObjectResult}
import magic.config.{Config as AppConfig}

// ========== 自动生成代码区域 ==========

/**
 * CosConfig - 腾讯云 COS 配置类
 *
 * 读取环境变量中的 COS 配置
 */
public class CosConfig {
    private static var client: ?CosClient = None<CosClient>

    public static func getSecretId(): String {
        AppConfig.env["QCLOUD_COS_SECRET_ID"].getOrDefault({ => "" })
    }

    public static func getSecretKey(): String {
        AppConfig.env["QCLOUD_COS_SECRET_KEY"].getOrDefault({ => "" })
    }

    public static func getRegion(): String {
        AppConfig.env["QCLOUD_COS_REGION"].getOrDefault({ => "ap-guangzhou" })
    }

    public static func getBucket(): String {
        AppConfig.env["QCLOUD_COS_BUCKET"].getOrDefault({ => "" })
    }

    public static func getProtocol(): String {
        AppConfig.env["QCLOUD_COS_PROTOCOL"].getOrDefault({ => "https" })
    }

    public static func getCdnBaseUrl(): String {
        AppConfig.env["QCLOUD_COS_CDN_BASE_URL"].getOrDefault({ => "" })
    }

    public static func getDefaultScene(): String {
        AppConfig.env["QCLOUD_COS_DEFAULT_SCENE"].getOrDefault({ => "default" })
    }

    /**
     * 获取或创建 COS 客户端单例
     */
    public static func getClient(): CosClient {
        if (client.isNone()) {
            let config = CosClientConfig(
                getSecretId(),
                getSecretKey(),
                getRegion(),
                bucket: Some(getBucket()),
                protocol: getProtocol(),
                timeout: 60
            )
            client = Some(CosClient(config))
        }
        return client.getOrThrow()
    }

    /**
     * 关闭 COS 客户端
     */
    public static func closeClient(): Unit {
        if (let Some(c) <- client) {
            c.close()
            client = None<CosClient>
        }
    }
}
