package body Todo is

   use all type Todo_VM.Command;

   function Entry_Field
     (Parent  : Todo_UI.Context'Class;
      Text    : Todo_UI.Text_Property;
      Submit  : Todo_VM.Command;
      Prompt  : String) return Entry_Part
   is
      Bound  : aliased Todo_UI.Component (Parent'Access);
      Typed  : constant UI.Field_Handle := Bound.Text_Field (Text, Submit => Submit, Placeholder => Prompt);
      Result : constant Entry_Part := (Layout => UI.Place (Typed), Focus => UI.Focus_Of (Typed));
   begin
      Bound.Commit;
      return Result;
   end Entry_Field;

   function Command_Button
     (Parent  : Todo_UI.Context'Class;
      Caption : String;
      Command : Todo_VM.Command;
      Width   : UI.Layouts.Length;
      Look    : Pomarine.Widgets.Buttons.Kind := Pomarine.Widgets.Buttons.Normal) return UI.Layout
   is
      Bound  : aliased Todo_UI.Component (Parent'Access);
      Made   : constant UI.Button_Handle := Bound.Button (Caption, Command => Command, Look => Look);
      Result : constant UI.Layout := UI.Place (Made, Width => Width);
   begin
      Bound.Commit;
      return Result;
   end Command_Button;

   function Task_Entry (Parent : Todo_UI.Context'Class) return Entry_Part is
     (Entry_Field (Parent, Task_Draft, Add_Task, "What needs doing? Press Return"));

   function Task_Content (Parent : Todo_UI.Context'Class) return Content_Part is
      Bound : aliased Todo_UI.Component (Parent'Access);
      Tasks_List : constant UI.List_Handle := Bound.List (Task_Rows, Task_Choice);
      Result : constant Content_Part :=
        (Layout => UI.Place (Tasks_List, Grow => 1.0), Reveal => UI.Reveal_Of (Tasks_List));
   begin
      Bound.Commit;
      return Result;
   end Task_Content;

   function Task_Actions (Parent : Todo_UI.Context'Class) return UI.Layout is
      Bound   : aliased Todo_UI.Component (Parent'Access);
      Summary : constant UI.Label_Handle := Bound.Label (Text => Task_Summary);
      Done    : constant UI.Layout := Command_Button (Bound, "Done", Toggle_Chosen, Width => 70.0);
      Delete  : constant UI.Layout :=
        Command_Button (Bound, "Delete", Remove_Chosen, Width => 70.0, Look => Pomarine.Widgets.Buttons.Danger);
      Clear   : constant UI.Layout := Command_Button (Bound, "Clear done", Sweep_Done, Width => 100.0);
      Result  : constant UI.Layout := UI.Row ([UI.Place (Summary, Grow => 1.0), Done, Delete, Clear], Gap => 8.0);
   begin
      Bound.Commit;
      return Result;
   end Task_Actions;

   function Task_Screen (Bound : Todo_UI.Context'Class) return UI.Layout is
      --  Declared one after the other: the order controls are made in is the order of the tab key.
      Entry_Area : constant Entry_Part := Task_Entry (Bound);
      Content    : constant Content_Part := Task_Content (Bound);
      Actions    : constant UI.Layout := Task_Actions (Bound);
   begin
      Bound.Focus_Initially (Entry_Area.Focus);
      Bound.Reveal_After (Add_Task, Content.Reveal, Task_Count);
      return UI.Column ([Entry_Area.Layout, Content.Layout, Actions], Padding => 12.0, Gap => 8.0);
   end Task_Screen;

   procedure Build (Screen : in out UI.View; Model : not null access Todo_VM.Model) is
      Bound : constant Todo_UI.Context'Class := Todo_UI.Bind (Screen, Model);
      Whole : constant UI.Layout := Task_Screen (Bound);
   begin
      UI.Mount (Screen, Whole);
   end Build;

end Todo;
