with Ada.Strings.Fixed;
package body Pomarine.Widgets.Progress_Bars is

   use type Semantics.Role;

   procedure Set_Value (Item : in out Progress_Bar; To : Float) is
   begin
      if To /= Item.Fraction then
         Item.Fraction := To;
         if Is_Attached (Item) then
            Invalidate (Item);
         end if;
      end if;
   end Set_Value;

   function Value (Item : Progress_Bar) return Float is (Item.Fraction);

   overriding procedure Draw
     (Item   : in out Progress_Bar;
      Target : SDL3.Painters.Painter'Class;
      Colors : Themes.Theme) is
   begin
      SDL3.Painters.Fill_Rect
        (Target, Themes.Mix (Colors (Themes.Background), Colors (Themes.Foreground), 0.2),
         Left_Of (Item), Top_Of (Item), Width_Of (Item), Height_Of (Item));
      SDL3.Painters.Fill_Rect
        (Target, Colors (Themes.Accent),
         Left_Of (Item), Top_Of (Item),
         Float'Rounding (Width_Of (Item) * Item.Fraction), Height_Of (Item));
   end Draw;

   overriding procedure Describe
     (Item  : Progress_Bar;
      Facts : in out Semantics.Description) is
   begin
      if Facts.Kind = Semantics.Unknown then
         Facts.Kind := Semantics.Progress_Indicator;
      end if;
      Facts.Has_Number := True;
      Facts.Number := Item.Fraction;
      Facts.Minimum := 0.0;
      Facts.Maximum := 1.0;
      Semantics.Value_As
        (Facts, Ada.Strings.Fixed.Trim
                  (Integer'Image (Integer (Item.Fraction * 100.0)), Ada.Strings.Left) & "%");
   end Describe;

end Pomarine.Widgets.Progress_Bars;
