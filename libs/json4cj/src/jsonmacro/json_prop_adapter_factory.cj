macro package json4cj.jsonmacro

import std.collection.HashMap

/*
* The factory for json adapters
*/
class JsonPropAdapterFactory {
    private let map: HashMap<String, String> = HashMap()
    private static const separator = ":"

    /*
    * Registers the adapter by property name
    * @param propName the property name
    * @param serializer the serializer to register
    */
    public func register(propName: String, serializer: String): Unit {
        map.add(propName, serializer)
    }

    public func hasAdapter(propName: String): Bool {
        return map.contains(propName)
    }

    /*
    * Gets the json adapter by property name
    * @param propName the property name
    * @return String the adapter for given property name
    */
    public func getAdapter(propName: String): String {
        return map.get(propName)
        .getOrThrow({ => AdapterMissingException("No adapter registered for ${propName}") })
    }
}