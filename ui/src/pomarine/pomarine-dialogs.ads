with Ada.Strings.Unbounded;
with Pomarine.Windows;
with Pomarine.Widgets.Dialogs;

--  The questions most programs ask, ready made from a Dialog the program has added to its tree (see
--  Pomarine.Widgets.Dialogs): tell the person something, ask them to go ahead or not, or to choose one of a few. Each
--  sets the dialog up and shows it, over everything; what the person answers is heard as the dialog's Choose (or
--  Dismiss, for Escape), which these read:
--
--     Dialogs.Confirm (Ask, "Delete the file?", "It cannot be got back.", Yes => "Delete", Dangerous => True);
--     ...                              --  later, in the listener, or with Callbacks.On (Ask, Choose, ...)
--     if Dialogs.Confirmed (Event) then Delete_It; end if;
package Pomarine.Dialogs is

   type File_States is (Idle, Waiting, Chosen, Cancelled, Failed);
   --  One native file dialog at a time. Completion wakes the event loop. Copy File_Path before Reset_File.
   function File_State return File_States;

   procedure Open_File
     (Over : Windows.Window; Name : String := "Files"; Extensions : String := "")
     with Pre => Windows.Is_Open (Over) and then File_State /= Waiting;
   --  Extensions: semicolon-separated, such as "pdf;epub", or empty for any file.

   procedure Save_File
     (Over : Windows.Window; Name : String := "Files"; Extensions : String := ""; Suggested : String := "")
     with Pre => Windows.Is_Open (Over) and then File_State /= Waiting;

   function File_Path return String
     with Pre => File_State = Chosen, Post => File_Path'Result'Length > 0;

   procedure Reset_File
     with Pre => File_State /= Waiting, Post => File_State = Idle;

   subtype Dialog is Pomarine.Widgets.Dialogs.Dialog;

   function "+" (Text : String) return Ada.Strings.Unbounded.Unbounded_String
     renames Ada.Strings.Unbounded.To_Unbounded_String;

   type Choice_Array is array (Positive range <>) of Ada.Strings.Unbounded.Unbounded_String;
   --  What the person is to choose from: [+"Save", +"Don't save", +"Cancel"].

   procedure Alert
     (Item    : in out Dialog;
      Title   : String;
      Message : String := "";
      Ok      : String := "OK")
     with Pre => Pomarine.Widgets.Is_Attached (Item) and then not Pomarine.Widgets.Dialogs.Is_Shown (Item);
   --  Tell them, with the one button. Whatever they do ends it: Choose with 1, or Dismiss.

   procedure Confirm
     (Item      : in out Dialog;
      Title     : String;
      Message   : String := "";
      Yes       : String := "OK";
      No        : String := "Cancel";
      Dangerous : Boolean := False)
     with Pre => Pomarine.Widgets.Is_Attached (Item) and then not Pomarine.Widgets.Dialogs.Is_Shown (Item);
   --  Ask whether to go ahead: No is the first button, Yes the second and the one that has the focus (the first, No,
   --  if Dangerous, which has Yes in the danger colour).

   function Confirmed (Event : Pomarine.Widgets.Widget_Event) return Boolean;
   --  Whether they said Yes (the second button of Confirm).

   Confirm_Yes : constant := 2;

   procedure Choose_From
     (Item    : in out Dialog;
      Title   : String;
      Message : String;
      Choices : Choice_Array;
      Default : Positive := 1)
     with Pre => Pomarine.Widgets.Is_Attached (Item) and then not Pomarine.Widgets.Dialogs.Is_Shown (Item)
                 and then Choices'Length in 1 .. Pomarine.Widgets.Dialogs.Max_Buttons
                 and then Default <= Choices'Length;
   --  Ask which of up to Max_Buttons: the answer is the number, from 1, of the one they chose.

   function Chosen (Event : Pomarine.Widgets.Widget_Event) return Natural;
   --  Which of the choices, from 1; 0 if they cancelled (Escape).

end Pomarine.Dialogs;
