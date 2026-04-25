macro package json4cj.jsonmacro

class AdapterMissingException <: Exception {
    public init(message: String) {
        super(message)
    }
}

class TypeInferenceException <: Exception {
    public init(message: String) {
        super(message)
    }
}

class TokenVerificationException <: Exception {
    public init(message: String) {
        super(message)
    }
}

class MacroExpansionException <: Exception {
    public init(message: String) {
        super(message)
    }
}

class MacroParameterException <: Exception {
    public init(message: String) {
        super(message)
    }
}
