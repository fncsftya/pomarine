with Pomarine.Text_Areas;
package body Pomarine.Widgets.Text_Fields is

   Longest : constant := 100_000.0;
   --  Layout units: wider than any line is typed.

   function Text_Area_Of (Item : in out Text_Field)
      return not null access Text_Areas.Text_Area is
     (Editors.Area (Editors.Editor (Item)));

   procedure Configure
     (Item   : in out Text_Field;
      Family : String;
      Size   : Float) is
   begin
      Editors.Configure
        (Editors.Editor (Item), Family, Size, Measure => Longest);
      Text_Areas.Set_Single_Line (Text_Area_Of (Item).all);
   end Configure;

end Pomarine.Widgets.Text_Fields;
