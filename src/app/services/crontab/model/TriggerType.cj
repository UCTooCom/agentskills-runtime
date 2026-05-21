package magic.app.services.crontab.model

public enum TriggerType {
    | Cron
    | Manual
    | Misfire
    | Retry
    | SkippedConcurrent
}

public func triggerTypeToString(t: TriggerType): String {
    match (t) {
        case Cron => "cron"
        case Manual => "manual"
        case Misfire => "misfire"
        case Retry => "retry"
        case SkippedConcurrent => "skipped_concurrent"
    }
}

public func triggerTypeFromString(s: String): TriggerType {
    match (s) {
        case "manual" => Manual
        case "misfire" => Misfire
        case "retry" => Retry
        case "skipped_concurrent" => SkippedConcurrent
        case _ => Cron
    }
}
