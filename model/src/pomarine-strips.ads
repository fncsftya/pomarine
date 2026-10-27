--  A picture too tall to be one texture, kept as several PNG files, one
--  under another and all as wide: the first is the file itself, and the
--  others are beside it, named for it without its ending, then the number
--  and ".png" ("71.png", "71.2.png", "71.3.png"). Whatever draws or reads
--  such a picture finds its strips here, so a picture of one file is just a
--  picture of one strip.

package Pomarine.Strips is

   Max_Strips : constant := 32;
   --  How many a picture is of, at the most: more are not looked for.

   subtype Strip_Index is Positive range 1 .. Max_Strips;

   function Strip_File (Path : String; Index : Strip_Index) return String
   with Pre => Path'Length > 0, Post => (if Index = 1 then Strip_File'Result = Path else Strip_File'Result'Length > 0);
   --  The file of strip Index of the picture whose first strip is Path.

   function Strip_Count (Path : String) return Natural
   with Post => Strip_Count'Result <= Max_Strips;
   --  How many strips there are: those of 1 on whose files exist, in order,
   --  so 0 if Path itself does not.

end Pomarine.Strips;
