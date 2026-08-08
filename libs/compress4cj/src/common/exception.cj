package compress4cj.common

public class Zlib4cjException <: Exception {
    public init(message: String) {
        super(message)
    }

    public override func toString(): String {
        if (message == "") {
            return "Zlib4cjException"
        } else {
            return "Zlib4cjException: ${message}"
        }
    }
}
