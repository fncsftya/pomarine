package body Pomarine.Widgets.Tooltips is

   use type Semantics.Role;

   use all type SDL3.Painters.Painter;

   Pad : constant Float := 8.0;  --  in points, at each side

   procedure Set_Text (Item : in out Tooltip; Value : String) is
   begin
      if Value /= Text (Item) then
         Item.Content := Ada.Strings.Unbounded.To_Unbounded_String (Value);
         if Is_Attached (Item) then
            Invalidate (Item);
         end if;
      end if;
   end Set_Text;

   function Text (Item : Tooltip) return String is
     (Ada.Strings.Unbounded.To_String (Item.Content));

   function Natural_Width (Item : Tooltip) return Float is
     (2.0 * Pad
      + (if Text_Lines (Item) = null then 0.0
         else Pomarine.Line_Texts.Width
                (Text_Lines (Item).all, Text (Item), 1.0,
                 Pomarine.Line_Texts.Strong)));

   overriding procedure Draw
     (Item   : in out Tooltip;
      Target : SDL3.Painters.Painter'Class;
      Colors : Themes.Theme)
   is
      Pixels : constant Float := Density (Item);
   begin
      Fill_Rect
        (Target, Colors (Themes.Bar), Left_Of (Item), Top_Of (Item), Width_Of (Item),
         Height_Of (Item));
      if Ada.Strings.Unbounded.Length (Item.Content) > 0 and then Text_Lines (Item) /= null then
         Pomarine.Line_Texts.Draw
           (Text_Lines (Item).all, Target, Themes.Soft_White, Text (Item),
            Left_Of (Item)
            + (Width_Of (Item)
               - Pomarine.Line_Texts.Width
                   (Text_Lines (Item).all, Text (Item), Pixels,
                    Pomarine.Line_Texts.Strong)) / 2.0,
            Top_Of (Item) + Height_Of (Item) / 2.0, Pixels,
            Pomarine.Line_Texts.Strong);
      end if;
   end Draw;

   overriding procedure Describe
     (Item  : Tooltip;
      Facts : in out Semantics.Description) is
   begin
      if Facts.Kind = Semantics.Unknown then
         Facts.Kind := Semantics.Tooltip;
      end if;
      Semantics.Name_As (Facts, Text (Item));
   end Describe;

end Pomarine.Widgets.Tooltips;
