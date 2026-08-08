/*
 * @Copyright (c) Huawei Technologies Co., Ltd. 2022-2026. All rights reserved.
 */

/**
 * @file
 * This file is about chart set
 */

package charset4cj.charset.encoding

/**
 * The class is Charset
 * @author freeonsky
 * @since 0.28.4
 */
public abstract class Charset <: Hashable & Equatable<Charset> & Equatable<String> & ToString {
    protected let name: String
    private let labels_ = HashSet<String>()
    protected init(name: String, labels: Array<String>){
        this.name = name
        putLabel(name, this.labels_)
        for(label in labels){
            putLabel(label, this.labels_)
        }
    }

    private static func putLabel(label: String, labels: Set<String>){
        labels.add(label)
        labels.add(label.toAsciiLower())
        labels.add(label.toAsciiUpper())
    }

    public func hashCode(): Int64 {
        name.hashCode()
    }
    public operator func ==(rhs: Charset){
        nameEquals(rhs.name)
    }
    public operator func !=(rhs: Charset){
        !(this == rhs)
    }
    public operator func ==(name: String){
        nameEquals(name)
    }
    public operator func !=(name: String){
        !(this == name)
    }
    public func toString(){
        name
    }
    public func labels(): Iterator<String>{
        labels_.iterator()
    }

    /**
     * Judge whether the character set name (or labels) is a given string
     *
     * @param name Character set name
     *
     * @return Bool
     * @since 0.28.4
     */
    public func nameEquals(n:String):Bool{
        labels_.contains(n)
    }

    /**
     * Encodes a string into a byte array
     *
     * @return Type of Encoder
     * @since 0.28.4
     */
    public func newEncoder():Encoder

    /**
     * Decodes a byte array into a string
     *
     * @return Type of Decoder
     * @since 0.28.4
     */
    public func newDecoder():Decoder
}
