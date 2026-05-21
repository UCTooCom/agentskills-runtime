package magic.app.services.crontab.misfire

public enum MisfirePolicy {
    | FireNow
    | FireOnce
    | Ignore
}

public func misfirePolicyFromTactics(tactics: String): MisfirePolicy {
    match (tactics) {
        case "1" => FireNow
        case "2" => FireOnce
        case "3" => Ignore
        case _ => Ignore
    }
}

public func misfirePolicyToString(p: MisfirePolicy): String {
    match (p) {
        case FireNow => "1"
        case FireOnce => "2"
        case Ignore => "3"
    }
}
