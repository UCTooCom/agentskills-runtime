package magic.app.services.uctoo

// ========== 自定义引入区域 ==========
import cj_mail.*
import cj_mail.smtp.*
import std.collection.*
import std.convert.*
import std.time.*
import magic.config.{Config as AppConfig}
import magic.log.LogUtils

// ========== 自动生成代码区域 ==========

/**
 * MailConfig - 邮件发送配置类
 *
 * 读取环境变量中的邮件配置
 */
public class MailConfig {
    private static var smtpConnection: ?Smtp = None<Smtp>

    public static func getSmtpHost(): String {
        AppConfig.env["MAIL_SMTP_HOST"].getOrDefault({ => "smtp.mail.com" })
    }

    public static func getSmtpPort(): UInt16 {
        let portStr = AppConfig.env["MAIL_SMTP_PORT"].getOrDefault({ => "465" })
        let port = Int64.parse(portStr)
        match (port as UInt16) {
            case Some(p) => p
            case None => 465u16
        }
    }

    public static func getUsername(): String {
        AppConfig.env["MAIL_USERNAME"].getOrDefault({ => "" })
    }

    public static func getPassword(): String {
        AppConfig.env["MAIL_PASSWORD"].getOrDefault({ => "" })
    }

    public static func getFromAddress(): String {
        AppConfig.env["MAIL_FROM_ADDRESS"].getOrDefault({ => "" })
    }

    public static func getFromName(): String {
        AppConfig.env["MAIL_FROM_NAME"].getOrDefault({ => "AgentSkills" })
    }

    /**
     * 获取或创建 SMTP 连接单例
     * QQ邮箱使用SSL 465端口
     */
    public static func getSmtpConnection(): Smtp {
        if (smtpConnection.isNone()) {
            try {
                let smtp = Smtp(getSmtpHost(), getSmtpPort())
                smtp.plain(getUsername(), getPassword())
                smtpConnection = Some(smtp)
                LogUtils.info("MailConfig", "=== SMTP connection initialized successfully ===")
            } catch (e: Exception) {
                LogUtils.error("MailConfig", "=== Failed to initialize SMTP connection: ${e.message} ===")
                throw e
            }
        }
        return smtpConnection.getOrThrow()
    }

    /**
     * 发送邮件
     */
    public static func sendEmail(toAddress: String, subject: String, content: String): Bool {
        try {
            LogUtils.info("MailConfig", "=== sendEmail start: to=${toAddress}, subject=${subject} ===")
            LogUtils.info("MailConfig", "=== SMTP config: host=${getSmtpHost()}, port=${getSmtpPort()}, username=${getUsername()}, from=${getFromAddress()} ===")
            
            let smtp = getSmtpConnection()
            LogUtils.info("MailConfig", "=== SMTP connection created successfully ===")
            
            let mail = SendMail()
            mail.from.name = getFromName()
            mail.from.address = getFromAddress()
            let toList = ArrayList<MailAddress>()
            toList.add(MailAddress("", toAddress))
            mail.to = toList
            mail.subject = subject
            mail.data = content
            LogUtils.info("MailConfig", "=== Mail object created: from=${mail.from.address}, to=${toAddress}, subject=${subject} ===")
            
            smtp.send(mail)
            LogUtils.info("MailConfig", "=== Email sent successfully ===")
            return true
        } catch (e: Exception) {
            LogUtils.error("MailConfig", "=== Send email failed: ${e.message} ===")
            closeConnection()
            return false
        }
    }

    /**
     * 关闭 SMTP 连接
     */
    public static func closeConnection(): Unit {
        if (let Some(smtp) <- smtpConnection) {
            smtp.close()
            smtpConnection = None<Smtp>
        }
    }
}
