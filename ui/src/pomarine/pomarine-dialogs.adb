with Pomarine.Widgets.Buttons;
with Pomarine.Windows.Files;
with SDL3.Dialogs;
package body Pomarine.Dialogs is

   function File_State return File_States is
     (File_States'Val (SDL3.Dialogs.States'Pos (SDL3.Dialogs.State)));
   function File_Path return String is (SDL3.Dialogs.Path);

   procedure Reset_File is
   begin
      SDL3.Dialogs.Reset;
   end Reset_File;

   procedure Open_File
     (Over : Windows.Window; Name : String := "Files"; Extensions : String := "") is
   begin
      Windows.Files.Open_File (Over, Name, Extensions);
   end Open_File;

   procedure Save_File
     (Over : Windows.Window; Name : String := "Files"; Extensions : String := ""; Suggested : String := "") is
   begin
      Windows.Files.Save_File (Over, Name, Extensions, Suggested);
   end Save_File;

   package Boxes renames Pomarine.Widgets.Dialogs;
   package Buttons renames Pomarine.Widgets.Buttons;

   procedure Say (Item : in out Dialog; Title, Message : String) is
   begin
      Boxes.Clear_Buttons (Item);
      Boxes.Set_Title (Item, Title);
      Boxes.Set_Message (Item, Message);
   end Say;

   procedure Alert
     (Item    : in out Dialog;
      Title   : String;
      Message : String := "";
      Ok      : String := "OK") is
   begin
      Say (Item, Title, Message);
      Boxes.Add_Button (Item, Ok, Buttons.Primary);
      Boxes.Set_Default (Item, 1);
      Boxes.Show (Item);
   end Alert;

   procedure Confirm
     (Item      : in out Dialog;
      Title     : String;
      Message   : String := "";
      Yes       : String := "OK";
      No        : String := "Cancel";
      Dangerous : Boolean := False) is
   begin
      Say (Item, Title, Message);
      Boxes.Add_Button (Item, No);
      Boxes.Add_Button (Item, Yes, (if Dangerous then Buttons.Danger else Buttons.Primary));
      Boxes.Set_Default (Item, (if Dangerous then 1 else Confirm_Yes));
      Boxes.Show (Item);
   end Confirm;

   function Confirmed (Event : Pomarine.Widgets.Widget_Event) return Boolean is
     (Boxes.Answer (Event) = Confirm_Yes);

   procedure Choose_From
     (Item    : in out Dialog;
      Title   : String;
      Message : String;
      Choices : Choice_Array;
      Default : Positive := 1) is
   begin
      Say (Item, Title, Message);
      for Each of Choices loop
         Boxes.Add_Button (Item, Ada.Strings.Unbounded.To_String (Each));
      end loop;
      Boxes.Set_Default (Item, Default);
      Boxes.Show (Item);
   end Choose_From;

   function Chosen (Event : Pomarine.Widgets.Widget_Event) return Natural is (Boxes.Answer (Event));

end Pomarine.Dialogs;
