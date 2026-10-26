with Ada.Assertions;
with Interfaces.C;
with SDL3;
with System;
with Pomarine.Dialogs;
with Pomarine.Events;
with Pomarine.Widgets.Panels;

package body Surface_Tests is
   package W renames Pomarine.Widgets;
   package E renames Pomarine.Events;
   use type E.Event_Kind;
   use type Pomarine.Dialogs.File_States;

   type Probe is new W.Panels.Panel with record
      Last : E.Event;
      Seen : Natural := 0;
   end record;
   overriding function Is_Focusable (Item : Probe) return Boolean is (True);
   overriding procedure Handle (Item : in out Probe; Event : E.Event; Handled : out Boolean);
   overriding procedure Handle (Item : in out Probe; Event : E.Event; Handled : out Boolean) is
   begin
      Item.Last := Event;
      Item.Seen := Item.Seen + 1;
      Handled := True;
   end Handle;

   --  Inject through SDL's real queue so decoding and the public event conversion are both exercised.
   type Raw_Event is array (0 .. 31) of Interfaces.Unsigned_32
     with Convention => C, Alignment => 8;
   function Push (Raw : System.Address) return Interfaces.C.C_bool
     with Import, Convention => C, External_Name => "SDL_PushEvent";
   procedure Set_Modifiers (Mask : Interfaces.Unsigned_16)
     with Import, Convention => C, External_Name => "SDL_SetModState";

   procedure Input is
      Tree : W.Tree;
      Root : aliased W.Panels.Panel;
      First, Second : aliased Probe;
      Handled : Boolean;
      Raw : aliased Raw_Event := [others => 0];
      Event : E.Event;
      Found : Boolean;
      use type E.Key_Code;
   begin
      SDL3.Initialize;
      while E.Poll (Event) loop
         null;
      end loop;
      Raw (0) := 16#301#; -- SDL_EVENT_KEY_UP
      Raw (7) := Interfaces.Unsigned_32 (E.Key_A);
      Raw (8) := 16#0FC3#; -- GUI, Control, Alt and Shift in the key's own modifier mask
      pragma Assert (Boolean (Push (Raw'Address)));
      Found := E.Wait (Event, Timeout_MS => 100);
      pragma Assert (Found and then Event.Kind = E.Key_Up and then Event.Key = E.Key_A);
      pragma Assert (Event.Command and then Event.Control and then Event.Option and then Event.Shift);
      Set_Modifiers (16#0FC3#);
      Raw := [others => 0];
      Raw (0) := 16#403#; -- SDL_EVENT_MOUSE_WHEEL
      pragma Assert (Boolean (Push (Raw'Address)));
      Found := E.Wait (Event, Timeout_MS => 100);
      pragma Assert (Found and then Event.Kind = E.Mouse_Wheel);
      pragma Assert (Event.Command and then Event.Control and then Event.Option and then Event.Shift);
      Set_Modifiers (0);

      W.Set_Root (Tree, Root);
      W.Add (Root, First, Second);
      W.Focus (First);
      W.Dispatch (Tree, (Kind => E.Key_Up, Key => E.Key_Tab, Shift => True, others => <>), Handled);
      pragma Assert (Handled and then First.Last.Kind = E.Key_Up and then First.Last.Shift);
      pragma Assert (W.Has_Focus (First)); -- key-up does not move focus

      W.Capture_Pointer (First);
      W.Dispatch (Tree, (Kind => E.Mouse_Move, Mouse_X => -100.0, others => <>), Handled);
      pragma Assert (Handled and then First.Last.Mouse_X = -100.0 and then W.Has_Pointer_Capture (First));
      W.Dispatch (Tree, (Kind => E.Mouse_Up, Button => 1, others => <>), Handled);
      pragma Assert (W.Has_Pointer_Capture (First)); -- explicit capture survives a release
      W.Capture_Pointer (Second, Button => 3);
      W.Release_Pointer (First); -- cannot release somebody else's capture
      pragma Assert (W.Has_Pointer_Capture (Second) and then not W.Has_Pointer_Capture (First));
      W.Dispatch (Tree, (Kind => E.Mouse_Up, Button => 1, others => <>), Handled);
      pragma Assert (W.Has_Pointer_Capture (Second));
      W.Dispatch (Tree, (Kind => E.Mouse_Up, Button => 3, others => <>), Handled);
      pragma Assert (not W.Has_Pointer_Capture (Second));
      W.Capture_Pointer (First);
      W.Set_Visible (Root, False);
      pragma Assert (not W.Has_Pointer_Capture (First));
      W.Set_Visible (Root, True);
      W.Capture_Pointer (First);
      W.Remove (First);
      pragma Assert (not W.Has_Pointer_Capture (First));
      W.Release_Pointer (First); -- detached is safe
      W.Capture_Pointer (Second);
      W.Release_Pointer (Second);
      pragma Assert (not W.Has_Pointer_Capture (Second));

      Pomarine.Dialogs.Reset_File;
      pragma Assert (Pomarine.Dialogs.File_State = Pomarine.Dialogs.Idle);
      begin
         declare
            Unavailable : constant String := Pomarine.Dialogs.File_Path;
         begin
            pragma Assert (Unavailable'Length = 0);
         end;
         raise Program_Error with "File_Path must reject Idle";
      exception
         when Ada.Assertions.Assertion_Error => null;
      end;
   end Input;
end Surface_Tests;
