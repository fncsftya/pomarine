--  Native file-dialog bridge; applications use Pomarine.Dialogs.
package Pomarine.Windows.Files is
   procedure Open_File (Over : Window; Name, Extensions : String)
     with Pre => Is_Open (Over);
   procedure Save_File (Over : Window; Name, Extensions, Suggested : String)
     with Pre => Is_Open (Over);
end Pomarine.Windows.Files;
