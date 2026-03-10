/**
 * @file
 * This file is about yaml null style.
 */

package yaml4cj.yaml

/**
 * The interface is StyleT inherited from ToString
 * @author changeden
 * @since 0.30.4
 */
interface StyleT {
    static func getValues(): Array<StyleT>
    func getCode(): Int64
}

enum NullStyleT <: StyleT {
    NullStyleT_NULL_STYLE

    /**
     * The Function is getValues
     *
     * @return Type of Array<StyleT>
     * @since 0.30.4
     */
    public static func getValues(): Array<StyleT> {
        [NullStyleT_NULL_STYLE]
    }

    /**
     * The Function is getCode
     *
     * @return Type of Int64
     * @since 0.30.4
     */
    public func getCode(): Int64 {
        0
    }

    /**
     * The Function is hashCode
     *
     * @return Type of Int64
     * @since 0.30.4
     */
    /*public func hashCode(): Int64 {
        genHashCode([getCode()], name: "NullStyleT")
}

    /**
     * The Function is ==
     *
     * @param b of StyleT
     *
     * @return Type of Bool
     * @since 0.30.4
     */
    public operator func ==(b: StyleT): Bool {
        eq(getCode(), b.getCode())
    }

    /**
     * The Function is !=
     *
     * @param b of StyleT
     *
     * @return Type of Bool
     * @since 0.30.4
     */
    public operator func !=(b: StyleT): Bool {
        ne(getCode(), b.getCode())
    }

    /**
     * The Function is toString
     *
     * @return Type of String
     * @since 0.30.4
     */
    public func toString(): String {
        "NullStyleT_NULL_STYLE"
    }*/
}

enum ScalarStyleT <: StyleT {
    | ScalarStyleT_ANY_SCALAR_STYLE
    | ScalarStyleT_PLAIN_SCALAR_STYLE
    | ScalarStyleT_SINGLE_QUOTED_SCALAR_STYLE
    | ScalarStyleT_DOUBLE_QUOTED_SCALAR_STYLE
    | ScalarStyleT_LITERAL_SCALAR_STYLE
    | ScalarStyleT_FOLDED_SCALAR_STYLE

    /**
     * The Function is get
     *
     * @param i of StyleT
     *
     * @return Type of ScalarStyleT
     * @since 0.30.4
     */
    public static func get(i: StyleT): ScalarStyleT {
        for (v in getValues()) {
            if (v.getCode() == i.getCode()) {
                return (v as ScalarStyleT).getOrThrow()
            }
        }
        ScalarStyleT_ANY_SCALAR_STYLE
    }

    /**
     * The Function is getValues
     *
     * @return Type of Array<StyleT>
     * @since 0.30.4
     */
    public static func getValues(): Array<StyleT> {
        [
            ScalarStyleT_ANY_SCALAR_STYLE,
            ScalarStyleT_PLAIN_SCALAR_STYLE,
            ScalarStyleT_SINGLE_QUOTED_SCALAR_STYLE,
            ScalarStyleT_DOUBLE_QUOTED_SCALAR_STYLE,
            ScalarStyleT_LITERAL_SCALAR_STYLE,
            ScalarStyleT_FOLDED_SCALAR_STYLE
        ]
    }

    /**
     * The Function is getCode
     *
     * @return Type of Int64
     * @since 0.30.4
     */
    public func getCode(): Int64 {
        match (this) {
            case ScalarStyleT_ANY_SCALAR_STYLE => 0
            case ScalarStyleT_PLAIN_SCALAR_STYLE => 1
            case ScalarStyleT_SINGLE_QUOTED_SCALAR_STYLE => 2
            case ScalarStyleT_DOUBLE_QUOTED_SCALAR_STYLE => 3
            case ScalarStyleT_LITERAL_SCALAR_STYLE => 4
            case ScalarStyleT_FOLDED_SCALAR_STYLE => 5
        }
    }

    /**
     * The Function is hashCode
     *
     * @return Type of Int64
     * @since 0.30.4
     */
    /*public func hashCode(): Int64 {
        genHashCode([getCode()], name: "ScalarStyleT")
    }*/

    /**
     * The Function is ==
     *
     * @param b of StyleT
     *
     * @return Type of Bool
     * @since 0.30.4
     */
    public operator func ==(b: StyleT): Bool {
        eq(getCode(), b.getCode())
    }

    /**
     * The Function is !=
     *
     * @param b of StyleT
     *
     * @return Type of Bool
     * @since 0.30.4
     */
    public operator func !=(b: StyleT): Bool {
        ne(getCode(), b.getCode())
    }

    /**
     * The Function is toString
     *
     * @return Type of String
     * @since 0.30.4
     */
    /*public func toString(): String {
        match (this) {
            case ScalarStyleT_ANY_SCALAR_STYLE => "ScalarStyleT_ANY_SCALAR_STYLE"
            case ScalarStyleT_PLAIN_SCALAR_STYLE => "ScalarStyleT_PLAIN_SCALAR_STYLE"
            case ScalarStyleT_SINGLE_QUOTED_SCALAR_STYLE => "ScalarStyleT_SINGLE_QUOTED_SCALAR_STYLE"
            case ScalarStyleT_DOUBLE_QUOTED_SCALAR_STYLE => "ScalarStyleT_DOUBLE_QUOTED_SCALAR_STYLE"
            case ScalarStyleT_LITERAL_SCALAR_STYLE => "ScalarStyleT_LITERAL_SCALAR_STYLE"
            case ScalarStyleT_FOLDED_SCALAR_STYLE => "ScalarStyleT_FOLDED_SCALAR_STYLE"
        }
    }*/
}

