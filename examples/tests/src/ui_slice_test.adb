with Ada.Text_IO;
with Pomarine.Events;
with Pomarine.Testing;
with Pomarine.UI;
with Pomarine.Widgets;
with Form_UI;
with Form_VM;

--  The first slice: a text field and commands, through a view that owns its widgets.
procedure UI_Slice_Test is
   package UI renames Pomarine.UI;
   package Testing renames Pomarine.Testing;
   package Forms renames Form_UI.Forms;
   use all type Form_VM.Command;

   Tree   : aliased Pomarine.Widgets.Tree;
   Model  : aliased Form_VM.Model;
   Screen : UI.View (Tree'Access);
   Window : Testing.Session;

   function Form_Part (Parent : Forms.Context'Class) return UI.Layout is
      Bound : aliased Forms.Component (Parent'Access);
      Name  : constant UI.Field_Handle := Bound.Text_Field
        (Form_UI.Name, Submit => Save, Placeholder => "Name", Name => "Name");
      Shown : constant UI.Label_Handle := Bound.Label (Form_UI.Status);
      Done  : constant UI.Button_Handle := Bound.Button ("Save", Save);
      Clear : constant UI.Button_Handle := Bound.Button ("Reset", Reset);
      Result : constant UI.Layout := UI.Column
        ([UI.Place (Name), UI.Place (Shown), UI.Row ([UI.Place (Done), UI.Place (Clear)], Gap => 8.0)],
         Padding => 12.0, Gap => 8.0);
   begin
      Bound.Focus_Initially (UI.Focus_Of (Name));
      Bound.Commit;
      return Result;
   end Form_Part;

begin
   declare
      Bound : constant Forms.Context'Class := Forms.Bind (Screen, Model'Access);
      Form  : constant UI.Layout := Form_Part (Bound);
   begin
      UI.Mount (Screen, Form);
   end;
   Testing.Open (Window, Tree, 400, 200);
   Ada.Text_IO.Put_Line (Testing.Screen (Window));
   pragma Assert (Testing.Is_Disabled (Window, "Save"));
   pragma Assert (Testing.Is_Disabled (Window, "Reset"));
   pragma Assert (Testing.Shows (Window, "0 saved"));
   Testing.Type_Text (Window, "abc");
   pragma Assert (Form_VM.Name (Model) = "abc");
   pragma Assert (not Testing.Is_Disabled (Window, "Save"));
   Testing.Press (Window, Pomarine.Events.Key_Return);
   pragma Assert (Form_VM.Saved_Count (Model) = 1);
   pragma Assert (Form_VM.Last_Saved (Model) = "abc");
   pragma Assert (Testing.Shows (Window, "1 saved"));
   pragma Assert (Testing.Value_Of (Window, "Name") = "");
   Ada.Text_IO.Put_Line (Form_VM.Journal (Model));
   Ada.Text_IO.Put_Line ("ok");
end UI_Slice_Test;
