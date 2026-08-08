/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2024. All rights reserved.
 */
package zip4cj.headers

let encode_arr: Array<Rune> = [
    r'\u{00}', //  0x0000 -> NULL
    r'\u{01}', //  0x0001 -> START OF HEADING
    r'\u{02}', //  0x0002 -> START OF TEXT
    r'\u{03}', //  0x0003 -> END OF TEXT
    r'\u{04}', //  0x0004 -> END OF TRANSMISSION
    r'\u{05}', //  0x0005 -> ENQUIRY
    r'\u{06}', //  0x0006 -> ACKNOWLEDGE
    r'\u{07}', //  0x0007 -> BELL
    r'\u{08}', //  0x0008 -> BACKSPACE
    r'\t', //  0x0009 -> HORIZONTAL TABULATION
    r'\n', //  0x000a -> LINE FEED
    r'\u{0b}', //  0x000b -> VERTICAL TABULATION
    r'\u{0c}', //  0x000c -> FORM FEED
    r'\r', //  0x000d -> CARRIAGE RETURN
    r'\u{0e}', //  0x000e -> SHIFT OUT
    r'\u{0f}', //  0x000f -> SHIFT IN
    r'\u{10}', //  0x0010 -> DATA LINK ESCAPE
    r'\u{11}', //  0x0011 -> DEVICE CONTROL ONE
    r'\u{12}', //  0x0012 -> DEVICE CONTROL TWO
    r'\u{13}', //  0x0013 -> DEVICE CONTROL THREE
    r'\u{14}', //  0x0014 -> DEVICE CONTROL FOUR
    r'\u{15}', //  0x0015 -> NEGATIVE ACKNOWLEDGE
    r'\u{16}', //  0x0016 -> SYNCHRONOUS IDLE
    r'\u{17}', //  0x0017 -> END OF TRANSMISSION BLOCK
    r'\u{18}', //  0x0018 -> CANCEL
    r'\u{19}', //  0x0019 -> END OF MEDIUM
    r'\u{1a}', //  0x001a -> SUBSTITUTE
    r'\u{1b}', //  0x001b -> ESCAPE
    r'\u{1c}', //  0x001c -> FILE SEPARATOR
    r'\u{1d}', //  0x001d -> GROUP SEPARATOR
    r'\u{1e}', //  0x001e -> RECORD SEPARATOR
    r'\u{1f}', //  0x001f -> UNIT SEPARATOR
    r' ', //  0x0020 -> SPACE
    r'!', //  0x0021 -> EXCLAMATION MARK
    r'"', //  0x0022 -> QUOTATION MARK
    r'#', //  0x0023 -> NUMBER SIGN
    r'$', //  0x0024 -> DOLLAR SIGN
    r'%', //  0x0025 -> PERCENT SIGN
    r'&', //  0x0026 -> AMPERSAND
    r'\'', //  0x0027 -> APOSTROPHE
    r'(', //  0x0028 -> LEFT PARENTHESIS
    r')', //  0x0029 -> RIGHT PARENTHESIS
    r'*', //  0x002a -> ASTERISK
    r'+', //  0x002b -> PLUS SIGN
    r',', //  0x002c -> COMMA
    r'-', //  0x002d -> HYPHEN-MINUS
    r'.', //  0x002e -> FULL STOP
    r'/', //  0x002f -> SOLIDUS
    r'0', //  0x0030 -> DIGIT ZERO
    r'1', //  0x0031 -> DIGIT ONE
    r'2', //  0x0032 -> DIGIT TWO
    r'3', //  0x0033 -> DIGIT THREE
    r'4', //  0x0034 -> DIGIT FOUR
    r'5', //  0x0035 -> DIGIT FIVE
    r'6', //  0x0036 -> DIGIT SIX
    r'7', //  0x0037 -> DIGIT SEVEN
    r'8', //  0x0038 -> DIGIT EIGHT
    r'9', //  0x0039 -> DIGIT NINE
    r':', //  0x003a -> COLON
    r';', //  0x003b -> SEMICOLON
    r'<', //  0x003c -> LESS-THAN SIGN
    r'=', //  0x003d -> EQUALS SIGN
    r'>', //  0x003e -> GREATER-THAN SIGN
    r'?', //  0x003f -> QUESTION MARK
    r'@', //  0x0040 -> COMMERCIAL AT
    r'A', //  0x0041 -> LATIN CAPITAL LETTER A
    r'B', //  0x0042 -> LATIN CAPITAL LETTER B
    r'C', //  0x0043 -> LATIN CAPITAL LETTER C
    r'D', //  0x0044 -> LATIN CAPITAL LETTER D
    r'E', //  0x0045 -> LATIN CAPITAL LETTER E
    r'F', //  0x0046 -> LATIN CAPITAL LETTER F
    r'G', //  0x0047 -> LATIN CAPITAL LETTER G
    r'H', //  0x0048 -> LATIN CAPITAL LETTER H
    r'I', //  0x0049 -> LATIN CAPITAL LETTER I
    r'J', //  0x004a -> LATIN CAPITAL LETTER J
    r'K', //  0x004b -> LATIN CAPITAL LETTER K
    r'L', //  0x004c -> LATIN CAPITAL LETTER L
    r'M', //  0x004d -> LATIN CAPITAL LETTER M
    r'N', //  0x004e -> LATIN CAPITAL LETTER N
    r'O', //  0x004f -> LATIN CAPITAL LETTER O
    r'P', //  0x0050 -> LATIN CAPITAL LETTER P
    r'Q', //  0x0051 -> LATIN CAPITAL LETTER Q
    r'R', //  0x0052 -> LATIN CAPITAL LETTER R
    r'S', //  0x0053 -> LATIN CAPITAL LETTER S
    r'T', //  0x0054 -> LATIN CAPITAL LETTER T
    r'U', //  0x0055 -> LATIN CAPITAL LETTER U
    r'V', //  0x0056 -> LATIN CAPITAL LETTER V
    r'W', //  0x0057 -> LATIN CAPITAL LETTER W
    r'X', //  0x0058 -> LATIN CAPITAL LETTER X
    r'Y', //  0x0059 -> LATIN CAPITAL LETTER Y
    r'Z', //  0x005a -> LATIN CAPITAL LETTER Z
    r'[', //  0x005b -> LEFT SQUARE BRACKET
    r'\\', //  0x005c -> REVERSE SOLIDUS
    r']', //  0x005d -> RIGHT SQUARE BRACKET
    r'^', //  0x005e -> CIRCUMFLEX ACCENT
    r'_', //  0x005f -> LOW LINE
    r'`', //  0x0060 -> GRAVE ACCENT
    r'a', //  0x0061 -> LATIN SMALL LETTER A
    r'b', //  0x0062 -> LATIN SMALL LETTER B
    r'c', //  0x0063 -> LATIN SMALL LETTER C
    r'd', //  0x0064 -> LATIN SMALL LETTER D
    r'e', //  0x0065 -> LATIN SMALL LETTER E
    r'f', //  0x0066 -> LATIN SMALL LETTER F
    r'g', //  0x0067 -> LATIN SMALL LETTER G
    r'h', //  0x0068 -> LATIN SMALL LETTER H
    r'i', //  0x0069 -> LATIN SMALL LETTER I
    r'j', //  0x006a -> LATIN SMALL LETTER J
    r'k', //  0x006b -> LATIN SMALL LETTER K
    r'l', //  0x006c -> LATIN SMALL LETTER L
    r'm', //  0x006d -> LATIN SMALL LETTER M
    r'n', //  0x006e -> LATIN SMALL LETTER N
    r'o', //  0x006f -> LATIN SMALL LETTER O
    r'p', //  0x0070 -> LATIN SMALL LETTER P
    r'q', //  0x0071 -> LATIN SMALL LETTER Q
    r'r', //  0x0072 -> LATIN SMALL LETTER R
    r's', //  0x0073 -> LATIN SMALL LETTER S
    r't', //  0x0074 -> LATIN SMALL LETTER T
    r'u', //  0x0075 -> LATIN SMALL LETTER U
    r'v', //  0x0076 -> LATIN SMALL LETTER V
    r'w', //  0x0077 -> LATIN SMALL LETTER W
    r'x', //  0x0078 -> LATIN SMALL LETTER X
    r'y', //  0x0079 -> LATIN SMALL LETTER Y
    r'z', //  0x007a -> LATIN SMALL LETTER Z
    r'{', //  0x007b -> LEFT CURLY BRACKET
    r'|', //  0x007c -> VERTICAL LINE
    r'}', //  0x007d -> RIGHT CURLY BRACKET
    r'~', //  0x007e -> TILDE
    r'\u{7f}', //  0x007f -> DELETE
    r'\u{c7}', //  0x0080 -> LATIN CAPITAL LETTER C WITH CEDILLA
    r'\u{fc}', //  0x0081 -> LATIN SMALL LETTER U WITH DIAERESIS
    r'\u{e9}', //  0x0082 -> LATIN SMALL LETTER E WITH ACUTE
    r'\u{e2}', //  0x0083 -> LATIN SMALL LETTER A WITH CIRCUMFLEX
    r'\u{e4}', //  0x0084 -> LATIN SMALL LETTER A WITH DIAERESIS
    r'\u{e0}', //  0x0085 -> LATIN SMALL LETTER A WITH GRAVE
    r'\u{e5}', //  0x0086 -> LATIN SMALL LETTER A WITH RING ABOVE
    r'\u{e7}', //  0x0087 -> LATIN SMALL LETTER C WITH CEDILLA
    r'\u{ea}', //  0x0088 -> LATIN SMALL LETTER E WITH CIRCUMFLEX
    r'\u{eb}', //  0x0089 -> LATIN SMALL LETTER E WITH DIAERESIS
    r'\u{e8}', //  0x008a -> LATIN SMALL LETTER E WITH GRAVE
    r'\u{ef}', //  0x008b -> LATIN SMALL LETTER I WITH DIAERESIS
    r'\u{ee}', //  0x008c -> LATIN SMALL LETTER I WITH CIRCUMFLEX
    r'\u{ec}', //  0x008d -> LATIN SMALL LETTER I WITH GRAVE
    r'\u{c4}', //  0x008e -> LATIN CAPITAL LETTER A WITH DIAERESIS
    r'\u{c5}', //  0x008f -> LATIN CAPITAL LETTER A WITH RING ABOVE
    r'\u{c9}', //  0x0090 -> LATIN CAPITAL LETTER E WITH ACUTE
    r'\u{e6}', //  0x0091 -> LATIN SMALL LIGATURE AE
    r'\u{c6}', //  0x0092 -> LATIN CAPITAL LIGATURE AE
    r'\u{f4}', //  0x0093 -> LATIN SMALL LETTER O WITH CIRCUMFLEX
    r'\u{f6}', //  0x0094 -> LATIN SMALL LETTER O WITH DIAERESIS
    r'\u{f2}', //  0x0095 -> LATIN SMALL LETTER O WITH GRAVE
    r'\u{fb}', //  0x0096 -> LATIN SMALL LETTER U WITH CIRCUMFLEX
    r'\u{f9}', //  0x0097 -> LATIN SMALL LETTER U WITH GRAVE
    r'\u{ff}', //  0x0098 -> LATIN SMALL LETTER Y WITH DIAERESIS
    r'\u{d6}', //  0x0099 -> LATIN CAPITAL LETTER O WITH DIAERESIS
    r'\u{dc}', //  0x009a -> LATIN CAPITAL LETTER U WITH DIAERESIS
    r'\u{a2}', //  0x009b -> CENT SIGN
    r'\u{a3}', //  0x009c -> POUND SIGN
    r'\u{a5}', //  0x009d -> YEN SIGN
    r'\u{20a7}', //  0x009e -> PESETA SIGN
    r'\u{0192}', //  0x009f -> LATIN SMALL LETTER F WITH HOOK
    r'\u{e1}', //  0x00a0 -> LATIN SMALL LETTER A WITH ACUTE
    r'\u{ed}', //  0x00a1 -> LATIN SMALL LETTER I WITH ACUTE
    r'\u{f3}', //  0x00a2 -> LATIN SMALL LETTER O WITH ACUTE
    r'\u{fa}', //  0x00a3 -> LATIN SMALL LETTER U WITH ACUTE
    r'\u{f1}', //  0x00a4 -> LATIN SMALL LETTER N WITH TILDE
    r'\u{d1}', //  0x00a5 -> LATIN CAPITAL LETTER N WITH TILDE
    r'\u{aa}', //  0x00a6 -> FEMININE ORDINAL INDICATOR
    r'\u{ba}', //  0x00a7 -> MASCULINE ORDINAL INDICATOR
    r'\u{bf}', //  0x00a8 -> INVERTED QUESTION MARK
    r'\u{2310}', //  0x00a9 -> REVERSED NOT SIGN
    r'\u{ac}', //  0x00aa -> NOT SIGN
    r'\u{bd}', //  0x00ab -> VULGAR FRACTION ONE HALF
    r'\u{bc}', //  0x00ac -> VULGAR FRACTION ONE QUARTER
    r'\u{a1}', //  0x00ad -> INVERTED EXCLAMATION MARK
    r'\u{ab}', //  0x00ae -> LEFT-POINTING DOUBLE ANGLE QUOTATION MARK
    r'\u{bb}', //  0x00af -> RIGHT-POINTING DOUBLE ANGLE QUOTATION MARK
    r'\u{2591}', //  0x00b0 -> LIGHT SHADE
    r'\u{2592}', //  0x00b1 -> MEDIUM SHADE
    r'\u{2593}', //  0x00b2 -> DARK SHADE
    r'\u{2502}', //  0x00b3 -> BOX DRAWINGS LIGHT VERTICAL
    r'\u{2524}', //  0x00b4 -> BOX DRAWINGS LIGHT VERTICAL AND LEFT
    r'\u{2561}', //  0x00b5 -> BOX DRAWINGS VERTICAL SINGLE AND LEFT DOUBLE
    r'\u{2562}', //  0x00b6 -> BOX DRAWINGS VERTICAL DOUBLE AND LEFT SINGLE
    r'\u{2556}', //  0x00b7 -> BOX DRAWINGS DOWN DOUBLE AND LEFT SINGLE
    r'\u{2555}', //  0x00b8 -> BOX DRAWINGS DOWN SINGLE AND LEFT DOUBLE
    r'\u{2563}', //  0x00b9 -> BOX DRAWINGS DOUBLE VERTICAL AND LEFT
    r'\u{2551}', //  0x00ba -> BOX DRAWINGS DOUBLE VERTICAL
    r'\u{2557}', //  0x00bb -> BOX DRAWINGS DOUBLE DOWN AND LEFT
    r'\u{255d}', //  0x00bc -> BOX DRAWINGS DOUBLE UP AND LEFT
    r'\u{255c}', //  0x00bd -> BOX DRAWINGS UP DOUBLE AND LEFT SINGLE
    r'\u{255b}', //  0x00be -> BOX DRAWINGS UP SINGLE AND LEFT DOUBLE
    r'\u{2510}', //  0x00bf -> BOX DRAWINGS LIGHT DOWN AND LEFT
    r'\u{2514}', //  0x00c0 -> BOX DRAWINGS LIGHT UP AND RIGHT
    r'\u{2534}', //  0x00c1 -> BOX DRAWINGS LIGHT UP AND HORIZONTAL
    r'\u{252c}', //  0x00c2 -> BOX DRAWINGS LIGHT DOWN AND HORIZONTAL
    r'\u{251c}', //  0x00c3 -> BOX DRAWINGS LIGHT VERTICAL AND RIGHT
    r'\u{2500}', //  0x00c4 -> BOX DRAWINGS LIGHT HORIZONTAL
    r'\u{253c}', //  0x00c5 -> BOX DRAWINGS LIGHT VERTICAL AND HORIZONTAL
    r'\u{255e}', //  0x00c6 -> BOX DRAWINGS VERTICAL SINGLE AND RIGHT DOUBLE
    r'\u{255f}', //  0x00c7 -> BOX DRAWINGS VERTICAL DOUBLE AND RIGHT SINGLE
    r'\u{255a}', //  0x00c8 -> BOX DRAWINGS DOUBLE UP AND RIGHT
    r'\u{2554}', //  0x00c9 -> BOX DRAWINGS DOUBLE DOWN AND RIGHT
    r'\u{2569}', //  0x00ca -> BOX DRAWINGS DOUBLE UP AND HORIZONTAL
    r'\u{2566}', //  0x00cb -> BOX DRAWINGS DOUBLE DOWN AND HORIZONTAL
    r'\u{2560}', //  0x00cc -> BOX DRAWINGS DOUBLE VERTICAL AND RIGHT
    r'\u{2550}', //  0x00cd -> BOX DRAWINGS DOUBLE HORIZONTAL
    r'\u{256c}', //  0x00ce -> BOX DRAWINGS DOUBLE VERTICAL AND HORIZONTAL
    r'\u{2567}', //  0x00cf -> BOX DRAWINGS UP SINGLE AND HORIZONTAL DOUBLE
    r'\u{2568}', //  0x00d0 -> BOX DRAWINGS UP DOUBLE AND HORIZONTAL SINGLE
    r'\u{2564}', //  0x00d1 -> BOX DRAWINGS DOWN SINGLE AND HORIZONTAL DOUBLE
    r'\u{2565}', //  0x00d2 -> BOX DRAWINGS DOWN DOUBLE AND HORIZONTAL SINGLE
    r'\u{2559}', //  0x00d3 -> BOX DRAWINGS UP DOUBLE AND RIGHT SINGLE
    r'\u{2558}', //  0x00d4 -> BOX DRAWINGS UP SINGLE AND RIGHT DOUBLE
    r'\u{2552}', //  0x00d5 -> BOX DRAWINGS DOWN SINGLE AND RIGHT DOUBLE
    r'\u{2553}', //  0x00d6 -> BOX DRAWINGS DOWN DOUBLE AND RIGHT SINGLE
    r'\u{256b}', //  0x00d7 -> BOX DRAWINGS VERTICAL DOUBLE AND HORIZONTAL SINGLE
    r'\u{256a}', //  0x00d8 -> BOX DRAWINGS VERTICAL SINGLE AND HORIZONTAL DOUBLE
    r'\u{2518}', //  0x00d9 -> BOX DRAWINGS LIGHT UP AND LEFT
    r'\u{250c}', //  0x00da -> BOX DRAWINGS LIGHT DOWN AND RIGHT
    r'\u{2588}', //  0x00db -> FULL BLOCK
    r'\u{2584}', //  0x00dc -> LOWER HALF BLOCK
    r'\u{258c}', //  0x00dd -> LEFT HALF BLOCK
    r'\u{2590}', //  0x00de -> RIGHT HALF BLOCK
    r'\u{2580}', //  0x00df -> UPPER HALF BLOCK
    r'\u{03b1}', //  0x00e0 -> GREEK SMALL LETTER ALPHA
    r'\u{df}', //  0x00e1 -> LATIN SMALL LETTER SHARP S
    r'\u{0393}', //  0x00e2 -> GREEK CAPITAL LETTER GAMMA
    r'\u{03c0}', //  0x00e3 -> GREEK SMALL LETTER PI
    r'\u{03a3}', //  0x00e4 -> GREEK CAPITAL LETTER SIGMA
    r'\u{03c3}', //  0x00e5 -> GREEK SMALL LETTER SIGMA
    r'\u{b5}', //  0x00e6 -> MICRO SIGN
    r'\u{03c4}', //  0x00e7 -> GREEK SMALL LETTER TAU
    r'\u{03a6}', //  0x00e8 -> GREEK CAPITAL LETTER PHI
    r'\u{0398}', //  0x00e9 -> GREEK CAPITAL LETTER THETA
    r'\u{03a9}', //  0x00ea -> GREEK CAPITAL LETTER OMEGA
    r'\u{03b4}', //  0x00eb -> GREEK SMALL LETTER DELTA
    r'\u{221e}', //  0x00ec -> INFINITY
    r'\u{03c6}', //  0x00ed -> GREEK SMALL LETTER PHI
    r'\u{03b5}', //  0x00ee -> GREEK SMALL LETTER EPSILON
    r'\u{2229}', //  0x00ef -> INTERSECTION
    r'\u{2261}', //  0x00f0 -> IDENTICAL TO
    r'\u{b1}', //  0x00f1 -> PLUS-MINUS SIGN
    r'\u{2265}', //  0x00f2 -> GREATER-THAN OR EQUAL TO
    r'\u{2264}', //  0x00f3 -> LESS-THAN OR EQUAL TO
    r'\u{2320}', //  0x00f4 -> TOP HALF INTEGRAL
    r'\u{2321}', //  0x00f5 -> BOTTOM HALF INTEGRAL
    r'\u{f7}', //  0x00f6 -> DIVISION SIGN
    r'\u{2248}', //  0x00f7 -> ALMOST EQUAL TO
    r'\u{b0}', //  0x00f8 -> DEGREE SIGN
    r'\u{2219}', //  0x00f9 -> BULLET OPERATOR
    r'\u{b7}', //  0x00fa -> MIDDLE DOT
    r'\u{221a}', //  0x00fb -> SQUARE ROOT
    r'\u{207f}', //  0x00fc -> SUPERSCRIPT LATIN SMALL LETTER N
    r'\u{b2}', //  0x00fd -> SUPERSCRIPT TWO
    r'\u{25a0}', //  0x00fe -> BLACK SQUARE
    r'\u{a0}' //  0x00ff -> NO-BREAK SPACE
]

