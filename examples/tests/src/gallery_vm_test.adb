with Gallery_VM;

--  The gallery's model alone, as its commands' contracts say, with no widgets.

procedure Gallery_VM_Test is
   use Gallery_VM;
   State : Gallery_VM.Model;
begin
   Seed (State);
   pragma Assert (Count (State) = 4);
   pragma Assert (Can_Execute (State, Click_Me));
   pragma Assert (not Can_Execute (State, Click_Me, 1));
   pragma Assert (not Can_Execute (State, Reset));
   pragma Assert (not Can_Execute (State, Remove_Chosen));
   pragma Assert (not Can_Execute (State, Pick_Size, 0));
   pragma Assert (not Can_Execute (State, Pick_Size, Size_Count + 1));
   pragma Assert (Can_Execute (State, Pick_Size, Size_Count));

   --  Progress fills at Full_At clicks and stays full.
   pragma Assert (Progress (State) = 0.0);
   for Tap in 1 .. Full_At + 5 loop
      Execute (State, Click_Me);
   end loop;
   pragma Assert (Progress (State) = 1.0);
   pragma Assert (Can_Execute (State, Reset));
   Execute (State, Reset);
   pragma Assert (Clicks (State) = 0 and then Summary (State) = "Clicked 0 times");

   --  One size at a time.
   Execute (State, Pick_Size, 1);
   pragma Assert (Is_Size (State, 1) and then not Is_Size (State, 2) and then Size (State) = 1);

   --  A change is a new version, and setting what it has is not.
   declare
      Before : constant Natural := Natural (Version (State));
   begin
      Set_Notify (State, False);
      pragma Assert (Natural (Version (State)) = Before);
      Set_Notify (State, True);
      pragma Assert (Natural (Version (State)) /= Before);
   end;

   --  The choice is of the item, and goes with its removal.
   Select_Row (State, 2);
   pragma Assert (Selected (State) = 2 and then Can_Execute (State, Remove_Chosen));
   Execute (State, Remove_Chosen);
   pragma Assert (Count (State) = 3 and then Selected (State) = 0 and then Selected_Item (State) = 0);
   pragma Assert (Greeting (State) = "Hello, stranger!");
   Set_Name (State, "Ada");
   pragma Assert (Greeting (State) = "Hello, Ada!");
end Gallery_VM_Test;
