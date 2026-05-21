package magic.app.services.crontab.retry

import std.math.pow

public enum RetryStrategy {
    | FixedDelay(Int64)
    | ExponentialBackoff(Int64, Float64)
}

extend RetryStrategy {
    public func calculateDelay(attempt: Int32): Int64 {
        match (this) {
            case FixedDelay(base) =>
                base
            case ExponentialBackoff(base, multiplier) =>
                let exp = pow(multiplier, Float64(attempt))
                let delay = Int64(Float64(base) * exp)
                if (delay > 300000) { 300000 } else { delay }
        }
    }
}
