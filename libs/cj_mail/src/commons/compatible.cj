package cj_mail.commons

import std.regex.*
import std.collection.*

func add<T> ( list: List<T>, item: T) {
    list.add(item)
}

@When[cjc_version >= "0.59.6"]
public func regexGroups(regex: Regex, line: String): Option<ArrayList<String>> {
    let matchs = regex.find(line, group: true);
    match(matchs) {
        case Some(r) => 
            let groups = ArrayList<String>()
            let count = r.groupCount()
            for (i in 0..count + 1) {
                add(groups, r.matchString(i))
            }
            return Some(groups)
        case None => 
            return None
    }
}

@When[cjc_version < "0.59.6"]
public func regexGroups(regex: Regex, line: String): Option<ArrayList<String>> {
    let matchs = regex.matches(line);
    match(matchs) {
        case Some(r) => 
            let groups = ArrayList<String>()
            for (i in 0..r.groupNumber()) {
                add(groups, r.matchStr(i))
            }
            return Some(groups)
        case None => 
            return None
        
    }
}

