with Ada.Directories;
with Ada.Exceptions;
with Ada.Text_IO;

package body Pomarine.Icons is

   package Textures renames SDL3.Windows.Renderers.Textures;

   use Ada.Strings.Unbounded;

   function File_Name (Item : Library; Which : Icon) return String is
     (if Item.Names (Which).Length > 0
      then Item.Names (Which).Text (1 .. Item.Names (Which).Length)
      elsif Which = Check then "check" & File_Extension
      elsif Which = Close then "close" & File_Extension
      elsif Which = Minimize then "minimize" & File_Extension
      elsif Which = Chevron_Down then "chevron_down" & File_Extension
      elsif Which = Chevron_Up then "chevron_up" & File_Extension
      else "");

   procedure Forget (Each : in out Made) is
   begin
      Each.Size := 0;
      Each.Failed := 0;
   end Forget;

   procedure Set_File (Item : in out Library; Which : Icon; Name : String) is
      Padded : String (1 .. File_Capacity) := [others => ' '];
   begin
      Padded (1 .. Name'Length) := Name;
      Item.Names (Which) := (Text => Padded, Length => Name'Length);
      Forget (Item.Icons (Which));
   end Set_File;

   procedure Set_Directory (Item : in out Library; Path : String) is
   begin
      Item.Folder := To_Unbounded_String (Path);
      for Each of Item.Icons loop
         Forget (Each);
      end loop;
   end Set_Directory;

   procedure Make
     (Item   : in out Library;
      Target : SDL3.Windows.Renderers.Renderer;
      Which  : Icon;
      Size   : Positive;
      Made_It : out Boolean);
   --  Have the icon Size pixels square, if it can be.

   procedure Make
     (Item   : in out Library;
      Target : SDL3.Windows.Renderers.Renderer;
      Which  : Icon;
      Size   : Positive;
      Made_It : out Boolean)
   is
      Each : Made renames Item.Icons (Which);
      Path : constant String :=
        To_String (Item.Folder) & "/" & File_Name (Item, Which);
   begin
      Made_It := Each.Size = Size;
      if Made_It or else Each.Failed = Size or else Item.Folder = ""
        or else File_Name (Item, Which) = ""
      then
         return;
      end if;

      Each.Failed := Size;  --  until it is not
      if Ada.Directories.Exists (Path) then
         Each.Size := 0;
         Textures.Create_Mask_From_SVG (Each.Image, Target, Path, Size, Size);
         Each.Size := Size;
         Each.Failed := 0;
         Made_It := True;
      end if;
   exception
      when Problem : others =>
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "Could not make icon " & Path & ": "
            & Ada.Exceptions.Exception_Message (Problem));
   end Make;

   procedure Draw
     (Item   : in out Library;
      Target : SDL3.Windows.Renderers.Renderer;
      Which  : Icon;
      Value  : SDL3.Windows.Renderers.Color;
      Left, Top : Float;
      Size   : Positive;
      Drawn  : out Boolean) is
   begin
      Make (Item, Target, Which, Size, Drawn);
      if Drawn then
         Textures.Draw_Tinted
           (Target, Item.Icons (Which).Image, Left, Top, Value);
      end if;
   end Draw;

end Pomarine.Icons;
