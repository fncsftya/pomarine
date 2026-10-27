with Ada.Directories;
with Ada.Strings.Fixed;

package body Pomarine.Strips is

   use type Ada.Directories.File_Kind;

   function Stem (Path : String) return String
   is (if Path'Length > 4 and then Path (Path'Last - 3 .. Path'Last) = ".png"
       then Path (Path'First .. Path'Last - 4)
       else Path);

   function Strip_File (Path : String; Index : Strip_Index) return String
   is (if Index = 1 then Path else Stem (Path) & "." & Ada.Strings.Fixed.Trim (Index'Image, Ada.Strings.Both) & ".png");

   function Strip_Count (Path : String) return Natural is
      Count : Natural := 0;
   begin
      if Path = "" then
         return 0;
      end if;
      while Count < Max_Strips
        and then Ada.Directories.Exists (Strip_File (Path, Count + 1))
        and then Ada.Directories.Kind (Strip_File (Path, Count + 1)) = Ada.Directories.Ordinary_File
      loop
         Count := Count + 1;
      end loop;
      return Count;
   exception
      when Ada.Directories.Name_Error | Ada.Directories.Use_Error =>
         return Count;
   end Strip_Count;

end Pomarine.Strips;
