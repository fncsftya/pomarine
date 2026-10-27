with Pomarine.Widgets.Menus;
with Pomarine.Icons;

--  Immutable row descriptions composed before the menu is changed. Dynamic content uses growing storage.

package Pomarine.UI.Menus is

   package Widgets_Menus renames Pomarine.Widgets.Menus;
   subtype Row_Description is Widgets_Menus.Row_Description;

   function Row
     (Kind    : Widgets_Menus.Row_Kind;
      Text    : String := "";
      Shade   : Widgets_Menus.Tone := Widgets_Menus.Plain;
      Checked : Boolean := False;
      Allowed : Boolean := True;
      Icon    : Pomarine.Icons.Optional := Pomarine.Icons.No_Icon;
      Swatch  : Themes.Slot := 0) return Row_Description
   renames Widgets_Menus.Describe_Row;

   package Row_Vectors renames Widgets_Menus.Row_Vectors;
   subtype Content is Row_Vectors.Vector;

   function Count (Rows : Content) return Natural
   is (Natural (Rows.Length));
   procedure Set_Content (Item : in out Widgets_Menus.Menu; Rows : Content) renames Widgets_Menus.Set_Rows;

end Pomarine.UI.Menus;
