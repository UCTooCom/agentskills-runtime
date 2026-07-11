package magic.app.services.uctoo

// ========== 自定义引入区域 ==========

// ========== 自动生成代码区域 ==========

/**
 * UploadRequest - 文件上传请求
 */
public class UploadRequest {
    public let filename: String
    public let content: String
    public let mimeType: String
    public let scene: String
    public let `type`: String

    public init(
        filename: String,
        content: String,
        mimeType!: String = "application/octet-stream",
        scene!: String = "default",
        `type`!: String = ""
    ) {
        this.filename = filename
        this.content = content
        this.mimeType = mimeType
        this.scene = scene
        this.`type` = `type`
    }
}

/**
 * UploadResponse - 文件上传响应
 */
public class UploadResponse {
    /// 附件ID
    public let id: String
    /// 文件路径
    public let path: String
    /// 文件URL
    public let url: String
    /// 文件大小
    public let filesize: Int32
    /// 文件名
    public let filename: String
    /// MIME类型
    public let mimeType: String
    /// 文件扩展名
    public let fileExt: String
    /// 存储驱动
    public let driver: String

    public init(
        id: String,
        path: String,
        url: String,
        filesize: Int32,
        filename: String,
        mimeType: String,
        fileExt: String,
        driver!: String = "qcloud"
    ) {
        this.id = id
        this.path = path
        this.url = url
        this.filesize = filesize
        this.filename = filename
        this.mimeType = mimeType
        this.fileExt = fileExt
        this.driver = driver
    }
}
