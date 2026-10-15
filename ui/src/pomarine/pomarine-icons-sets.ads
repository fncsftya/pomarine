--  An application's icons, named by an enumeration.
--
--     type Name is (Edit, Delete, Stroke_Dots);
--     package Sets is new Pomarine.Icons.Sets (Name);
--
--     Sets.Install (Library, "share/icons");     --  edit.svg, delete.svg, stroke_dots.svg
--     Buttons.Set_Icon (Rename, Sets.Icon_Of (Edit));
--
--  so that there is one list of the icons, and no numbers to keep in step with
--  the files.
generic
   type Name is (<>);
package Pomarine.Icons.Sets is

   pragma Compile_Time_Error
     (Name'Pos (Name'Last) > Natural (Capacity) - Natural (First_Custom),
      "more icons than a library holds (see Pomarine_Ui_Config.Icon_Capacity)");

   function Icon_Of (Which : Name) return Icon is (Custom (Name'Pos (Which)));
   --  The icon that is Which, among the library's.

   function File_Of (Which : Name) return String;
   --  Its file: its name in lower case, with File_Extension.

   procedure Install (Item : in out Library; Directory : String);
   --  Say where the files are, and which is which: those of every Name.

end Pomarine.Icons.Sets;
