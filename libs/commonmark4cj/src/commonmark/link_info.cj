/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2025-2025. All rights resvered.
 */
package commonmark4cj.commonmark

/**
 * A parsed link/image. There are different types of links.
 * <p>
 * Inline links:
 * <pre>
 * [text](destination)
 * [text](destination "title")
 * </pre>
 * <p>
 * Reference links, which have different subtypes. Full::
 * <pre>
 * [text][label]
 * </pre>
 * Collapsed (label is ""):
 * <pre>
 * [text][]
 * </pre>
 * Shortcut (label is None):
 * <pre>
 * [text]
 * </pre>
 * Images use the same syntax as links but with a {@code !} {@link #marker()} front, e.g. {@code ![text](destination)}.
 */
public interface LinkInfo {

    /**
     * The marker if present, or None. A marker is e.g. {@code !} for an image, or a custom marker as specified in
     * {@link org.commonmark.parser.Parser.Builder#linkMarker}.
     */
    func marker(): ?Text

    /**
     * The text node of the opening bracket {@code [}.
     */
    func openingBracket(): Text

    /**
     * The text between the first brackets, e.g. `foo` in `[foo][bar]`.
     */
    func text(): String

    /**
     * The label, or None for inline links or for shortcut links (in which case {@link #text()} should be used as the label).
     */
    func label(): ?String

    /**
     * The destination if available, e.g. in `[foo](destination)`, or None
     */
    func destination(): ?String

    /**
     * The title if available, e.g. in `[foo](destination "title")`, or None
     */
    func title(): ?String

    /**
     * The position after the closing text bracket, e.g.:
     * <pre>
     * [foo][bar]
     *      ^
     * </pre>
     */
    func afterTextBracket(): SourcePosition
}

public class LinkInfoImpl <: LinkInfo {
    private let _marker: ?Text
    private let _openingBracket: Text
    private let _text: String
    private let _label: ?String
    private let _destination: ?String
    private let _title: ?String
    private let _afterTextBracket: SourcePosition

    public LinkInfoImpl(
        marker: ?Text,
        openingBracket: Text,
        text: String,
        label: ?String,
        destination: ?String,
        title: ?String,
        afterTextBracket: SourcePosition
    ) {
        this._marker = marker
        this._openingBracket = openingBracket
        this._text = text
        this._label = label
        this._destination = destination
        this._title = title
        this._afterTextBracket = afterTextBracket
    }

    // @Override
    public func marker(): ?Text {
        return _marker
    }

    // @Override
    public func openingBracket(): Text {
        return _openingBracket
    }

    // @Override
    public func text(): String {
        return _text
    }

    // @Override
    public func label(): ?String {
        return _label
    }

    // @Override
    public func destination(): ?String {
        return _destination
    }

    // @Override
    public func title(): ?String {
        return _title
    }

    // @Override
    public func afterTextBracket(): SourcePosition {
        return _afterTextBracket
    }
}
