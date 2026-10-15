with Pomarine_Ui_Config;
with Ada.Strings.Unbounded;
with SDL3.Windows.Renderers.Textures;
with SDL3.Windows.Renderers;

--  Icons, drawn from SVG files in a folder: the outline pictures buttons
--  show, drawn in one colour (the files' own colours are not used), at
--  the size they are wanted, made once each.
--
--  The library has no pictures of its own. An Icon is only a number the
--  application gives a file to (Set_File): widgets are given the Icon to
--  show. The few that the widgets themselves draw (Check, Close,
--  Minimize, Chevron_Down, Chevron_Up) have a number here, and a file
--  named for them ("check.svg" and so on) unless the application says
--  otherwise; the application's own start at First_Custom.
--
--  Declare a library after the renderer it draws to, and always draw it
--  to that renderer.
package Pomarine.Icons is

   Capacity : constant := Pomarine_Ui_Config.Icon_Capacity;
   --  Icons of one library, those of the widgets and the application's.

   type Icon is range 1 .. Capacity;

   Check        : constant Icon := 1;
   Close        : constant Icon := 2;
   Minimize     : constant Icon := 3;
   Chevron_Down : constant Icon := 4;
   Chevron_Up   : constant Icon := 5;
   --  What the widgets draw themselves.

   First_Custom : constant Icon := 6;
   --  The application's are Custom (0), Custom (1) and so on.

   function Custom (Offset : Natural) return Icon is
     (Icon (Natural (First_Custom) + Offset))
     with Pre => Offset <= Natural (Capacity - First_Custom);

   File_Extension : constant String := ".svg";

   File_Capacity : constant := 48;

   type Library is limited private;

   procedure Set_Directory (Item : in out Library; Path : String);
   --  Where the files are. Icons made already are forgotten.

   procedure Set_File (Item : in out Library; Which : Icon; Name : String)
     with Pre => Name'Length in 1 .. File_Capacity;
   --  The name of the file of Which, in the directory, with its extension.
   --  If made already, it is forgotten.

   function File_Name (Item : Library; Which : Icon) return String;
   --  What Set_File gave, or for the widgets' own, the default: the
   --  icon's name in lower case with the extension. Empty if none.

   procedure Draw
     (Item   : in out Library;
      Target : SDL3.Windows.Renderers.Renderer;
      Which  : Icon;
      Value  : SDL3.Windows.Renderers.Color;
      Left, Top : Float;
      Size   : Positive;
      Drawn  : out Boolean);
   --  Draw it in colour Value, Size pixels square, with its top left at
   --  Left, Top. The file is read, and rasterized, the first time. Drawn
   --  says whether it was: not if there is no file, or it cannot be read
   --  (which is not tried again).

private

   type Made is record
      Image  : SDL3.Windows.Renderers.Textures.Texture;
      Size   : Natural := 0;     --  in pixels, of Image; 0 if none
      Failed : Natural := 0;     --  the size that could not be made
   end record;

   type Made_Array is array (Icon) of Made;

   type Stored_Name is record
      Text   : String (1 .. File_Capacity) := [others => ' '];
      Length : Natural range 0 .. File_Capacity := 0;
   end record;

   type Name_Array is array (Icon) of Stored_Name;

   type Library is limited record
      Folder : Ada.Strings.Unbounded.Unbounded_String;
      Icons  : Made_Array;
      Names  : Name_Array;
   end record;

end Pomarine.Icons;
