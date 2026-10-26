with Pomarine.Widgets.Buttons;
package body Pomarine.Dialogs is

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
