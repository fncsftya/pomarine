with Ada.Assertions;
with Todo_VM;
with Tasks;
with Pomarine.View_Models;

procedure Todo_VM_Test is
   use Todo_VM;
   use type Pomarine.View_Models.Version_Number;
   Item : Model;
   Before : Pomarine.View_Models.Version_Number;
   Refused : Boolean := False;
begin
   pragma Assert (not Can_Execute (Item, Add_Task));
   pragma Assert (not Can_Execute (Item, Remove_Chosen));
   pragma Assert (not Can_Execute (Item, Sweep_Done));
   begin
      Commands.Execute (Commands.Model'Class (Item), Add_Task);
   exception
      when Ada.Assertions.Assertion_Error => Refused := True;
   end;
   pragma Assert (Refused);
   Before := Version (Item);
   Set_Draft (Item, "");
   Select_Row (Item, 0);
   pragma Assert (Version (Item) = Before);
   Set_Draft (Item, [1 .. 10_000 => 'x']);
   Before := Version (Item);
   Set_Draft (Item, Draft (Item));
   pragma Assert (Version (Item) = Before);
   Execute (Item, Add_Task);
   pragma Assert (Count (Item) = 1 and then Draft (Item) = "");
   Select_Row (Item, 1);
   pragma Assert (Can_Execute (Item, Toggle_Chosen));
   Execute (Item, Toggle_Chosen);
   pragma Assert (Summary (Item) = " 0 of 1 left");
   Execute (Item, Sweep_Done);
   pragma Assert (Count (Item) = 0 and then Selected (Item) = 0);
   for I in 1 .. 300 loop
      Set_Draft (Item, I'Image);
      Execute (Item, Add_Task);
   end loop;
   declare
      Old_Id : constant Positive := Tasks.Row_Id (Rows (Item).all, 1);
   begin
      Select_Row (Item, 1);
      Execute (Item, Remove_Chosen);
      pragma Assert (Selected (Item) = 0);
      pragma Assert (Tasks.Row_Id (Rows (Item).all, 1) /= Old_Id);
   end;
   pragma Assert (Count (Item) = 299);
   pragma Assert (not Can_Execute (Item, Add_Task, 1));

   --  A choice is of a task, not of a row.
   declare
      Other : Model;
      Held  : constant not null access Tasks.Task_List := Todo_VM.Rows (Other);
      Chosen : Natural;
      Was   : Pomarine.View_Models.Version_Number;
   begin
      Seed (Other);
      Set_Draft (Other, "third");
      Execute (Other, Add_Task);
      Select_Row (Other, 3);
      Chosen := Selected_Task (Other);
      pragma Assert (Chosen = Tasks.Row_Id (Held.all, 3) and then Selected (Other) = 3);

      --  Rows move, or others go: the same task.
      Tasks.Move (Held.all, 3, 1);
      pragma Assert (Selected_Task (Other) = Chosen and then Selected (Other) = 1);
      Tasks.Delete (Held.all, 2);
      pragma Assert (Selected_Task (Other) = Chosen and then Selected (Other) = 1);
      pragma Assert (Can_Execute (Other, Toggle_Chosen));

      --  The model's version knows of changes made to the rows, for a view that reads it.
      Was := Version (Other);
      Tasks.Toggle (Held.all, 1);
      pragma Assert (Version (Other) /= Was);

      --  It goes: no row has it, and the one that takes its row's place is not it.
      Tasks.Delete (Held.all, 1);
      pragma Assert (Selected (Other) = 0 and then not Can_Execute (Other, Toggle_Chosen));
      Set_Draft (Other, "newcomer");
      Execute (Other, Add_Task);
      pragma Assert (Selected (Other) = 0 and then Selected_Task (Other) = Chosen);
      pragma Assert (Tasks.Find (Held.all, Chosen) = 0);
      Select_Task (Other, 0);
      pragma Assert (Selected_Task (Other) = 0);
   end;

   --  Rows are found by id quickly while they are in order and still when they are not.
   declare
      List : Tasks.Task_List;
   begin
      for Number in 1 .. 1_000 loop
         Tasks.Add (List, Number'Image);
      end loop;
      pragma Assert (Tasks.Find (List, 1) = 1 and then Tasks.Find (List, 1_000) = 1_000);
      pragma Assert (Tasks.Find (List, 0) = 0 and then Tasks.Find (List, 1_001) = 0);
      Tasks.Delete (List, 10);
      pragma Assert (Tasks.Find (List, 10) = 0 and then Tasks.Find (List, 11) = 10);
      Tasks.Move (List, 500, 1);
      pragma Assert (Tasks.Find (List, 501) = 1 and then Tasks.Find (List, 1) = 2);
      pragma Assert (Tasks.Find (List, 999) = 998 or else Tasks.Find (List, 999) = 999);
   end;
end Todo_VM_Test;
