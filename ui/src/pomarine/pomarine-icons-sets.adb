with Ada.Characters.Handling;

package body Pomarine.Icons.Sets is

   function File_Of (Which : Name) return String
   is (Ada.Characters.Handling.To_Lower (Name'Image (Which)) & File_Extension);

   procedure Install (Item : in out Library; Directory : String) is
   begin
      Set_Directory (Item, Directory);
      for Each in Name loop
         Set_File (Item, Icon_Of (Each), File_Of (Each));
      end loop;
   end Install;

end Pomarine.Icons.Sets;
