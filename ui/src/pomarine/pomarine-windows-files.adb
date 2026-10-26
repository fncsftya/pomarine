with SDL3.Dialogs;
package body Pomarine.Windows.Files is
   procedure Open_File (Over : Window; Name, Extensions : String) is
   begin
      SDL3.Dialogs.Open_File (Over.Frame, Name, Extensions);
   end Open_File;

   procedure Save_File (Over : Window; Name, Extensions, Suggested : String) is
   begin
      SDL3.Dialogs.Save_File (Over.Frame, Name, Extensions, Suggested);
   end Save_File;
end Pomarine.Windows.Files;
