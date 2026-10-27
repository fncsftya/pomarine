with Ada.Strings.Unbounded;
with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Labels;
with Pomarine.Widgets.Panels;

--  A dialog: a title, a message, wrapped to the dialog's width in up to Max_Lines lines, and up to Max_Buttons buttons
--  in a row at the right, in a white box, outlined and casting a shadow, that is over everything, and dims what is
--  under it, while it is asked about (see Pomarine.Widgets.Overlays). What is under it takes no input, Tab goes round
--  only its buttons, the focus is on the default one, Return or Space presses it, and Escape lets it go.
--
--     Dialogs.Add (Root, Ask);                                     --  once, hidden
--     Dialogs.Set_Title (Ask, "Delete the file?");
--     Dialogs.Set_Message (Ask, "It cannot be got back.");
--     Dialogs.Add_Button (Ask, "Cancel");
--     Dialogs.Add_Button (Ask, "Delete", Buttons.Danger);
--     Dialogs.Show (Ask);
--
--  A button says Choose, with its Row the number of the button, and the dialog is let go of; Escape says Dismiss (take
--  it as Cancel). Both are heard by the listener or with Callbacks.On (Ask, Choose, ...). Pomarine.Dialogs has the
--  usual three, ready made.

package Pomarine.Widgets.Dialogs is

   Max_Lines   : constant := 8;
   Max_Buttons : constant := 4;
   --  What one dialog shows: a message of more lines than that ends in an ellipsis, a choice of more than four
   --  buttons is for a list.

   type Dialog is new Panels.Panel with private;

   procedure Add (Parent : in out Widget'Class; Item : in out Dialog; Width : Float := 360.0)
   with
     Pre  => Is_Attached (Parent) and then not Is_Attached (Item) and then Child_Count (Item) = 0,
     Post => Is_Attached (Item) and then not Is_Visible (Item);
   --  Add Item to Parent, which is the root, or a box that covers the window, hidden, with its parts in it, Width
   --  points wide.

   procedure Set_Title (Item : in out Dialog; Text : String);

   function Title (Item : Dialog) return String;

   procedure Set_Message (Item : in out Dialog; Text : String)
   with Pre => Is_Attached (Item);
   --  Wrapped at the spaces to fit the width, and cut at each LF; more than Max_Lines end in "...".

   function Message (Item : Dialog) return String;

   procedure Add_Button (Item : in out Dialog; Label : String; Look : Buttons.Kind := Buttons.Normal)
   with Pre => Button_Count (Item) < Max_Buttons;
   --  A button after the others.

   procedure Clear_Buttons (Item : in out Dialog)
   with Post => Button_Count (Item) = 0;

   function Button_Count (Item : Dialog) return Natural;

   procedure Set_Default (Item : in out Dialog; Button : Natural)
   with Pre => Button <= Button_Count (Item);
   --  Which button has the focus when it is shown; none (0) for the first.

   procedure Show (Item : in out Dialog)
   with Pre => Is_Attached (Item) and then Button_Count (Item) > 0;
   --  Over everything, in the middle of the window.

   procedure Hide (Item : in out Dialog);
   --  Let go of it, saying nothing.

   function Is_Shown (Item : Dialog) return Boolean;

   function Answer (Event : Widget_Event) return Natural;
   --  Of what it said: the number of the button for a Choose, 0 for a Dismiss (it was cancelled).

private

   type Line_Array is array (1 .. Max_Lines) of Labels.Label;
   type Button_Array is array (1 .. Max_Buttons) of Buttons.Button;

   type Dialog is new Panels.Panel with record
      Heading : Labels.Label;
      Lines   : Line_Array;
      Row     : Panels.Panel;
      Choices : Button_Array;
      Count   : Natural := 0;
      Default : Natural := 0;
      Whole   : Ada.Strings.Unbounded.Unbounded_String;
      Room    : Float := 360.0;
      --  The width, in points.
   end record;

end Pomarine.Widgets.Dialogs;
