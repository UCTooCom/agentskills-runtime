package uc_installer.services

import blowfish.Bcrypt

/// 哈希管理员口令：写库前把前缀从 $2b$10$ 归一为 $2a$10$（哈希体不变，
/// 满足 AC-112 字面要求并与 nestJs 产物前缀一致；bcrypt.cj:247 的 genSalt 生成 $2b$）。
public func hashPassword(plain: String): String {
    let h = Bcrypt.hash(plain, cost: 10)
    return h.replace("$2b$10$", "$2a$10$")
}

/// 校验口令：verify 侧取前 29 字符作 salt 且不校验版本前缀（bcrypt.cj:229），
/// 故对 $2a$/$2b$/$2y$ 三种前缀均接受，双向互认成立。
public func verifyPassword(plain: String, hash: String): Bool {
    return Bcrypt.verify(plain, hash)
}
