with Ada.Text_IO;
with Pomarine.Events;
with Pomarine.Testing;
with Pomarine.UI;
with Pomarine.Widgets;
with Form_Parts;
with Form_UI;
with Form_VM;
with Reentry;

--  What happens when something arrives while the view is synchronizing, and when the person and the model both
--  change the same text in one turn.

procedure UI_Reentry_Test is
   package UI renames Pomarine.UI;
   package Testing renames Pomarine.Testing;
   package Widgets renames Pomarine.Widgets;
   package Forms renames Form_UI.Forms;

   procedure Work_Waits_For_The_Pass is
      Tree   : aliased Widgets.Tree;
      Model  : aliased Form_VM.Model;
      Screen : aliased UI.View (Tree'Access);
      Window : aliased Testing.Session;
   begin
      declare
         Bound : constant Forms.Context'Class := Forms.Bind (Screen, Model'Access);
         Part  : constant Form_Parts.Field_Part := Form_Parts.Handles_Part (Bound);
      begin
         UI.Mount (Screen, Part.Layout);
      end;
      Testing.Open (Window, Tree, 300, 200);
      Reentry.Window := Window'Unchecked_Access;
      Reentry.Screen := Screen'Unchecked_Access;
      Form_VM.Inside_Save := Reentry.Press_Return'Access;

      Testing.Feed (Window, Pomarine.Events.Text_Event ("abc"));
      Testing.Feed (Window, (Kind => Pomarine.Events.Key_Down, Key => Pomarine.Events.Key_Return, others => <>));
      Form_VM.Inside_Save := null;

      --  The Return made in the middle of the save was not run inside it (which would have saved twice, the
      --  name not being cleared yet): the tree, which was delivering, kept it for after.
      pragma Assert (UI.Queued_Events (Screen) = 0);
      pragma Assert (Form_VM.Journal (Model) = "set(abc) save(abc)");
      pragma Assert (Form_VM.Saved_Count (Model) = 1);
      Testing.Settle (Window);
      pragma Assert (Form_VM.Saved_Count (Model) = 1);
   end Work_Waits_For_The_Pass;

   procedure Edits_Are_Collected_Before_Work_That_Comes_In_Meanwhile is
      Tree   : aliased Widgets.Tree;
      Model  : aliased Form_VM.Model;
      Screen : aliased UI.View (Tree'Access);
      Window : aliased Testing.Session;
   begin
      declare
         Bound : constant Forms.Context'Class := Forms.Bind (Screen, Model'Access);
         Part  : constant Form_Parts.Field_Part := Form_Parts.Handles_Part (Bound);
      begin
         UI.Mount (Screen, Part.Layout);
      end;
      Testing.Open (Window, Tree, 300, 200);
      Reentry.Window := Window'Unchecked_Access;
      Reentry.Screen := Screen'Unchecked_Access;
      Testing.Feed (Window, Pomarine.Events.Text_Event ("abc"));
      --  The view is told of the typing in its next pass; that pass, in the middle of giving the model the
      --  text, has a Return come in: it waits for the pass to be done, and then is a turn of its own.
      Form_VM.Inside_Set := Reentry.Press_Return'Access;
      Testing.Settle (Window);
      Form_VM.Inside_Set := null;
      pragma Assert (Reentry.Queued_Seen = 1);
      pragma Assert (UI.Queued_Events (Screen) = 0);
      pragma Assert (Form_VM.Journal (Model) = "set(abc) save(abc)");
      pragma Assert (Form_VM.Saved_Count (Model) = 1);
   end Edits_Are_Collected_Before_Work_That_Comes_In_Meanwhile;

   procedure A_Model_That_Fails_Does_Not_Wedge_The_View is
      Tree   : aliased Widgets.Tree;
      Model  : aliased Form_VM.Model;
      Screen : aliased UI.View (Tree'Access);
      Window : aliased Testing.Session;
      Failed : Boolean := False;
   begin
      declare
         Bound : constant Forms.Context'Class := Forms.Bind (Screen, Model'Access);
         Part  : constant Form_Parts.Field_Part := Form_Parts.Handles_Part (Bound);
      begin
         UI.Mount (Screen, Part.Layout);
      end;
      Testing.Open (Window, Tree, 300, 200);
      Reentry.Window := Window'Unchecked_Access;
      Reentry.Screen := Screen'Unchecked_Access;
      Form_VM.Inside_Save := Reentry.Fail'Access;
      Testing.Type_Text (Window, "abc");
      begin
         Testing.Press (Window, Pomarine.Events.Key_Return);
      exception
         when Program_Error =>
            Failed := True;
      end;
      Form_VM.Inside_Save := null;
      pragma Assert (Failed);
      pragma Assert (UI.Queued_Events (Screen) = 0);
      --  The view goes on: the next turn is a turn, and the next command is done.
      Testing.Settle (Window);
      Testing.Press (Window, Pomarine.Events.Key_Return);
      pragma Assert (Form_VM.Saved_Count (Model) = 1);
   end A_Model_That_Fails_Does_Not_Wedge_The_View;

   procedure The_Person_And_The_Model_Edit_At_Once is
      Tree   : aliased Widgets.Tree;
      Model  : aliased Form_VM.Model;
      Screen : aliased UI.View (Tree'Access);
      Window : aliased Testing.Session;
   begin
      declare
         Bound : constant Forms.Context'Class := Forms.Bind (Screen, Model'Access);
         Part  : constant Form_Parts.Field_Part := Form_Parts.Handles_Part (Bound);
      begin
         UI.Mount (Screen, Part.Layout);
      end;
      Testing.Open (Window, Tree, 300, 200);
      --  In one turn, the person types and something else changes the text.
      Testing.Feed (Window, Pomarine.Events.Text_Event ("typed"));
      Form_VM.Change_From_Elsewhere (Model, "other");
      Testing.Settle (Window);
      --  The person's edit is the model's first, then the model's word is shown: here, the same.
      pragma Assert (Form_VM.Name (Model) = "typed");
      pragma Assert (Testing.Value_Of (Window, "Name") = "typed");
      pragma Assert (Form_VM.Journal (Model) = "set(typed)");

      --  Where the model says it another way, it is that way that is shown.
      Form_VM.Shouting (Model);
      Testing.Feed (Window, Pomarine.Events.Text_Event ("!"));
      Testing.Settle (Window);
      pragma Assert (Form_VM.Name (Model) = "TYPED!");
      pragma Assert (Testing.Value_Of (Window, "Name") = "TYPED!");
   end The_Person_And_The_Model_Edit_At_Once;

begin
   Ada.Text_IO.Put_Line ("Work_Waits_For_The_Pass");
   Work_Waits_For_The_Pass;
   Ada.Text_IO.Put_Line ("Edits_Are_Collected_Before_Work_That_Comes_In_Meanwhile");
   Edits_Are_Collected_Before_Work_That_Comes_In_Meanwhile;
   Ada.Text_IO.Put_Line ("A_Model_That_Fails_Does_Not_Wedge_The_View");
   A_Model_That_Fails_Does_Not_Wedge_The_View;
   Ada.Text_IO.Put_Line ("The_Person_And_The_Model_Edit_At_Once");
   The_Person_And_The_Model_Edit_At_Once;
   Ada.Text_IO.Put_Line ("ok");
end UI_Reentry_Test;