let encode_map: HashMap<Int64, Rune> = HashMap<Int64, Rune>(
    [
        (0x0080, r'\u{00c7}'), //  LATIN CAPITAL LETTER C WITH CEDILLA
        (0x0081, r'\u{00fc}'), //  LATIN SMALL LETTER U WITH DIAERESIS
        (0x0082, r'\u{00e9}'), //  LATIN SMALL LETTER E WITH ACUTE
        (0x0083, r'\u{00e2}'), //  LATIN SMALL LETTER A WITH CIRCUMFLEX
        (0x0084, r'\u{00e4}'), //  LATIN SMALL LETTER A WITH DIAERESIS
        (0x0085, r'\u{00e0}'), //  LATIN SMALL LETTER A WITH GRAVE
        (0x0086, r'\u{00e5}'), //  LATIN SMALL LETTER A WITH RING ABOVE
        (0x0087, r'\u{00e7}'), //  LATIN SMALL LETTER C WITH CEDILLA
        (0x0088, r'\u{00ea}'), //  LATIN SMALL LETTER E WITH CIRCUMFLEX
        (0x0089, r'\u{00eb}'), //  LATIN SMALL LETTER E WITH DIAERESIS
        (0x008a, r'\u{00e8}'), //  LATIN SMALL LETTER E WITH GRAVE
        (0x008b, r'\u{00ef}'), //  LATIN SMALL LETTER I WITH DIAERESIS
        (0x008c, r'\u{00ee}'), //  LATIN SMALL LETTER I WITH CIRCUMFLEX
        (0x008d, r'\u{00ec}'), //  LATIN SMALL LETTER I WITH GRAVE
        (0x008e, r'\u{00c4}'), //  LATIN CAPITAL LETTER A WITH DIAERESIS
        (0x008f, r'\u{00c5}'), //  LATIN CAPITAL LETTER A WITH RING ABOVE
        (0x0090, r'\u{00c9}'), //  LATIN CAPITAL LETTER E WITH ACUTE
        (0x0091, r'\u{00e6}'), //  LATIN SMALL LIGATURE AE
        (0x0092, r'\u{00c6}'), //  LATIN CAPITAL LIGATURE AE
        (0x0093, r'\u{00f4}'), //  LATIN SMALL LETTER O WITH CIRCUMFLEX
        (0x0094, r'\u{00f6}'), //  LATIN SMALL LETTER O WITH DIAERESIS
        (0x0095, r'\u{00f2}'), //  LATIN SMALL LETTER O WITH GRAVE
        (0x0096, r'\u{00fb}'), //  LATIN SMALL LETTER U WITH CIRCUMFLEX
        (0x0097, r'\u{00f9}'), //  LATIN SMALL LETTER U WITH GRAVE
        (0x0098, r'\u{00ff}'), //  LATIN SMALL LETTER Y WITH DIAERESIS
        (0x0099, r'\u{00d6}'), //  LATIN CAPITAL LETTER O WITH DIAERESIS
        (0x009a, r'\u{00dc}'), //  LATIN CAPITAL LETTER U WITH DIAERESIS
        (0x009b, r'\u{00a2}'), //  CENT SIGN
        (0x009c, r'\u{00a3}'), //  POUND SIGN
        (0x009d, r'\u{00a5}'), //  YEN SIGN
        (0x009e, r'\u{20a7}'), //  PESETA SIGN
        (0x009f, r'\u{0192}'), //  LATIN SMALL LETTER F WITH HOOK
        (0x00a0, r'\u{00e1}'), //  LATIN SMALL LETTER A WITH ACUTE
        (0x00a1, r'\u{00ed}'), //  LATIN SMALL LETTER I WITH ACUTE
        (0x00a2, r'\u{00f3}'), //  LATIN SMALL LETTER O WITH ACUTE
        (0x00a3, r'\u{00fa}'), //  LATIN SMALL LETTER U WITH ACUTE
        (0x00a4, r'\u{00f1}'), //  LATIN SMALL LETTER N WITH TILDE
        (0x00a5, r'\u{00d1}'), //  LATIN CAPITAL LETTER N WITH TILDE
        (0x00a6, r'\u{00aa}'), //  FEMININE ORDINAL INDICATOR
        (0x00a7, r'\u{00ba}'), //  MASCULINE ORDINAL INDICATOR
        (0x00a8, r'\u{00bf}'), //  INVERTED QUESTION MARK
        (0x00a9, r'\u{2310}'), //  REVERSED NOT SIGN
        (0x00aa, r'\u{00ac}'), //  NOT SIGN
        (0x00ab, r'\u{00bd}'), //  VULGAR FRACTION ONE HALF
        (0x00ac, r'\u{00bc}'), //  VULGAR FRACTION ONE QUARTER
        (0x00ad, r'\u{00a1}'), //  INVERTED EXCLAMATION MARK
        (0x00ae, r'\u{00ab}'), //  LEFT-POINTING DOUBLE ANGLE QUOTATION MARK
        (0x00af, r'\u{00bb}'), //  RIGHT-POINTING DOUBLE ANGLE QUOTATION MARK
        (0x00b0, r'\u{2591}'), //  LIGHT SHADE
        (0x00b1, r'\u{2592}'), //  MEDIUM SHADE
        (0x00b2, r'\u{2593}'), //  DARK SHADE
        (0x00b3, r'\u{2502}'), //  BOX DRAWINGS LIGHT VERTICAL
        (0x00b4, r'\u{2524}'), //  BOX DRAWINGS LIGHT VERTICAL AND LEFT
        (0x00b5, r'\u{2561}'), //  BOX DRAWINGS VERTICAL SINGLE AND LEFT DOUBLE
        (0x00b6, r'\u{2562}'), //  BOX DRAWINGS VERTICAL DOUBLE AND LEFT SINGLE
        (0x00b7, r'\u{2556}'), //  BOX DRAWINGS DOWN DOUBLE AND LEFT SINGLE
        (0x00b8, r'\u{2555}'), //  BOX DRAWINGS DOWN SINGLE AND LEFT DOUBLE
        (0x00b9, r'\u{2563}'), //  BOX DRAWINGS DOUBLE VERTICAL AND LEFT
        (0x00ba, r'\u{2551}'), //  BOX DRAWINGS DOUBLE VERTICAL
        (0x00bb, r'\u{2557}'), //  BOX DRAWINGS DOUBLE DOWN AND LEFT
        (0x00bc, r'\u{255d}'), //  BOX DRAWINGS DOUBLE UP AND LEFT
        (0x00bd, r'\u{255c}'), //  BOX DRAWINGS UP DOUBLE AND LEFT SINGLE
        (0x00be, r'\u{255b}'), //  BOX DRAWINGS UP SINGLE AND LEFT DOUBLE
        (0x00bf, r'\u{2510}'), //  BOX DRAWINGS LIGHT DOWN AND LEFT
        (0x00c0, r'\u{2514}'), //  BOX DRAWINGS LIGHT UP AND RIGHT
        (0x00c1, r'\u{2534}'), //  BOX DRAWINGS LIGHT UP AND HORIZONTAL
        (0x00c2, r'\u{252c}'), //  BOX DRAWINGS LIGHT DOWN AND HORIZONTAL
        (0x00c3, r'\u{251c}'), //  BOX DRAWINGS LIGHT VERTICAL AND RIGHT
        (0x00c4, r'\u{2500}'), //  BOX DRAWINGS LIGHT HORIZONTAL
        (0x00c5, r'\u{253c}'), //  BOX DRAWINGS LIGHT VERTICAL AND HORIZONTAL
        (0x00c6, r'\u{255e}'), //  BOX DRAWINGS VERTICAL SINGLE AND RIGHT DOUBLE
        (0x00c7, r'\u{255f}'), //  BOX DRAWINGS VERTICAL DOUBLE AND RIGHT SINGLE
        (0x00c8, r'\u{255a}'), //  BOX DRAWINGS DOUBLE UP AND RIGHT
        (0x00c9, r'\u{2554}'), //  BOX DRAWINGS DOUBLE DOWN AND RIGHT
        (0x00ca, r'\u{2569}'), //  BOX DRAWINGS DOUBLE UP AND HORIZONTAL
        (0x00cb, r'\u{2566}'), //  BOX DRAWINGS DOUBLE DOWN AND HORIZONTAL
        (0x00cc, r'\u{2560}'), //  BOX DRAWINGS DOUBLE VERTICAL AND RIGHT
        (0x00cd, r'\u{2550}'), //  BOX DRAWINGS DOUBLE HORIZONTAL
        (0x00ce, r'\u{256c}'), //  BOX DRAWINGS DOUBLE VERTICAL AND HORIZONTAL
        (0x00cf, r'\u{2567}'), //  BOX DRAWINGS UP SINGLE AND HORIZONTAL DOUBLE
        (0x00d0, r'\u{2568}'), //  BOX DRAWINGS UP DOUBLE AND HORIZONTAL SINGLE
        (0x00d1, r'\u{2564}'), //  BOX DRAWINGS DOWN SINGLE AND HORIZONTAL DOUBLE
        (0x00d2, r'\u{2565}'), //  BOX DRAWINGS DOWN DOUBLE AND HORIZONTAL SINGLE
        (0x00d3, r'\u{2559}'), //  BOX DRAWINGS UP DOUBLE AND RIGHT SINGLE
        (0x00d4, r'\u{2558}'), //  BOX DRAWINGS UP SINGLE AND RIGHT DOUBLE
        (0x00d5, r'\u{2552}'), //  BOX DRAWINGS DOWN SINGLE AND RIGHT DOUBLE
        (0x00d6, r'\u{2553}'), //  BOX DRAWINGS DOWN DOUBLE AND RIGHT SINGLE
        (0x00d7, r'\u{256b}'), //  BOX DRAWINGS VERTICAL DOUBLE AND HORIZONTAL SINGLE
        (0x00d8, r'\u{256a}'), //  BOX DRAWINGS VERTICAL SINGLE AND HORIZONTAL DOUBLE
        (0x00d9, r'\u{2518}'), //  BOX DRAWINGS LIGHT UP AND LEFT
        (0x00da, r'\u{250c}'), //  BOX DRAWINGS LIGHT DOWN AND RIGHT
        (0x00db, r'\u{2588}'), //  FULL BLOCK
        (0x00dc, r'\u{2584}'), //  LOWER HALF BLOCK
        (0x00dd, r'\u{258c}'), //  LEFT HALF BLOCK
        (0x00de, r'\u{2590}'), //  RIGHT HALF BLOCK
        (0x00df, r'\u{2580}'), //  UPPER HALF BLOCK
        (0x00e0, r'\u{03b1}'), //  GREEK SMALL LETTER ALPHA
        (0x00e1, r'\u{00df}'), //  LATIN SMALL LETTER SHARP S
        (0x00e2, r'\u{0393}'), //  GREEK CAPITAL LETTER GAMMA
        (0x00e3, r'\u{03c0}'), //  GREEK SMALL LETTER PI
        (0x00e4, r'\u{03a3}'), //  GREEK CAPITAL LETTER SIGMA
        (0x00e5, r'\u{03c3}'), //  GREEK SMALL LETTER SIGMA
        (0x00e6, r'\u{00b5}'), //  MICRO SIGN
        (0x00e7, r'\u{03c4}'), //  GREEK SMALL LETTER TAU
        (0x00e8, r'\u{03a6}'), //  GREEK CAPITAL LETTER PHI
        (0x00e9, r'\u{0398}'), //  GREEK CAPITAL LETTER THETA
        (0x00ea, r'\u{03a9}'), //  GREEK CAPITAL LETTER OMEGA
        (0x00eb, r'\u{03b4}'), //  GREEK SMALL LETTER DELTA
        (0x00ec, r'\u{221e}'), //  INFINITY
        (0x00ed, r'\u{03c6}'), //  GREEK SMALL LETTER PHI
        (0x00ee, r'\u{03b5}'), //  GREEK SMALL LETTER EPSILON
        (0x00ef, r'\u{2229}'), //  INTERSECTION
        (0x00f0, r'\u{2261}'), //  IDENTICAL TO
        (0x00f1, r'\u{00b1}'), //  PLUS-MINUS SIGN
        (0x00f2, r'\u{2265}'), //  GREATER-THAN OR EQUAL TO
        (0x00f3, r'\u{2264}'), //  LESS-THAN OR EQUAL TO
        (0x00f4, r'\u{2320}'), //  TOP HALF INTEGRAL
        (0x00f5, r'\u{2321}'), //  BOTTOM HALF INTEGRAL
        (0x00f6, r'\u{00f7}'), //  DIVISION SIGN
        (0x00f7, r'\u{2248}'), //  ALMOST EQUAL TO
        (0x00f8, r'\u{00b0}'), //  DEGREE SIGN
        (0x00f9, r'\u{2219}'), //  BULLET OPERATOR
        (0x00fa, r'\u{00b7}'), //  MIDDLE DOT
        (0x00fb, r'\u{221a}'), //  SQUARE ROOT
        (0x00fc, r'\u{207f}'), //  SUPERSCRIPT LATIN SMALL LETTER N
        (0x00fd, r'\u{00b2}'), //  SUPERSCRIPT TWO
        (0x00fe, r'\u{25a0}'), //  BLACK SQUARE
        (0x00ff, r'\u{00a0}') //  NO-BREAK SPACE
    ]
)

