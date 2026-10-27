with Ada.Containers.Hashed_Maps;
with Interfaces;
with SDL3.Painters;
with Ada.Strings.Unbounded;
with CoreText.Fonts;
with CoreText.Shaping;
with CoreText.Strings;
with SDL3.Windows.Renderers;
with Typeset.Glyph_Atlas;

--  Single lines of text, such as labels and buttons have, in the system's
--  user interface font, shared by the widgets of a window: they are
--  shaped, and drawn from a glyph atlas, as a document's text is.
--
--  Declare it after the renderer it draws to, and always draw it to that
--  renderer.

package Pomarine.Line_Texts is

   Interface_Font   : constant String := ".AppleSystemUIFont";
   Interface_Medium : constant String := ".AppleSystemUIFontMedium";
   Interface_Bold   : constant String := ".AppleSystemUIFontBold";
   --  The system's user interface font, in its weights: CoreText's names
   --  for them, as the interface of macOS draws.

   Serif : constant String := "Georgia";
   --  Georgia, a serif that ships with macOS: the face of what is written
   --  and read, and of the display type of a screen.

   type Style is (Regular, Strong, Heading, Display, Caption, Serif_Label, Serif_Bold, Serif_Italic);
   --  Regular is the size of the text of a window, in the regular weight;
   --  Strong is the same size, and heavier, as of buttons; Heading is
   --  larger, and heavier still; Display is larger again, in the serif, as
   --  the title of a screen; Caption is small and heavy, as the name of a
   --  list.

   Regular_Size : constant := 13.0;
   Heading_Size : constant := 16.0;
   Display_Size : constant := 30.0;
   Caption_Size : constant := 11.0;
   --  In points.

   function Size (Of_Style : Style) return Float
   is (case Of_Style is
         when Regular | Strong | Serif_Label | Serif_Bold | Serif_Italic => Regular_Size,
         when Heading                                                    => Heading_Size,
         when Display                                                    => Display_Size,
         when Caption                                                    => Caption_Size);

   function Face_Name (Of_Style : Style) return String
   is (case Of_Style is
         when Regular               => Interface_Font,
         when Strong | Caption      => Interface_Medium,
         when Heading               => Interface_Bold,
         when Display | Serif_Label => Serif,
         when Serif_Bold            => "Georgia-Bold",
         when Serif_Italic          => "Georgia-Italic");

   type Drawer is limited private;

   procedure Begin_Frame (Item : in out Drawer);
   --  Call before drawing a frame, as Typeset.Glyph_Atlas.Begin_Frame.

   function Width
     (Item : in out Drawer; Text : String; Scale : Float; Using : Style := Regular; Face : String := "") return Float
   with Pre => Scale > 0.0;
   --  Of Text in pixels, at Scale pixels to a point. If Face is not empty
   --  it is the font (a PostScript or family name) it is in, at the size
   --  of Using, in place of Using's own.

   function Height (Item : in out Drawer; Scale : Float; Using : Style := Regular) return Float
   with Pre => Scale > 0.0;
   --  Of a line of text in pixels, at Scale pixels to a point: the font's
   --  ascent, descent and leading.

   function Fitted
     (Item : in out Drawer; Text : String; Room : Float; Scale : Float; Using : Style := Regular; Face : String := "")
      return String
   with Pre => Scale > 0.0;
   --  Text, or as much of its start as fits Room pixels with an ellipsis
   --  after it, cut where a character begins. All of it if Room is not
   --  positive.

   procedure Draw
     (Item   : in out Drawer;
      Target : SDL3.Painters.Painter'Class;
      Value  : SDL3.Windows.Renderers.Color;
      Text   : String;
      Left   : Float;
      Middle : Float;
      Scale  : Float;
      Using  : Style := Regular;
      Face   : String := "")
   with Pre => Scale > 0.0;
   --  Draw Text, in Face if it is not empty as Width says, with its start Left pixels, and the middle of its height
   --  Middle pixels, from the top left of the target. It is drawn at
   --  once, so that what is drawn after is over it.

   procedure Draw_Character
     (Item     : in out Drawer;
      Target   : SDL3.Painters.Painter'Class;
      Value    : SDL3.Windows.Renderers.Color;
      Face     : String;
      Code     : Interfaces.Unsigned_32;
      X        : Float;
      Baseline : Float;
      Pixels   : Float;
      Settled  : Boolean := True)
   with Pre => Pixels > 0.0 and then Face'Length > 0;
   --  Batch one character of the font named Face (a PostScript or family
   --  name), its baseline start X pixels from the target's left and
   --  Baseline from its top, Pixels tall as the font's size. For text
   --  that is set elsewhere, character by character, as a page of a
   --  document is. A character the font has not is drawn as another font
   --  has it, if one does. Flush to have them drawn: they are batched,
   --  so that anything drawn after them but before the Flush is under
   --  them. While the size changes, as when zooming, Settled is False.

   procedure Flush (Item : in out Drawer; Target : SDL3.Painters.Painter'Class);
   --  Draw the characters batched.

private

   type Face_Array is array (Style) of CoreText.Fonts.Font;

   Character_Faces : constant := 64;
   --  How many fonts of the text of pages are kept open; when they are
   --  all in use the first is closed for the next.

   Face_Size : constant := 64.0;
   --  The size they are opened at (glyphs are rasterized at the size
   --  they are drawn).

   type Open_Face is record
      Name : Ada.Strings.Unbounded.Unbounded_String;
      Font : CoreText.Fonts.Font;
   end record;

   type Open_Face_Array is array (1 .. Character_Faces) of Open_Face;

   use type Interfaces.Unsigned_64;

   function Glyph_Hash (Key : Interfaces.Unsigned_64) return Ada.Containers.Hash_Type
   is (Ada.Containers.Hash_Type ((Key xor Interfaces.Shift_Right (Key, 32)) and 16#FFFF_FFFF#));

   package Glyph_Maps is new
     Ada.Containers.Hashed_Maps
       (Interfaces.Unsigned_64,
        CoreText.Shaping.Glyph,
        Glyph_Hash,
        Interfaces."=",
        CoreText.Shaping."=");
   --  Which glyph is a character in a face, keyed by the face's number
   --  (shifted up by 32 bits) and the character.

   Cache_Size : constant := 64;
   --  How many lines are kept shaped: more than a screen has.

   Named_Faces : constant := 128;
   --  How many fonts, by name, are kept open for lines in a face of
   --  their own; when they are all in use the first is closed for the
   --  next, and the lines shaped in them are forgotten.

   type Named_Face_Array is array (1 .. Named_Faces) of Open_Face;

   type Cached_Line is record
      Used  : Boolean := False;
      Using : Style := Regular;
      Face  : Ada.Strings.Unbounded.Unbounded_String;
      Text  : Ada.Strings.Unbounded.Unbounded_String;
      Line  : CoreText.Shaping.Shaped;
   end record;

   type Cache_Array is array (1 .. Cache_Size) of Cached_Line;

   type Drawer is limited record
      Reg         : CoreText.Shaping.Registry;
      Atlas       : Typeset.Glyph_Atlas.Atlas;
      Faces       : Face_Array;
      Source      : CoreText.Strings.Text;
      Cache       : Cache_Array;
      Next        : Positive range 1 .. Cache_Size := 1;
      --  The line to replace when one is not there.
      Opened      : Open_Face_Array;
      Opens       : Natural range 0 .. Character_Faces := 0;
      Turn        : Positive range 1 .. Character_Faces := 1;
      --  The face to close when none is free.
      Glyphs      : Glyph_Maps.Map;
      Named       : Named_Face_Array;
      Named_Opens : Natural range 0 .. Named_Faces := 0;
      Named_Turn  : Positive range 1 .. Named_Faces := 1;
   end record;

end Pomarine.Line_Texts;
