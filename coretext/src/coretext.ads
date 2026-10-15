--  Ada-style interface to CoreText (macOS only): fonts, lines of text
--  set in them, line breaking and rasterization into RGBA bitmaps.
--  The C bindings are hidden in CoreText.Thin.
--
--  Strings are UTF-8 Ada Strings. CoreText indexes text in UTF-16 code
--  units, and every index in this crate is one; UTF16_Length converts a
--  string's length.
package CoreText is

   Error : exception;
   --  A CoreText or CoreGraphics call failed.

   function UTF16_Length (Text : String) return Natural;
   --  How many UTF-16 code units the UTF-8 Text takes, as Sanitized (Text)
   --  would: a byte that is not well-formed UTF-8 is one.

   function Is_Clean (Text : String) return Boolean;
   --  Whether Text is well-formed UTF-8 with no byte order mark.

   function Sanitized (Text : String) return String
     with Post => Sanitized'Result'Length = Text'Length
                  and then Sanitized'Result'First = 1
                  and then Is_Clean (Sanitized'Result);
   --  Text made safe for CoreFoundation, byte for byte: each byte that is
   --  not part of well-formed UTF-8 (a stray or truncated byte, an overlong
   --  form, a surrogate, a code point past U+10FFFF) becomes "?", and each
   --  U+FEFF (which CoreFoundation drops from the start of a string it
   --  decodes, so its UTF-16 units would not match) becomes U+2060, a word
   --  joiner: as wide in bytes and units, and as unseen.

end CoreText;
