with Ada.Text_IO;
with Pomarine.Events;
with Pomarine.Models;
with Pomarine.Testing;
with Pomarine.Widgets;
with Tasks;
with Todo;
with Todo_VM;

--  The list of the todo screen and the choice in it: a choice is of an item, the first focus, and the row
--  that is shown after one is added.
procedure UI_List_Test is
   package Testing renames Pomarine.Testing;
   package Widgets renames Pomarine.Widgets;
   use all type Todo_VM.Command;

   procedure Add (Model : in out Todo_VM.Model; Text : String) is
   begin
      Todo_VM.Set_Draft (Model, Text);
      Todo_VM.Execute (Model, Add_Task);
   end Add;

   function Detail (Model : in out Todo_VM.Model; Id : Natural) return String is
      Content : Pomarine.Models.Row_Content;
   begin
      Tasks.Describe_Row (Todo_VM.Rows (Model).all, Tasks.Find (Todo_VM.Rows (Model).all, Id), Content);
      return Pomarine.Models.Detail_Of (Content);
   end Detail;

   procedure A_Choice_Follows_Its_Item is
      Tree   : aliased Widgets.Tree;
      Model  : aliased Todo_VM.Model;
      Screen : Todo.UI.View (Tree'Access);
      Window : Testing.Session;
   begin
      Todo_VM.Seed (Model);
      Add (Model, "third");
      Add (Model, "fourth");
      Add (Model, "fifth");
      Todo.Build (Screen, Model'Access);
      Testing.Open (Window, Tree, 640, 480);
      pragma Assert (Todo_VM.Selected_Task (Model) = 0);

      --  A click on a row is the model's choice.
      Testing.Click_On (Window, "third");
      declare
         Third : constant Natural := Todo_VM.Selected_Task (Model);
      begin
         pragma Assert (Third /= 0 and then Todo_VM.Selected (Model) = 3);
         pragma Assert (Testing.Shows (Window, "list item 'third' selected"));
         pragma Assert (not Testing.Is_Disabled (Window, "Done"));

         --  Rows move: the choice stays with the item.
         Tasks.Move (Todo_VM.Rows (Model).all, 3, 1);
         Testing.Settle (Window);
         pragma Assert (Todo_VM.Selected_Task (Model) = Third and then Todo_VM.Selected (Model) = 1);
         pragma Assert (Testing.Shows (Window, "list item 'third' selected"));

         --  Another is deleted, and the row of the chosen one moves again.
         Tasks.Delete (Todo_VM.Rows (Model).all, 3);
         Testing.Settle (Window);
         pragma Assert (Todo_VM.Selected_Task (Model) = Third);
         pragma Assert (Testing.Shows (Window, "list item 'third' selected"));

         --  What the buttons do, they do to it.
         Testing.Click_On (Window, "Done");
         pragma Assert (Detail (Model, Third) = "done");
         pragma Assert (Testing.Shows (Window, "3 of 4 left") or else Testing.Shows (Window, "2 of 4 left"));

         --  It goes: the choice goes with it, and the buttons are off.
         Tasks.Delete (Todo_VM.Rows (Model).all, Tasks.Find (Todo_VM.Rows (Model).all, Third));
         Testing.Settle (Window);
         pragma Assert (Todo_VM.Selected_Task (Model) = 0 and then Todo_VM.Selected (Model) = 0);
         pragma Assert (Testing.Is_Disabled (Window, "Done") and then Testing.Is_Disabled (Window, "Delete"));
         pragma Assert (not Testing.Shows (Window, "selected"));

         --  A task that takes the place of the one that went is not chosen for it.
         Add (Model, "newcomer");
         Testing.Settle (Window);
         pragma Assert (Todo_VM.Selected_Task (Model) = 0);
         pragma Assert (not Testing.Shows (Window, "'newcomer' selected"));
      end;

      --  The model may choose too, and the list shows it.
      Todo_VM.Select_Task (Model, Tasks.Row_Id (Todo_VM.Rows (Model).all, 1));
      Testing.Settle (Window);
      pragma Assert (Testing.Shows (Window, "list item 'third'") = False);
      pragma Assert (not Testing.Is_Disabled (Window, "Delete"));
      Testing.Click_On (Window, "Delete");
      pragma Assert (Todo_VM.Selected_Task (Model) = 0);
   end A_Choice_Follows_Its_Item;

   procedure The_First_Focus_Is_The_Entry is
      Tree   : aliased Widgets.Tree;
      Model  : aliased Todo_VM.Model;
      Screen : Todo.UI.View (Tree'Access);
      Window : Testing.Session;
   begin
      Todo.Build (Screen, Model'Access);
      Testing.Open (Window, Tree, 640, 480);
      --  No click: what is typed goes to the entry, and Return adds it.
      Testing.Type_Text (Window, "straight in");
      pragma Assert (Todo_VM.Draft (Model) = "straight in");
      Testing.Press (Window, Pomarine.Events.Key_Return);
      pragma Assert (Todo_VM.Count (Model) = 1);
      pragma Assert (Testing.Shows (Window, "list item 'straight in'"));
   end The_First_Focus_Is_The_Entry;

   procedure A_Task_That_Is_Added_Is_Shown is
      Tree   : aliased Widgets.Tree;
      Model  : aliased Todo_VM.Model;
      Screen : Todo.UI.View (Tree'Access);
      Window : Testing.Session;
   begin
      for Number in 1 .. 60 loop
         Add (Model, "Task" & Number'Image);
      end loop;
      Todo.Build (Screen, Model'Access);
      Testing.Open (Window, Tree, 640, 480);
      pragma Assert (Testing.Exists (Window, "Task 1"));
      pragma Assert (not Testing.Exists (Window, "Task 60"));

      --  Added through the screen's command: the new row is brought into view.
      Testing.Type_Text (Window, "the last");
      Testing.Press (Window, Pomarine.Events.Key_Return);
      pragma Assert (Todo_VM.Count (Model) = 61);
      Testing.Settle (Window, 500);
      pragma Assert (Testing.Exists (Window, "the last"));
      pragma Assert (not Testing.Exists (Window, "Task 1"));

      --  Added by something else: no command of the screen's, so the view does not move.
      Add (Model, "unseen");
      Testing.Settle (Window, 500);
      pragma Assert (not Testing.Exists (Window, "unseen"));
   end A_Task_That_Is_Added_Is_Shown;

   procedure Names_Are_What_They_Were is
      Tree   : aliased Widgets.Tree;
      Model  : aliased Todo_VM.Model;
      Screen : Todo.UI.View (Tree'Access);
      Window : Testing.Session;
   begin
      Todo_VM.Seed (Model);
      Todo.Build (Screen, Model'Access);
      Testing.Open (Window, Tree, 640, 480);
      pragma Assert (Testing.Exists (Window, "Done") and then Testing.Exists (Window, "Delete"));
      pragma Assert (Testing.Exists (Window, "Clear done"));
      pragma Assert (Testing.Exists (Window, "Read the Pomarine README"));
      pragma Assert (Testing.Exists (Window, "Build the examples"));
      pragma Assert (Testing.Shows (Window, "2 of 2 left"));
   end Names_Are_What_They_Were;

begin
   Ada.Text_IO.Put_Line ("A_Choice_Follows_Its_Item");
   A_Choice_Follows_Its_Item;
   Ada.Text_IO.Put_Line ("The_First_Focus_Is_The_Entry");
   The_First_Focus_Is_The_Entry;
   Ada.Text_IO.Put_Line ("A_Task_That_Is_Added_Is_Shown");
   A_Task_That_Is_Added_Is_Shown;
   Ada.Text_IO.Put_Line ("Names_Are_What_They_Were");
   Names_Are_What_They_Were;
   Ada.Text_IO.Put_Line ("ok");
end UI_List_Test;
