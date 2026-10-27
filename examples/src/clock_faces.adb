with Ada.Calendar.Formatting;
with Ada.Calendar.Time_Zones;
with Ada.Numerics;
with Ada.Numerics.Elementary_Functions;
with Ada.Strings.Fixed;
with Pomarine.Line_Texts;

package body Clock_Faces is
   package Themes renames Pomarine.Themes;
   package Painters renames SDL3.Painters;
   package Semantics renames Pomarine.Semantics;

   use type Semantics.Role;

   Frame : constant := 33;
   --  Milliseconds between looks at the clock: about 30 a second.

   Two_Pi : constant Float := 2.0 * Ada.Numerics.Pi;

   function Hours (Item : Face) return Natural
   is (Item.Hour);
   function Minutes (Item : Face) return Natural
   is (Item.Minute);
   function Seconds (Item : Face) return Natural
   is (Item.Second);

   procedure Set_Time (Item : in out Face; Hour, Minute, Second : Natural; Fraction : Float := 0.0) is
   begin
      if Hour /= Item.Hour or else Minute /= Item.Minute or else Second /= Item.Second or else Fraction /= Item.Fraction
      then
         Item.Hour := Hour;
         Item.Minute := Minute;
         Item.Second := Second;
         Item.Fraction := Fraction;
         if Pomarine.Widgets.Is_Attached (Item) then
            Pomarine.Widgets.Invalidate (Item);
         end if;
      end if;
   end Set_Time;

   overriding
   procedure Update (Item : in out Face; Now : Pomarine.Events.Milliseconds) is
      pragma Unreferenced (Now);
      use Ada.Calendar;
      Here : constant Time := Clock;
      Zone : constant Time_Zones.Time_Offset := Time_Zones.UTC_Time_Offset (Here);
      --  The formatting functions give UTC unless told the zone.
   begin
      Set_Time
        (Item,
         Hour     => Formatting.Hour (Here, Zone),
         Minute   => Formatting.Minute (Here, Zone),
         Second   => Formatting.Second (Here),
         Fraction => Float (Formatting.Sub_Second (Here)));
   end Update;

   overriding
   function Until_Update (Item : Face) return Integer
   is (Frame);

   --  A turn of 0.0 is twelve o'clock, 0.25 three. Screen y grows downwards.
   function Across (Centre, Radius, Turn : Float) return Float
   is (Centre + Radius * Ada.Numerics.Elementary_Functions.Sin (Turn * Two_Pi));

   function Down (Centre, Radius, Turn : Float) return Float
   is (Centre - Radius * Ada.Numerics.Elementary_Functions.Cos (Turn * Two_Pi));

   overriding
   procedure Draw (Item : in out Face; Target : Painters.Painter'Class; Colors : Themes.Theme) is
      Ink   : constant Themes.Color := Colors (Themes.Foreground);
      Paper : constant Themes.Color := Colors (Themes.Page);
      Edge  : constant Themes.Color := Colors (Themes.Border);
      Faint : constant Themes.Color := Themes.Mix (Paper, Ink, 0.45);
      Red   : constant Themes.Color := Colors (Themes.Danger);

      X      : constant Float := Pomarine.Widgets.Left_Of (Item) + Pomarine.Widgets.Width_Of (Item) / 2.0;
      Y      : constant Float := Pomarine.Widgets.Top_Of (Item) + Pomarine.Widgets.Height_Of (Item) / 2.0;
      Radius : constant Float :=
        Float'Max (8.0, Float'Min (Pomarine.Widgets.Width_Of (Item), Pomarine.Widgets.Height_Of (Item)) / 2.0 - 8.0);
      Unit   : constant Float := Radius / 100.0;
      --  The drawing is made for a radius of 100 and scaled by this.

      Second : constant Float := Float (Item.Second) + Item.Fraction;
      Minute : constant Float := Float (Item.Minute) + Second / 60.0;
      Hour   : constant Float := Float (Item.Hour mod 12) + Minute / 60.0;

      procedure Hand (Colour : Themes.Color; Turn, Reach, Tail, Thick : Float) is
      begin
         Painters.Draw_Line
           (Target,
            Colour,
            Across (X, -Tail * Unit, Turn),
            Down (Y, -Tail * Unit, Turn),
            Across (X, Reach * Unit, Turn),
            Down (Y, Reach * Unit, Turn),
            Width => Float'Max (1.0, Thick * Unit));
      end Hand;
   begin
      --  The case, a shadow under it, the rim and the dial.
      Painters.Fill_Circle
        (Target, Themes.Mix (Colors (Themes.Background), (0, 0, 0, 255), 0.15), X + 3.0 * Unit, Y + 4.0 * Unit, Radius);
      Painters.Fill_Circle (Target, Edge, X, Y, Radius);
      Painters.Fill_Circle (Target, Ink, X, Y, Radius - 2.0 * Unit);
      Painters.Fill_Circle (Target, Paper, X, Y, Radius - 6.0 * Unit);

      --  Sixty ticks, longer and thicker at the hours; numerals inside them.
      for Mark in 0 .. 59 loop
         declare
            Turn      : constant Float := Float (Mark) / 60.0;
            Hour_Mark : constant Boolean := Mark mod 5 = 0;
            Outer     : constant Float := 90.0;
            Inner     : constant Float := (if Hour_Mark then 78.0 else 85.0);
         begin
            Painters.Draw_Line
              (Target,
               (if Hour_Mark then Ink else Faint),
               Across (X, Inner * Unit, Turn),
               Down (Y, Inner * Unit, Turn),
               Across (X, Outer * Unit, Turn),
               Down (Y, Outer * Unit, Turn),
               Width => Float'Max (1.0, (if Hour_Mark then 3.0 else 1.0) * Unit));
         end;
      end loop;

      for Number in 1 .. 12 loop
         declare
            Text  : constant String := Ada.Strings.Fixed.Trim (Integer'Image (Number), Ada.Strings.Left);
            Size  : constant Float := Radius * 0.17 / Pomarine.Line_Texts.Display_Size;
            --  Pixels to a point, to make the numerals a sixth of the radius high.
            Turn  : constant Float := Float (Number) / 12.0;
            Lines : Pomarine.Line_Texts.Drawer renames Pomarine.Widgets.Text_Lines (Item).all;
         begin
            Pomarine.Line_Texts.Draw
              (Lines,
               Target,
               Ink,
               Text,
               Across (X, 63.0 * Unit, Turn)
               - Pomarine.Line_Texts.Width (Lines, Text, Size, Pomarine.Line_Texts.Display) / 2.0,
               Down (Y, 63.0 * Unit, Turn),
               Size,
               Pomarine.Line_Texts.Display);
         end;
      end loop;

      --  Hands: hour, minute, then the second hand over them, and the pin.
      Hand (Ink, Hour / 12.0, 48.0, 8.0, 6.0);
      Hand (Ink, Minute / 60.0, 72.0, 10.0, 4.0);
      Hand (Red, Second / 60.0, 80.0, 18.0, 1.5);
      Painters.Fill_Circle (Target, Red, X, Y, 5.0 * Unit);
      Painters.Fill_Circle (Target, Paper, X, Y, 2.0 * Unit);
   end Draw;

   function Two (Value : Natural) return String
   is ((if Value < 10 then "0" else "") & Ada.Strings.Fixed.Trim (Natural'Image (Value), Ada.Strings.Left));

   overriding
   procedure Describe (Item : Face; Facts : in out Semantics.Description) is
   begin
      if Facts.Kind = Semantics.Unknown then
         Facts.Kind := Semantics.Image;
      end if;
      Semantics.Value_As (Facts, Two (Item.Hour) & ":" & Two (Item.Minute) & ":" & Two (Item.Second));
   end Describe;

end Clock_Faces;