let decode_map = HashMap<Rune, Rune>(
    [
        (r'\u{0000}', r'\u{0000}'), //  NULL
        (r'\u{0001}', r'\u{0001}'), //  START OF HEADING
        (r'\u{0002}', r'\u{0002}'), //  START OF TEXT
        (r'\u{0003}', r'\u{0003}'), //  END OF TEXT
        (r'\u{0004}', r'\u{0004}'), //  END OF TRANSMISSION
        (r'\u{0005}', r'\u{0005}'), //  ENQUIRY
        (r'\u{0006}', r'\u{0006}'), //  ACKNOWLEDGE
        (r'\u{0007}', r'\u{0007}'), //  BELL
        (r'\u{0008}', r'\u{0008}'), //  BACKSPACE
        (r'\u{0009}', r'\u{0009}'), //  HORIZONTAL TABULATION
        (r'\u{000a}', r'\u{000a}'), //  LINE FEED
        (r'\u{000b}', r'\u{000b}'), //  VERTICAL TABULATION
        (r'\u{000c}', r'\u{000c}'), //  FORM FEED
        (r'\u{000d}', r'\u{000d}'), //  CARRIAGE RETURN
        (r'\u{000e}', r'\u{000e}'), //  SHIFT OUT
        (r'\u{000f}', r'\u{000f}'), //  SHIFT IN
        (r'\u{0010}', r'\u{0010}'), //  DATA LINK ESCAPE
        (r'\u{0011}', r'\u{0011}'), //  DEVICE CONTROL ONE
        (r'\u{0012}', r'\u{0012}'), //  DEVICE CONTROL TWO
        (r'\u{0013}', r'\u{0013}'), //  DEVICE CONTROL THREE
        (r'\u{0014}', r'\u{0014}'), //  DEVICE CONTROL FOUR
        (r'\u{0015}', r'\u{0015}'), //  NEGATIVE ACKNOWLEDGE
        (r'\u{0016}', r'\u{0016}'), //  SYNCHRONOUS IDLE
        (r'\u{0017}', r'\u{0017}'), //  END OF TRANSMISSION BLOCK
        (r'\u{0018}', r'\u{0018}'), //  CANCEL
        (r'\u{0019}', r'\u{0019}'), //  END OF MEDIUM
        (r'\u{001a}', r'\u{001a}'), //  SUBSTITUTE
        (r'\u{001b}', r'\u{001b}'), //  ESCAPE
        (r'\u{001c}', r'\u{001c}'), //  FILE SEPARATOR
        (r'\u{001d}', r'\u{001d}'), //  GROUP SEPARATOR
        (r'\u{001e}', r'\u{001e}'), //  RECORD SEPARATOR
        (r'\u{001f}', r'\u{001f}'), //  UNIT SEPARATOR
        (r'\u{0020}', r'\u{0020}'), //  SPACE
        (r'\u{0021}', r'\u{0021}'), //  EXCLAMATION MARK
        (r'\u{0022}', r'\u{0022}'), //  QUOTATION MARK
        (r'\u{0023}', r'\u{0023}'), //  NUMBER SIGN
        (r'\u{0024}', r'\u{0024}'), //  DOLLAR SIGN
        (r'\u{0025}', r'\u{0025}'), //  PERCENT SIGN
        (r'\u{0026}', r'\u{0026}'), //  AMPERSAND
        (r'\u{0027}', r'\u{0027}'), //  APOSTROPHE
        (r'\u{0028}', r'\u{0028}'), //  LEFT PARENTHESIS
        (r'\u{0029}', r'\u{0029}'), //  RIGHT PARENTHESIS
        (r'\u{002a}', r'\u{002a}'), //  ASTERISK
        (r'\u{002b}', r'\u{002b}'), //  PLUS SIGN
        (r'\u{002c}', r'\u{002c}'), //  COMMA
        (r'\u{002d}', r'\u{002d}'), //  HYPHEN-MINUS
        (r'\u{002e}', r'\u{002e}'), //  FULL STOP
        (r'\u{002f}', r'\u{002f}'), //  SOLIDUS
        (r'\u{0030}', r'\u{0030}'), //  DIGIT ZERO
        (r'\u{0031}', r'\u{0031}'), //  DIGIT ONE
        (r'\u{0032}', r'\u{0032}'), //  DIGIT TWO
        (r'\u{0033}', r'\u{0033}'), //  DIGIT THREE
        (r'\u{0034}', r'\u{0034}'), //  DIGIT FOUR
        (r'\u{0035}', r'\u{0035}'), //  DIGIT FIVE
        (r'\u{0036}', r'\u{0036}'), //  DIGIT SIX
        (r'\u{0037}', r'\u{0037}'), //  DIGIT SEVEN
        (r'\u{0038}', r'\u{0038}'), //  DIGIT EIGHT
        (r'\u{0039}', r'\u{0039}'), //  DIGIT NINE
        (r'\u{003a}', r'\u{003a}'), //  COLON
        (r'\u{003b}', r'\u{003b}'), //  SEMICOLON
        (r'\u{003c}', r'\u{003c}'), //  LESS-THAN SIGN
        (r'\u{003d}', r'\u{003d}'), //  EQUALS SIGN
        (r'\u{003e}', r'\u{003e}'), //  GREATER-THAN SIGN
        (r'\u{003f}', r'\u{003f}'), //  QUESTION MARK
        (r'\u{0040}', r'\u{0040}'), //  COMMERCIAL AT
        (r'\u{0041}', r'\u{0041}'), //  LATIN CAPITAL LETTER A
        (r'\u{0042}', r'\u{0042}'), //  LATIN CAPITAL LETTER B
        (r'\u{0043}', r'\u{0043}'), //  LATIN CAPITAL LETTER C
        (r'\u{0044}', r'\u{0044}'), //  LATIN CAPITAL LETTER D
        (r'\u{0045}', r'\u{0045}'), //  LATIN CAPITAL LETTER E
        (r'\u{0046}', r'\u{0046}'), //  LATIN CAPITAL LETTER F
        (r'\u{0047}', r'\u{0047}'), //  LATIN CAPITAL LETTER G
        (r'\u{0048}', r'\u{0048}'), //  LATIN CAPITAL LETTER H
        (r'\u{0049}', r'\u{0049}'), //  LATIN CAPITAL LETTER I
        (r'\u{004a}', r'\u{004a}'), //  LATIN CAPITAL LETTER J
        (r'\u{004b}', r'\u{004b}'), //  LATIN CAPITAL LETTER K
        (r'\u{004c}', r'\u{004c}'), //  LATIN CAPITAL LETTER L
        (r'\u{004d}', r'\u{004d}'), //  LATIN CAPITAL LETTER M
        (r'\u{004e}', r'\u{004e}'), //  LATIN CAPITAL LETTER N
        (r'\u{004f}', r'\u{004f}'), //  LATIN CAPITAL LETTER O
        (r'\u{0050}', r'\u{0050}'), //  LATIN CAPITAL LETTER P
        (r'\u{0051}', r'\u{0051}'), //  LATIN CAPITAL LETTER Q
        (r'\u{0052}', r'\u{0052}'), //  LATIN CAPITAL LETTER R
        (r'\u{0053}', r'\u{0053}'), //  LATIN CAPITAL LETTER S
        (r'\u{0054}', r'\u{0054}'), //  LATIN CAPITAL LETTER T
        (r'\u{0055}', r'\u{0055}'), //  LATIN CAPITAL LETTER U
        (r'\u{0056}', r'\u{0056}'), //  LATIN CAPITAL LETTER V
        (r'\u{0057}', r'\u{0057}'), //  LATIN CAPITAL LETTER W
        (r'\u{0058}', r'\u{0058}'), //  LATIN CAPITAL LETTER X
        (r'\u{0059}', r'\u{0059}'), //  LATIN CAPITAL LETTER Y
        (r'\u{005a}', r'\u{005a}'), //  LATIN CAPITAL LETTER Z
        (r'\u{005b}', r'\u{005b}'), //  LEFT SQUARE BRACKET
        (r'\u{005c}', r'\u{005c}'), //  REVERSE SOLIDUS
        (r'\u{005d}', r'\u{005d}'), //  RIGHT SQUARE BRACKET
        (r'\u{005e}', r'\u{005e}'), //  CIRCUMFLEX ACCENT
        (r'\u{005f}', r'\u{005f}'), //  LOW LINE
        (r'\u{0060}', r'\u{0060}'), //  GRAVE ACCENT
        (r'\u{0061}', r'\u{0061}'), //  LATIN SMALL LETTER A
        (r'\u{0062}', r'\u{0062}'), //  LATIN SMALL LETTER B
        (r'\u{0063}', r'\u{0063}'), //  LATIN SMALL LETTER C
        (r'\u{0064}', r'\u{0064}'), //  LATIN SMALL LETTER D
        (r'\u{0065}', r'\u{0065}'), //  LATIN SMALL LETTER E
        (r'\u{0066}', r'\u{0066}'), //  LATIN SMALL LETTER F
        (r'\u{0067}', r'\u{0067}'), //  LATIN SMALL LETTER G
        (r'\u{0068}', r'\u{0068}'), //  LATIN SMALL LETTER H
        (r'\u{0069}', r'\u{0069}'), //  LATIN SMALL LETTER I
        (r'\u{006a}', r'\u{006a}'), //  LATIN SMALL LETTER J
        (r'\u{006b}', r'\u{006b}'), //  LATIN SMALL LETTER K
        (r'\u{006c}', r'\u{006c}'), //  LATIN SMALL LETTER L
        (r'\u{006d}', r'\u{006d}'), //  LATIN SMALL LETTER M
        (r'\u{006e}', r'\u{006e}'), //  LATIN SMALL LETTER N
        (r'\u{006f}', r'\u{006f}'), //  LATIN SMALL LETTER O
        (r'\u{0070}', r'\u{0070}'), //  LATIN SMALL LETTER P
        (r'\u{0071}', r'\u{0071}'), //  LATIN SMALL LETTER Q
        (r'\u{0072}', r'\u{0072}'), //  LATIN SMALL LETTER R
        (r'\u{0073}', r'\u{0073}'), //  LATIN SMALL LETTER S
        (r'\u{0074}', r'\u{0074}'), //  LATIN SMALL LETTER T
        (r'\u{0075}', r'\u{0075}'), //  LATIN SMALL LETTER U
        (r'\u{0076}', r'\u{0076}'), //  LATIN SMALL LETTER V
        (r'\u{0077}', r'\u{0077}'), //  LATIN SMALL LETTER W
        (r'\u{0078}', r'\u{0078}'), //  LATIN SMALL LETTER X
        (r'\u{0079}', r'\u{0079}'), //  LATIN SMALL LETTER Y
        (r'\u{007a}', r'\u{007a}'), //  LATIN SMALL LETTER Z
        (r'\u{007b}', r'\u{007b}'), //  LEFT CURLY BRACKET
        (r'\u{007c}', r'\u{007c}'), //  VERTICAL LINE
        (r'\u{007d}', r'\u{007d}'), //  RIGHT CURLY BRACKET
        (r'\u{007e}', r'\u{007e}'), //  TILDE
        (r'\u{007f}', r'\u{007f}'), //  DELETE
        (r'\u{00a0}', r'\u{00ff}'), //  NO-BREAK SPACE
        (r'\u{00a1}', r'\u{00ad}'), //  INVERTED EXCLAMATION MARK
        (r'\u{00a2}', r'\u{009b}'), //  CENT SIGN
        (r'\u{00a3}', r'\u{009c}'), //  POUND SIGN
        (r'\u{00a5}', r'\u{009d}'), //  YEN SIGN
        (r'\u{00aa}', r'\u{00a6}'), //  FEMININE ORDINAL INDICATOR
        (r'\u{00ab}', r'\u{00ae}'), //  LEFT-POINTING DOUBLE ANGLE QUOTATION MARK
        (r'\u{00ac}', r'\u{00aa}'), //  NOT SIGN
        (r'\u{00b0}', r'\u{00f8}'), //  DEGREE SIGN
        (r'\u{00b1}', r'\u{00f1}'), //  PLUS-MINUS SIGN
        (r'\u{00b2}', r'\u{00fd}'), //  SUPERSCRIPT TWO
        (r'\u{00b5}', r'\u{00e6}'), //  MICRO SIGN
        (r'\u{00b7}', r'\u{00fa}'), //  MIDDLE DOT
        (r'\u{00ba}', r'\u{00a7}'), //  MASCULINE ORDINAL INDICATOR
        (r'\u{00bb}', r'\u{00af}'), //  RIGHT-POINTING DOUBLE ANGLE QUOTATION MARK
        (r'\u{00bc}', r'\u{00ac}'), //  VULGAR FRACTION ONE QUARTER
        (r'\u{00bd}', r'\u{00ab}'), //  VULGAR FRACTION ONE HALF
        (r'\u{00bf}', r'\u{00a8}'), //  INVERTED QUESTION MARK
        (r'\u{00c4}', r'\u{008e}'), //  LATIN CAPITAL LETTER A WITH DIAERESIS
        (r'\u{00c5}', r'\u{008f}'), //  LATIN CAPITAL LETTER A WITH RING ABOVE
        (r'\u{00c6}', r'\u{0092}'), //  LATIN CAPITAL LIGATURE AE
        (r'\u{00c7}', r'\u{0080}'), //  LATIN CAPITAL LETTER C WITH CEDILLA
        (r'\u{00c9}', r'\u{0090}'), //  LATIN CAPITAL LETTER E WITH ACUTE
        (r'\u{00d1}', r'\u{00a5}'), //  LATIN CAPITAL LETTER N WITH TILDE
        (r'\u{00d6}', r'\u{0099}'), //  LATIN CAPITAL LETTER O WITH DIAERESIS
        (r'\u{00dc}', r'\u{009a}'), //  LATIN CAPITAL LETTER U WITH DIAERESIS
        (r'\u{00df}', r'\u{00e1}'), //  LATIN SMALL LETTER SHARP S
        (r'\u{00e0}', r'\u{0085}'), //  LATIN SMALL LETTER A WITH GRAVE
        (r'\u{00e1}', r'\u{00a0}'), //  LATIN SMALL LETTER A WITH ACUTE
        (r'\u{00e2}', r'\u{0083}'), //  LATIN SMALL LETTER A WITH CIRCUMFLEX
        (r'\u{00e4}', r'\u{0084}'), //  LATIN SMALL LETTER A WITH DIAERESIS
        (r'\u{00e5}', r'\u{0086}'), //  LATIN SMALL LETTER A WITH RING ABOVE
        (r'\u{00e6}', r'\u{0091}'), //  LATIN SMALL LIGATURE AE
        (r'\u{00e7}', r'\u{0087}'), //  LATIN SMALL LETTER C WITH CEDILLA
        (r'\u{00e8}', r'\u{008a}'), //  LATIN SMALL LETTER E WITH GRAVE
        (r'\u{00e9}', r'\u{0082}'), //  LATIN SMALL LETTER E WITH ACUTE
        (r'\u{00ea}', r'\u{0088}'), //  LATIN SMALL LETTER E WITH CIRCUMFLEX
        (r'\u{00eb}', r'\u{0089}'), //  LATIN SMALL LETTER E WITH DIAERESIS
        (r'\u{00ec}', r'\u{008d}'), //  LATIN SMALL LETTER I WITH GRAVE
        (r'\u{00ed}', r'\u{00a1}'), //  LATIN SMALL LETTER I WITH ACUTE
        (r'\u{00ee}', r'\u{008c}'), //  LATIN SMALL LETTER I WITH CIRCUMFLEX
        (r'\u{00ef}', r'\u{008b}'), //  LATIN SMALL LETTER I WITH DIAERESIS
        (r'\u{00f1}', r'\u{00a4}'), //  LATIN SMALL LETTER N WITH TILDE
        (r'\u{00f2}', r'\u{0095}'), //  LATIN SMALL LETTER O WITH GRAVE
        (r'\u{00f3}', r'\u{00a2}'), //  LATIN SMALL LETTER O WITH ACUTE
        (r'\u{00f4}', r'\u{0093}'), //  LATIN SMALL LETTER O WITH CIRCUMFLEX
        (r'\u{00f6}', r'\u{0094}'), //  LATIN SMALL LETTER O WITH DIAERESIS
        (r'\u{00f7}', r'\u{00f6}'), //  DIVISION SIGN
        (r'\u{00f9}', r'\u{0097}'), //  LATIN SMALL LETTER U WITH GRAVE
        (r'\u{00fa}', r'\u{00a3}'), //  LATIN SMALL LETTER U WITH ACUTE
        (r'\u{00fb}', r'\u{0096}'), //  LATIN SMALL LETTER U WITH CIRCUMFLEX
        (r'\u{00fc}', r'\u{0081}'), //  LATIN SMALL LETTER U WITH DIAERESIS
        (r'\u{00ff}', r'\u{0098}'), //  LATIN SMALL LETTER Y WITH DIAERESIS
        (r'\u{0192}', r'\u{009f}'), //  LATIN SMALL LETTER F WITH HOOK
        (r'\u{0393}', r'\u{00e2}'), //  GREEK CAPITAL LETTER GAMMA
        (r'\u{0398}', r'\u{00e9}'), //  GREEK CAPITAL LETTER THETA
        (r'\u{03a3}', r'\u{00e4}'), //  GREEK CAPITAL LETTER SIGMA
        (r'\u{03a6}', r'\u{00e8}'), //  GREEK CAPITAL LETTER PHI
        (r'\u{03a9}', r'\u{00ea}'), //  GREEK CAPITAL LETTER OMEGA
        (r'\u{03b1}', r'\u{00e0}'), //  GREEK SMALL LETTER ALPHA
        (r'\u{03b4}', r'\u{00eb}'), //  GREEK SMALL LETTER DELTA
        (r'\u{03b5}', r'\u{00ee}'), //  GREEK SMALL LETTER EPSILON
        (r'\u{03c0}', r'\u{00e3}'), //  GREEK SMALL LETTER PI
        (r'\u{03c3}', r'\u{00e5}'), //  GREEK SMALL LETTER SIGMA
        (r'\u{03c4}', r'\u{00e7}'), //  GREEK SMALL LETTER TAU
        (r'\u{03c6}', r'\u{00ed}'), //  GREEK SMALL LETTER PHI
        (r'\u{207f}', r'\u{00fc}'), //  SUPERSCRIPT LATIN SMALL LETTER N
        (r'\u{20a7}', r'\u{009e}'), //  PESETA SIGN
        (r'\u{2219}', r'\u{00f9}'), //  BULLET OPERATOR
        (r'\u{221a}', r'\u{00fb}'), //  SQUARE ROOT
        (r'\u{221e}', r'\u{00ec}'), //  INFINITY
        (r'\u{2229}', r'\u{00ef}'), //  INTERSECTION
        (r'\u{2248}', r'\u{00f7}'), //  ALMOST EQUAL TO
        (r'\u{2261}', r'\u{00f0}'), //  IDENTICAL TO
        (r'\u{2264}', r'\u{00f3}'), //  LESS-THAN OR EQUAL TO
        (r'\u{2265}', r'\u{00f2}'), //  GREATER-THAN OR EQUAL TO
        (r'\u{2310}', r'\u{00a9}'), //  REVERSED NOT SIGN
        (r'\u{2320}', r'\u{00f4}'), //  TOP HALF INTEGRAL
        (r'\u{2321}', r'\u{00f5}'), //  BOTTOM HALF INTEGRAL
        (r'\u{2500}', r'\u{00c4}'), //  BOX DRAWINGS LIGHT HORIZONTAL
        (r'\u{2502}', r'\u{00b3}'), //  BOX DRAWINGS LIGHT VERTICAL
        (r'\u{250c}', r'\u{00da}'), //  BOX DRAWINGS LIGHT DOWN AND RIGHT
        (r'\u{2510}', r'\u{00bf}'), //  BOX DRAWINGS LIGHT DOWN AND LEFT
        (r'\u{2514}', r'\u{00c0}'), //  BOX DRAWINGS LIGHT UP AND RIGHT
        (r'\u{2518}', r'\u{00d9}'), //  BOX DRAWINGS LIGHT UP AND LEFT
        (r'\u{251c}', r'\u{00c3}'), //  BOX DRAWINGS LIGHT VERTICAL AND RIGHT
        (r'\u{2524}', r'\u{00b4}'), //  BOX DRAWINGS LIGHT VERTICAL AND LEFT
        (r'\u{252c}', r'\u{00c2}'), //  BOX DRAWINGS LIGHT DOWN AND HORIZONTAL
        (r'\u{2534}', r'\u{00c1}'), //  BOX DRAWINGS LIGHT UP AND HORIZONTAL
        (r'\u{253c}', r'\u{00c5}'), //  BOX DRAWINGS LIGHT VERTICAL AND HORIZONTAL
        (r'\u{2550}', r'\u{00cd}'), //  BOX DRAWINGS DOUBLE HORIZONTAL
        (r'\u{2551}', r'\u{00ba}'), //  BOX DRAWINGS DOUBLE VERTICAL
        (r'\u{2552}', r'\u{00d5}'), //  BOX DRAWINGS DOWN SINGLE AND RIGHT DOUBLE
        (r'\u{2553}', r'\u{00d6}'), //  BOX DRAWINGS DOWN DOUBLE AND RIGHT SINGLE
        (r'\u{2554}', r'\u{00c9}'), //  BOX DRAWINGS DOUBLE DOWN AND RIGHT
        (r'\u{2555}', r'\u{00b8}'), //  BOX DRAWINGS DOWN SINGLE AND LEFT DOUBLE
        (r'\u{2556}', r'\u{00b7}'), //  BOX DRAWINGS DOWN DOUBLE AND LEFT SINGLE
        (r'\u{2557}', r'\u{00bb}'), //  BOX DRAWINGS DOUBLE DOWN AND LEFT
        (r'\u{2558}', r'\u{00d4}'), //  BOX DRAWINGS UP SINGLE AND RIGHT DOUBLE
        (r'\u{2559}', r'\u{00d3}'), //  BOX DRAWINGS UP DOUBLE AND RIGHT SINGLE
        (r'\u{255a}', r'\u{00c8}'), //  BOX DRAWINGS DOUBLE UP AND RIGHT
        (r'\u{255b}', r'\u{00be}'), //  BOX DRAWINGS UP SINGLE AND LEFT DOUBLE
        (r'\u{255c}', r'\u{00bd}'), //  BOX DRAWINGS UP DOUBLE AND LEFT SINGLE
        (r'\u{255d}', r'\u{00bc}'), //  BOX DRAWINGS DOUBLE UP AND LEFT
        (r'\u{255e}', r'\u{00c6}'), //  BOX DRAWINGS VERTICAL SINGLE AND RIGHT DOUBLE
        (r'\u{255f}', r'\u{00c7}'), //  BOX DRAWINGS VERTICAL DOUBLE AND RIGHT SINGLE
        (r'\u{2560}', r'\u{00cc}'), //  BOX DRAWINGS DOUBLE VERTICAL AND RIGHT
        (r'\u{2561}', r'\u{00b5}'), //  BOX DRAWINGS VERTICAL SINGLE AND LEFT DOUBLE
        (r'\u{2562}', r'\u{00b6}'), //  BOX DRAWINGS VERTICAL DOUBLE AND LEFT SINGLE
        (r'\u{2563}', r'\u{00b9}'), //  BOX DRAWINGS DOUBLE VERTICAL AND LEFT
        (r'\u{2564}', r'\u{00d1}'), //  BOX DRAWINGS DOWN SINGLE AND HORIZONTAL DOUBLE
        (r'\u{2565}', r'\u{00d2}'), //  BOX DRAWINGS DOWN DOUBLE AND HORIZONTAL SINGLE
        (r'\u{2566}', r'\u{00cb}'), //  BOX DRAWINGS DOUBLE DOWN AND HORIZONTAL
        (r'\u{2567}', r'\u{00cf}'), //  BOX DRAWINGS UP SINGLE AND HORIZONTAL DOUBLE
        (r'\u{2568}', r'\u{00d0}'), //  BOX DRAWINGS UP DOUBLE AND HORIZONTAL SINGLE
        (r'\u{2569}', r'\u{00ca}'), //  BOX DRAWINGS DOUBLE UP AND HORIZONTAL
        (r'\u{256a}', r'\u{00d8}'), //  BOX DRAWINGS VERTICAL SINGLE AND HORIZONTAL DOUBLE
        (r'\u{256b}', r'\u{00d7}'), //  BOX DRAWINGS VERTICAL DOUBLE AND HORIZONTAL SINGLE
        (r'\u{256c}', r'\u{00ce}'), //  BOX DRAWINGS DOUBLE VERTICAL AND HORIZONTAL
        (r'\u{2580}', r'\u{00df}'), //  UPPER HALF BLOCK
        (r'\u{2584}', r'\u{00dc}'), //  LOWER HALF BLOCK
        (r'\u{2588}', r'\u{00db}'), //  FULL BLOCK
        (r'\u{258c}', r'\u{00dd}'), //  LEFT HALF BLOCK
        (r'\u{2590}', r'\u{00de}'), //  RIGHT HALF BLOCK
        (r'\u{2591}', r'\u{00b0}'), //  LIGHT SHADE
        (r'\u{2592}', r'\u{00b1}'), //  MEDIUM SHADE
        (r'\u{2593}', r'\u{00b2}'), //  DARK SHADE
        (r'\u{25a0}', r'\u{00fe}') //  BLACK SQUARE
    ]
)

public func decodeCp437(arr: Array<Byte>): String {
    var sb = StringBuilder()
    for (i in 0..arr.size) {
        let a = arr[i]
        if (a <= 127) {
            sb.append(encode_arr[Int64(a)])
        } else if (encode_map.contains(Int64(a))) {
            sb.append(encode_map[Int64(a)])
        } else {
            throw ZipException("Cannot convert.")
        }
    }
    return sb.toString()
}

public func encodeCp437(str: String): Array<Byte> {
    let runs = str.toRuneArray()
    let ll = Array<Byte>(runs.size, repeat: 0)
    for (i in 0..runs.size) {
        ll[i] = UInt8(UInt32(decode_map[runs[i]]))
    }
    ll
}
