with Ada.Text_IO;
with Pomarine.Events;
with Pomarine.Testing;
with Pomarine.UI;
with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Editors;
with Pomarine.Widgets;
with Texts.Documents;
with Form_Parts;
with Form_UI;
with Form_VM;
with Todo;
with Todo_VM;

--  Keeping widgets and models in step: the first turn, the order of an edit and a command, the watches, and
--  two models in one view.
procedure UI_Sync_Test is
   package UI renames Pomarine.UI;
   package Testing renames Pomarine.Testing;
   package Widgets renames Pomarine.Widgets;
   package Forms renames Form_UI.Forms;
   package Docs renames Texts.Documents;

   function Shown (Screen : UI.View; Field : UI.Field_Handle) return String is
     (Docs.Whole (Widgets.Editors.Document (Widgets.Editors.Editor (UI.Widget_Of (Screen, Field).all)).all));

   procedure The_First_Turn_Is_Before_Anyone_Can_Use_It is
      Tree   : aliased Widgets.Tree;
      Model  : aliased Form_VM.Model;
      Screen : UI.View (Tree'Access);
      Before : constant Natural := Form_Parts.Runs;
   begin
      Form_VM.Set_Name (Model, "preset");
      Form_VM.Forget_Journal (Model);
      declare
         Bound : constant Forms.Context'Class := Forms.Bind (Screen, Model'Access);
         Part  : constant Form_Parts.Field_Part := Form_Parts.Handles_Part (Bound);
      begin
         pragma Assert (Shown (Screen, Part.Field) = "");
         UI.Mount (Screen, Part.Layout);
         --  Mount returned: nothing has been drawn, updated or clicked yet.
         pragma Assert (Shown (Screen, Part.Field) = "preset");
         pragma Assert (Widgets.Buttons.Is_Enabled (UI.Widget_Of (Screen, Part.Save).all));
         pragma Assert (Form_VM.Journal (Model) = "");
         pragma Assert (Form_Parts.Runs = Before + 1);
      end;
      --  And a model that cannot yet save is shown as one that cannot.
      declare
         Tree_2   : aliased Widgets.Tree;
         Model_2  : aliased Form_VM.Model;
         Screen_2 : UI.View (Tree_2'Access);
         Bound    : constant Forms.Context'Class := Forms.Bind (Screen_2, Model_2'Access);
         Part     : constant Form_Parts.Field_Part := Form_Parts.Handles_Part (Bound);
      begin
         UI.Mount (Screen_2, Part.Layout);
         pragma Assert (not Widgets.Buttons.Is_Enabled (UI.Widget_Of (Screen_2, Part.Save).all));
      end;
   end The_First_Turn_Is_Before_Anyone_Can_Use_It;

   procedure A_Command_Sees_The_Edit_Before_It is
      Tree   : aliased Widgets.Tree;
      Model  : aliased Form_VM.Model;
      Screen : UI.View (Tree'Access);
      Window : Testing.Session;
   begin
      declare
         Bound : constant Forms.Context'Class := Forms.Bind (Screen, Model'Access);
         Part  : constant Form_Parts.Field_Part := Form_Parts.Handles_Part (Bound);
      begin
         UI.Mount (Screen, Part.Layout);
      end;
      Testing.Open (Window, Tree, 300, 200);
      pragma Assert (Testing.Is_Disabled (Window, "Save"));

      --  Typed and Return pressed in one turn, with no update between: the model is told what was
      --  typed, found able to Save, and does.
      Testing.Feed (Window, Pomarine.Events.Text_Event ("abc"));
      pragma Assert (Form_VM.Name (Model) = "");
      Testing.Feed (Window, (Kind => Pomarine.Events.Key_Down, Key => Pomarine.Events.Key_Return, others => <>));
      pragma Assert (Form_VM.Journal (Model) = "set(abc) save(abc)");
      pragma Assert (Form_VM.Last_Saved (Model) = "abc");
      Testing.Settle (Window);
      pragma Assert (Testing.Value_Of (Window, "Name") = "");
      pragma Assert (Testing.Shows (Window, "1 saved"));
      pragma Assert (Testing.Is_Disabled (Window, "Save"));

      --  A button is as enabled as the last turn said (the widget takes no click while it is off), so
      --  one that is clicked in the very turn of the typing is not yet on; in the next turn it is.
      Form_VM.Forget_Journal (Model);
      Testing.Feed (Window, Pomarine.Events.Text_Event ("xyz"));
      pragma Assert (Testing.Is_Disabled (Window, "Save"));
      Testing.Settle (Window);
      pragma Assert (not Testing.Is_Disabled (Window, "Save"));
      Testing.Click_On (Window, "Save");
      pragma Assert (Form_VM.Journal (Model) = "set(xyz) save(xyz)");
      pragma Assert (Form_VM.Saved_Count (Model) = 2);

      --  A command that cannot be done is not done, and says nothing.
      Form_VM.Forget_Journal (Model);
      Testing.Click_On (Window, "Save");
      pragma Assert (Form_VM.Journal (Model) = "");
      pragma Assert (Form_VM.Saved_Count (Model) = 2);

      --  The command was done once, not once for each turn that saw it.
      Testing.Settle (Window, 200);
      pragma Assert (Form_VM.Saved_Count (Model) = 2);
   end A_Command_Sees_The_Edit_Before_It;

   procedure Each_Binding_Watches_Its_Own_Version is
      Tree   : aliased Widgets.Tree;
      Model  : aliased Form_VM.Model;
      Screen : UI.View (Tree'Access);
      Window : Testing.Session;
      Names  : Natural;
      States : Natural;
      Runs   : Natural;
   begin
      declare
         Bound : constant Forms.Context'Class := Forms.Bind (Screen, Model'Access);
         Part  : constant Form_Parts.Field_Part := Form_Parts.Handles_Part (Bound);
      begin
         UI.Mount (Screen, Part.Layout);
      end;
      Testing.Open (Window, Tree, 300, 200);
      Runs := Form_Parts.Runs;
      Names := Form_UI.Name_Reads;
      States := Form_UI.Status_Reads;
      Testing.Settle (Window, 100);
      Testing.Settle (Window, 100);
      pragma Assert (Form_UI.Name_Reads = Names and then Form_UI.Status_Reads = States);

      --  A change of the name alone is the name's.
      Form_VM.Change_From_Elsewhere (Model, "elsewhere");
      Testing.Settle (Window);
      pragma Assert (Form_UI.Name_Reads = Names + 1);
      pragma Assert (Form_UI.Status_Reads = States);
      pragma Assert (Testing.Value_Of (Window, "Name") = "elsewhere");
      --  What was shown by the model is not heard back as the person's word.
      pragma Assert (Form_VM.Journal (Model) = "");

      --  The same value again changes nothing.
      Form_VM.Change_From_Elsewhere (Model, "elsewhere");
      Testing.Settle (Window);
      pragma Assert (Form_UI.Name_Reads = Names + 1);

      --  A saved name is the status's.
      Testing.Click_On (Window, "Save");
      pragma Assert (Form_UI.Status_Reads = States + 1);
      pragma Assert (Testing.Shows (Window, "1 saved"));

      --  The components were not run again.
      pragma Assert (Form_Parts.Runs = Runs);
   end Each_Binding_Watches_Its_Own_Version;

   procedure Two_Models_Share_A_View is
      Tree    : aliased Widgets.Tree;
      First   : aliased Form_VM.Model;
      Second  : aliased Form_VM.Model;
      Items   : aliased Todo_VM.Model;
      Screen  : UI.View (Tree'Access);
      Window  : Testing.Session;
   begin
      Todo_VM.Seed (Items);
      declare
         Bound_1 : constant Forms.Context'Class := Forms.Bind (Screen, First'Access);
         Bound_2 : constant Forms.Context'Class := Forms.Bind (Screen, Second'Access);
         Bound_3 : constant Todo.Todo_UI.Context'Class := Todo.Todo_UI.Bind (Screen, Items'Access);
         Part_1  : constant UI.Layout := Form_Parts.Form_Part (Bound_1, "A");
         Part_2  : constant UI.Layout := Form_Parts.Form_Part (Bound_2, "B");
         Part_3  : constant UI.Layout :=
           UI.Column ([Todo.Task_Entry (Bound_3), Todo.Task_Content (Bound_3), Todo.Task_Actions (Bound_3)],
                      Height => 260.0, Gap => 8.0);
      begin
         UI.Mount (Screen, UI.Column ([Part_1, Part_2, Part_3], Gap => 4.0));
      end;
      Testing.Open (Window, Tree, 500, 700);
      pragma Assert (Testing.Is_Disabled (Window, "Save A") and then Testing.Is_Disabled (Window, "Save B"));

      Testing.Click_On (Window, "Name A");
      Testing.Type_Text (Window, "alpha");
      pragma Assert (not Testing.Is_Disabled (Window, "Save A"));
      pragma Assert (Testing.Is_Disabled (Window, "Save B"));
      pragma Assert (Form_VM.Name (First) = "alpha" and then Form_VM.Name (Second) = "");

      Testing.Click_On (Window, "Name B");
      Testing.Type_Text (Window, "beta");
      pragma Assert (Form_VM.Name (First) = "alpha" and then Form_VM.Name (Second) = "beta");

      --  The same command of two models: each button is its own model's.
      Testing.Click_On (Window, "Save B");
      pragma Assert (Form_VM.Saved_Count (Second) = 1 and then Form_VM.Saved_Count (First) = 0);
      pragma Assert (Form_VM.Journal (First) = "set(alpha)");
      Testing.Click_On (Window, "Save A");
      pragma Assert (Form_VM.Saved_Count (First) = 1 and then Form_VM.Last_Saved (First) = "alpha");
      pragma Assert (Form_VM.Last_Saved (Second) = "beta");

      --  And a model of another kind, whose commands have numbers of their own.
      Testing.Click_On (Window, "Read the Pomarine README");
      Testing.Click_On (Window, "Done");
      pragma Assert (Testing.Shows (Window, "1 of 2 left"));
      pragma Assert (Form_VM.Saved_Count (First) = 1 and then Form_VM.Saved_Count (Second) = 1);
      Testing.Click_On (Window, "Delete");
      pragma Assert (Todo_VM.Count (Items) = 1);

      --  A model that changes elsewhere is shown where it is, and only there.
      Form_VM.Change_From_Elsewhere (Second, "from outside");
      Testing.Settle (Window);
      pragma Assert (Testing.Value_Of (Window, "Name B") = "from outside");
      pragma Assert (Testing.Value_Of (Window, "Name A") = "");
   end Two_Models_Share_A_View;

   procedure A_Command_Need_Not_Be_A_Literal is
      Tree   : aliased Widgets.Tree;
      Model  : aliased Form_VM.Model;
      Screen : UI.View (Tree'Access);
      Window : Testing.Session;
   begin
      declare
         Bound : aliased constant Forms.Context'Class := Forms.Bind (Screen, Model'Access);
         Part  : aliased Forms.Component (Bound'Access);
         Typed : constant UI.Field_Handle :=
           Part.Text_Field (Form_UI.Name, Submit => Form_UI.Wipe_Name, Name => "Typed");
         Wipes : constant UI.Button_Handle := Part.Button ("Wipe", Form_UI.Wipe_Name);
         Whole : constant UI.Layout := UI.Column ([UI.Place (Typed), UI.Place (Wipes)], Gap => 8.0);
      begin
         Part.Focus_Initially (UI.Focus_Of (Typed));
         Part.Commit;
         UI.Mount (Screen, Whole);
      end;
      Testing.Open (Window, Tree, 300, 200);
      pragma Assert (Testing.Is_Disabled (Window, "Wipe"));
      Testing.Type_Text (Window, "abc");
      pragma Assert (not Testing.Is_Disabled (Window, "Wipe"));
      Testing.Click_On (Window, "Wipe");
      pragma Assert (Form_VM.Name (Model) = "" and then Testing.Value_Of (Window, "Typed") = "");
      pragma Assert (Testing.Is_Disabled (Window, "Wipe"));
      Testing.Type_Text (Window, "xyz");
      Testing.Press (Window, Pomarine.Events.Key_Return);
      pragma Assert (Form_VM.Name (Model) = "" and then Form_VM.Journal (Model) = "set(abc) set() set(xyz) set()");
   end A_Command_Need_Not_Be_A_Literal;

begin
   Ada.Text_IO.Put_Line ("The_First_Turn_Is_Before_Anyone_Can_Use_It");
   The_First_Turn_Is_Before_Anyone_Can_Use_It;
   Ada.Text_IO.Put_Line ("A_Command_Sees_The_Edit_Before_It");
   A_Command_Sees_The_Edit_Before_It;
   Ada.Text_IO.Put_Line ("Each_Binding_Watches_Its_Own_Version");
   Each_Binding_Watches_Its_Own_Version;
   Ada.Text_IO.Put_Line ("A_Command_Need_Not_Be_A_Literal");
   A_Command_Need_Not_Be_A_Literal;
   Ada.Text_IO.Put_Line ("Two_Models_Share_A_View");
   Two_Models_Share_A_View;
   Ada.Text_IO.Put_Line ("ok");
end UI_Sync_Test;
