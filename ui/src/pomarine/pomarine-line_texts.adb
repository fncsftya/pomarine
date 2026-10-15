package body Pomarine.Line_Texts is

   function Shape
     (Item : in out Drawer; Text : String; Using : Style) return Positive;
   --  Which of Item.Cache is Text shaped in Using, opening the font and
   --  shaping it if it is not there. A line is shaped again each time it
   --  is drawn otherwise: labels and buttons are drawn, and measured,
   --  every time what is behind them is.

   function Shape
     (Item : in out Drawer; Text : String; Using : Style) return Positive
   is
      use Ada.Strings.Unbounded;
   begin
      for Entry_Of in Item.Cache'Range loop
         if Item.Cache (Entry_Of).Used
           and then Item.Cache (Entry_Of).Using = Using
           and then Item.Cache (Entry_Of).Text = Text
         then
            return Entry_Of;
         end if;
      end loop;

      if not CoreText.Fonts.Is_Open (Item.Faces (Using)) then
         CoreText.Fonts.Open
           (Item.Faces (Using), Face_Name (Using), Size (Using));
      end if;
      CoreText.Strings.Set (Item.Source, Text);
      declare
         Slot : constant Positive := Item.Next;
      begin
         CoreText.Shaping.Shape
           (Item.Reg, Item.Faces (Using), Item.Source, 0,
            CoreText.Strings.Length (Item.Source), Item.Cache (Slot).Line);
         Item.Cache (Slot).Used := True;
         Item.Cache (Slot).Using := Using;
         Item.Cache (Slot).Text := To_Unbounded_String (Text);
         Item.Next := (if Slot = Cache_Size then 1 else Slot + 1);
         return Slot;
      end;
   end Shape;

   function UTF_8 (Code : Interfaces.Unsigned_32) return String;
   --  The character as UTF-8: a replacement character if it is not one.

   function UTF_8 (Code : Interfaces.Unsigned_32) return String is
      use type Interfaces.Unsigned_32;
      use Interfaces;
      C : constant Unsigned_32 :=
        (if Code > 16#10FFFF# or else Code in 16#D800# .. 16#DFFF#
         then 16#FFFD# else Code);
      function B (Value : Unsigned_32) return Character is
        (Character'Val (Natural (Value)));
   begin
      if C < 16#80# then
         return [B (C)];
      elsif C < 16#800# then
         return [B (16#C0# or Shift_Right (C, 6)), B (16#80# or (C and 16#3F#))];
      elsif C < 16#10000# then
         return [B (16#E0# or Shift_Right (C, 12)),
                 B (16#80# or (Shift_Right (C, 6) and 16#3F#)),
                 B (16#80# or (C and 16#3F#))];
      else
         return [B (16#F0# or Shift_Right (C, 18)),
                 B (16#80# or (Shift_Right (C, 12) and 16#3F#)),
                 B (16#80# or (Shift_Right (C, 6) and 16#3F#)),
                 B (16#80# or (C and 16#3F#))];
      end if;
   end UTF_8;

   function Face_Number (Item : in out Drawer; Name : String) return Positive;
   --  Which of Item.Opened is the font Name, opening it if it is not.

   function Face_Number (Item : in out Drawer; Name : String) return Positive is
      use Ada.Strings.Unbounded;
   begin
      for Each in 1 .. Item.Opens loop
         if Item.Opened (Each).Name = Name then
            return Each;
         end if;
      end loop;
      declare
         Slot : Positive;
      begin
         if Item.Opens < Character_Faces then
            Item.Opens := Item.Opens + 1;
            Slot := Item.Opens;
         else
            Slot := Item.Turn;
            Item.Turn := (if Slot = Character_Faces then 1 else Slot + 1);
            --  Its glyphs are known by its number: forget them all.
            Item.Glyphs.Clear;
         end if;
         Item.Opened (Slot).Name := To_Unbounded_String (Name);
         CoreText.Fonts.Open (Item.Opened (Slot).Font, Name, Face_Size);
         return Slot;
      end;
   end Face_Number;

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
   is
      use Interfaces;
      use type Glyph_Maps.Cursor;
      Which : constant Positive := Face_Number (Item, Face);
      Key   : constant Unsigned_64 :=
        Shift_Left (Unsigned_64 (Which), 32) or Unsigned_64 (Code);
      Found : constant Glyph_Maps.Cursor := Item.Glyphs.Find (Key);
      Glyph : CoreText.Shaping.Glyph;
   begin
      if Found /= Glyph_Maps.No_Element then
         Glyph := Glyph_Maps.Element (Found);
      else
         declare
            Line : CoreText.Shaping.Shaped;
         begin
            CoreText.Strings.Set (Item.Source, UTF_8 (Code));
            CoreText.Shaping.Shape
              (Item.Reg, Item.Opened (Which).Font, Item.Source, 0,
               CoreText.Strings.Length (Item.Source), Line);
            if Line.Glyphs.Is_Empty then
               return;
            end if;
            Glyph := Line.Glyphs.First_Element;
            Glyph.X := 0.0;
            Item.Glyphs.Insert (Key, Glyph);
         end;
      end if;
      Typeset.Glyph_Atlas.Draw
        (Item.Atlas, Item.Reg, Target,
         Line => CoreText.Shaping.Glyph_Array'[1 => Glyph],
         X => X, Baseline => Baseline, Scale => 1.0, Size => Pixels,
         Value => Value, Settled => Settled);
   end Draw_Character;

   procedure Flush
     (Item   : in out Drawer;
      Target : SDL3.Painters.Painter'Class) is
   begin
      Typeset.Glyph_Atlas.Flush (Item.Atlas, Target);
   end Flush;

   procedure Begin_Frame (Item : in out Drawer) is
   begin
      Typeset.Glyph_Atlas.Begin_Frame (Item.Atlas);
   end Begin_Frame;

   function Width
     (Item  : in out Drawer;
      Text  : String;
      Scale : Float;
      Using : Style := Regular) return Float is
   begin
      declare
         Which : constant Positive := Shape (Item, Text, Using);
      begin
         return Item.Cache (Which).Line.Width * Scale;
      end;
   end Width;

   function Height
     (Item  : in out Drawer;
      Scale : Float;
      Using : Style := Regular) return Float is
   begin
      if not CoreText.Fonts.Is_Open (Item.Faces (Using)) then
         CoreText.Fonts.Open (Item.Faces (Using), Face_Name (Using), Size (Using));
      end if;
      return CoreText.Fonts.Line_Height (Item.Faces (Using)) * Scale;
   end Height;

   procedure Draw
     (Item   : in out Drawer;
      Target : SDL3.Painters.Painter'Class;
      Value  : SDL3.Windows.Renderers.Color;
      Text   : String;
      Left   : Float;
      Middle : Float;
      Scale  : Float;
      Using  : Style := Regular) is
   begin
      declare
         Which   : constant Positive := Shape (Item, Text, Using);
         Face    : CoreText.Fonts.Font renames Item.Faces (Using);
         Ascent  : constant Float := CoreText.Fonts.Ascent (Face);
         Descent : constant Float := CoreText.Fonts.Descent (Face);
      begin
         Typeset.Glyph_Atlas.Draw
           (Item.Atlas, Item.Reg, Target, Item.Cache (Which).Line,
            X => Float'Rounding (Left),
            Baseline => Float'Rounding
              (Middle + (Ascent - Descent) / 2.0 * Scale),
            Scale => Scale, Size => Size (Using) * Scale,
            Value => Value, Settled => True);
      end;
      Typeset.Glyph_Atlas.Flush (Item.Atlas, Target);
   end Draw;

end Pomarine.Line_Texts;