enum SequenceStyleT <: StyleT {
    | SequenceStyleT_ANY_SEQUENCE_STYLE
    | SequenceStyleT_BLOCK_SEQUENCE_STYLE
    | SequenceStyleT_FLOW_SEQUENCE_STYLE

    /**
     * The Function is get
     *
     * @param i of StyleT
     *
     * @return Type of SequenceStyleT
     * @since 0.30.4
     */
    public static func get(i: StyleT): SequenceStyleT {
        for (v in getValues()) {
            if (v.getCode() == i.getCode()) {
                return (v as SequenceStyleT).getOrThrow()
            }
        }
        SequenceStyleT_ANY_SEQUENCE_STYLE
    }

    /**
     * The Function is getValues
     *
     * @return Type of Array<StyleT>
     * @since 0.30.4
     */
    public static func getValues(): Array<StyleT> {
        [
            SequenceStyleT_ANY_SEQUENCE_STYLE,
            SequenceStyleT_BLOCK_SEQUENCE_STYLE,
            SequenceStyleT_FLOW_SEQUENCE_STYLE
        ]
    }

    /**
     * The Function is getCode
     *
     * @return Type of Int64
     * @since 0.30.4
     */
    public func getCode(): Int64 {
        match (this) {
            case SequenceStyleT_ANY_SEQUENCE_STYLE => 0
            case SequenceStyleT_BLOCK_SEQUENCE_STYLE => 1
            case SequenceStyleT_FLOW_SEQUENCE_STYLE => 2
        }
    }

    /**
     * The Function is hashCode
     *
     * @return Type of Int64
     * @since 0.30.4
     */
    /*public func hashCode(): Int64 {
        genHashCode([getCode()], name: "SequenceStyleT")
    }*/

    /**
     * The Function is ==
     *
     * @param b of StyleT
     *
     * @return Type of Bool
     * @since 0.30.4
     */
    public operator func ==(b: StyleT): Bool {
        eq(getCode(), b.getCode())
    }

    /**
     * The Function is !=
     *
     * @param b of StyleT
     *
     * @return Type of Bool
     * @since 0.30.4
     */
    /*public operator func !=(b: StyleT): Bool {
        ne(getCode(), b.getCode())
}

    /**
     * The Function is toString
     *
     * @return Type of String
     * @since 0.30.4
     */
    public func toString(): String {
        match (this) {
            case SequenceStyleT_ANY_SEQUENCE_STYLE => "SequenceStyleT_ANY_SEQUENCE_STYLE"
            case SequenceStyleT_BLOCK_SEQUENCE_STYLE => "SequenceStyleT_BLOCK_SEQUENCE_STYLE"
            case SequenceStyleT_FLOW_SEQUENCE_STYLE => "SequenceStyleT_FLOW_SEQUENCE_STYLE"
        }
    }*/
}

enum MappingStyleT <: StyleT {
    | MappingStyleT_ANY_MAPPING_STYLE
    | MappingStyleT_BLOCK_MAPPING_STYLE
    | MappingStyleT_FLOW_MAPPING_STYLE

    /**
     * The Function is get
     *
     * @param i of StyleT
     *
     * @return Type of MappingStyleT
     * @since 0.30.4
     */
    public static func get(i: StyleT): MappingStyleT {
        for (v in getValues()) {
            if (v.getCode() == i.getCode()) {
                return (v as MappingStyleT).getOrThrow()
            }
        }
        MappingStyleT_ANY_MAPPING_STYLE
    }

    /**
     * The Function is getValues
     *
     * @return Type of Array<StyleT>
     * @since 0.30.4
     */
    public static func getValues(): Array<StyleT> {
        [
            MappingStyleT_ANY_MAPPING_STYLE,
            MappingStyleT_BLOCK_MAPPING_STYLE,
            MappingStyleT_FLOW_MAPPING_STYLE
        ]
    }

    /**
     * The Function is getCode
     *
     * @return Type of Int64
     * @since 0.30.4
     */
    public func getCode(): Int64 {
        match (this) {
            case MappingStyleT_ANY_MAPPING_STYLE => 0
            case MappingStyleT_BLOCK_MAPPING_STYLE => 1
            case MappingStyleT_FLOW_MAPPING_STYLE => 2
        }
    }

    /**
     * The Function is hashCode
     *
     * @return Type of Int64
     * @since 0.30.4
     */
    /*public func hashCode(): Int64 {
        genHashCode([getCode()], name: "MappingStyleT")
    }*/

    /**
     * The Function is ==
     *
     * @param b of StyleT
     *
     * @return Type of Bool
     * @since 0.30.4
     */
    public operator func ==(b: StyleT): Bool {
        eq(getCode(), b.getCode())
    }

    /**
     * The Function is !=
     *
     * @param b of StyleT
     *
     * @return Type of Bool
     * @since 0.30.4
     */
    /*public operator func !=(b: StyleT): Bool {
        ne(getCode(), b.getCode())
    }

    /**
     * The Function is toString
     *
     * @return Type of String
     * @since 0.30.4
     */
    public func toString(): String {
        match (this) {
            case MappingStyleT_ANY_MAPPING_STYLE => "MappingStyleT_ANY_MAPPING_STYLE"
            case MappingStyleT_BLOCK_MAPPING_STYLE => "MappingStyleT_BLOCK_MAPPING_STYLE"
            case MappingStyleT_FLOW_MAPPING_STYLE => "MappingStyleT_FLOW_MAPPING_STYLE"
        }
    }*/
}
