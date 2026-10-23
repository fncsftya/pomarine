with SDL3.Windows;

--  The system's dialog to choose a file, or where to save one, shown over a window while the
--  program goes on: it asks (Open_File), and finds out later, when its
--  event loop looks (State), what was chosen. One at a time. The loop that
--  is waiting for events is woken when the dialog ends (see
--  SDL3.Events.Wake).
package SDL3.Dialogs is

   type States is (Idle, Waiting, Chosen, Cancelled, Failed);
   --  Idle: none was asked for, or what it said was taken (Reset).
   --  Waiting: it is shown. Chosen: Path is the file. Cancelled: it was
   --  closed without one. Failed: it could not be shown.

   Max_Path : constant := 1_024;

   procedure Open_File
     (Over       : SDL3.Windows.Window;
      Name       : String;
      Extensions : String)
     with Pre => State /= Waiting and then SDL3.Windows.Is_Open (Over)
                 and then Name'Length <= 63 and then Extensions'Length <= 255;
   --  Ask for a file: Name says what kinds are shown, and Extensions
   --  which, as "pdf;epub" (those that are listed; any if empty).

   procedure Save_File
     (Over       : SDL3.Windows.Window;
      Name       : String;
      Extensions : String;
      Suggested  : String)
     with Pre => State /= Waiting and then SDL3.Windows.Is_Open (Over)
                 and then Name'Length <= 63 and then Extensions'Length <= 255
                 and then Suggested'Length <= 255;
   --  Ask where to save a file: the dialog is as Open_File's, and Suggested is the
   --  name it starts with ("" for none). Chosen, Path is where, which need not exist.

   function State return States;

   function Path return String
     with Pre => State = Chosen,
          Post => Path'Result'Length in 1 .. Max_Path;

   procedure Reset
     with Pre => State /= Waiting, Post => State = Idle;

end SDL3.Dialogs;
