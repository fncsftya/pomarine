with Pomarine.Widgets.Nodes;
with Pomarine.Widgets.Focusing;
package body Pomarine.Widgets.Dispatching is

   use Pomarine.Widgets.Nodes;
   use type Interfaces.Unsigned_32;
   use type Pomarine.Events.Event_Kind;
   use type Pomarine.Events.Milliseconds;
   use Pomarine.Widgets.Focusing;

   Wheel_Stickiness : constant Pomarine.Events.Milliseconds := 300;
   --  How soon after a wheel turn the next still goes to the same widget.

   function Hit_Slot (Item : Tree; X, Y : Float) return Node_Index is
      Table : Node_Table renames Item.Nodes.all;
      Found : Node_Index := 0;
      Level : Node_Index := Item.Root;
   begin
      --  Down through the last child that has the point, at each level.
      while Level /= 0 loop
         declare
            Box : Spot renames Table.Spot (Level);
         begin
            exit when not Box.Visible
              or else X < Box.Left or else X >= Box.Left + Box.Wide
              or else Y < Box.Top or else Y >= Box.Top + Box.High;
         end;
         Found := Level;
         declare
            Child : Node_Index := Table.First (Level);
         begin
            Level := 0;
            while Child /= 0 loop
               declare
                  Box : Spot renames Table.Spot (Child);
               begin
                  if Box.Visible
                    and then X >= Box.Left and then X < Box.Left + Box.Wide
                    and then Y >= Box.Top and then Y < Box.Top + Box.High
                  then
                     Level := Child;
                  end if;
               end;
               Child := Table.Next (Child);
            end loop;
         end;
      end loop;
      return Found;
   end Hit_Slot;

   procedure Bubble
     (Home    : Tree;
      From    : Node_Index;
      Event   : Pomarine.Events.Event;
      Taker   : out Node_Index)
   is
      Offered : Node_Index := From;
      Handled : Boolean;
   begin
      Taker := 0;
      while Offered /= 0 loop
         Handle (Home.Nodes.Object (Offered).all, Event, Handled);
         if Handled then
            Taker := Offered;
            return;
         end if;
         Offered := Home.Nodes.Parent (Offered);
      end loop;
   end Bubble;

   function Accepting (Home : Tree; From : Node_Index) return Node_Index is
      Climbing : Node_Index := From;
   begin
      while Climbing /= 0
        and then not Focuses_On_Click (Home.Nodes.Object (Climbing).all)
      loop
         Climbing := Home.Nodes.Parent (Climbing);
      end loop;
      return Climbing;
   end Accepting;

   procedure Dispatch_Press
     (Item    : in out Tree;
      Event   : Pomarine.Events.Event;
      Over    : Node_Index;
      Handled : out Boolean)
   is
      Accepts : constant Node_Index := Accepting (Item, Over);
      Taker   : Node_Index;
   begin
      if Accepts /= 0 then
         Set_Focus (Item, Accepts);
      end if;
      Bubble (Item, Over, Event, Taker);
      Handled := Taker /= 0;
      if Taker /= 0 then
         Item.Capture := Taker;
         Item.Capture_Button := Event.Button;
      elsif Accepts = 0 and then Item.Focus /= 0 then
         --  A click elsewhere takes the focus away.
         Set_Focus (Item, 0);
         Handled := True;
      end if;
   end Dispatch_Press;

   procedure Set_Input_Source (Item : in out Tree; Keyboard : Boolean) is
   begin
      if Item.Keyboard_Focus /= Keyboard then
         Item.Keyboard_Focus := Keyboard;
         if Item.Focus /= 0 then
            Invalidate (Item.Nodes.Object (Item.Focus).all);
         end if;
      end if;
   end Set_Input_Source;

   procedure Dispatch_Keys
     (Item    : in out Tree;
      Event   : Pomarine.Events.Event;
      Handled : out Boolean)
   is
      Taker   : Node_Index;
      Offered : Node_Index;
   begin
      if Event.Kind = Pomarine.Events.Key_Down then
         Set_Input_Source (Item, Keyboard => True);
      end if;
      Bubble (Item, Item.Focus, Event, Taker);
      Handled := Taker /= 0;
      if not Handled and then Event.Kind = Pomarine.Events.Key_Down then
         Offered := Item.Root;
         while Offered /= 0 and then not Handled loop
            if Item.Nodes.Spot (Offered).Visible then
               Handle (Item.Nodes.Object (Offered).all, Event, Handled);
            end if;
            Offered := Following_Shown (Item, Offered);
         end loop;
      end if;
      --  Tab, when the tree is to move the focus by it.
      if not Handled and then Item.Tab_Moves and then Event.Kind = Pomarine.Events.Key_Down
        and then Event.Key = Pomarine.Events.Key_Tab and then not Event.Command
      then
         Focus_Next (Item, Backwards => Event.Shift);
         Handled := True;
      end if;
      --  Keys that none of the widgets took, that the application has
      --  bound to commands.
      if not Handled and then Event.Kind = Pomarine.Events.Key_Down then
         for Each of Item.Keys (1 .. Item.Keys_Bound) loop
            if Each.Key = Event.Key and then Each.Command = Event.Command
              and then Each.Shift = Event.Shift
            then
               Perform_Command (Item, Each.Tag, Handled);
               exit;
            end if;
         end loop;
      end if;
   end Dispatch_Keys;

   procedure Dispatch_Event
     (Item    : in out Tree;
      Event   : Pomarine.Events.Event;
      Handled : out Boolean)
   is
      Over  : Node_Index;
      Taker : Node_Index;
   begin
      Handled := False;
      case Event.Kind is
         when Pomarine.Events.Mouse_Down =>
            Set_Input_Source (Item, Keyboard => False);
            Over := Hit_Slot (Item, Event.Mouse_X * Item.Density,
                              Event.Mouse_Y * Item.Density);
            Dispatch_Press (Item, Event, Over, Handled);

         when Pomarine.Events.Mouse_Move | Pomarine.Events.Mouse_Up =>
            Over := Hit_Slot (Item, Event.Mouse_X * Item.Density,
                              Event.Mouse_Y * Item.Density);
            Set_Hover (Item, Over);
            if Item.Capture /= 0 then
               Handle (Item.Nodes.Object (Item.Capture).all, Event, Handled);
               if Event.Kind = Pomarine.Events.Mouse_Up
                 and then Event.Button = Item.Capture_Button
               then
                  Item.Capture := 0;
               elsif Event.Kind = Pomarine.Events.Mouse_Move
                 and then Item.Capture_Button = 1
                 and then not Event.Left_Held
               then
                  Item.Capture := 0;  --  let go where it was not seen
               end if;
            else
               Bubble (Item, Over, Event, Taker);
               Handled := Taker /= 0;
            end if;

         when Pomarine.Events.Mouse_Wheel | Pomarine.Events.Pinch =>
            Over := Hit_Slot (Item, Event.Mouse_X * Item.Density,
                              Event.Mouse_Y * Item.Density);
            if Event.Kind = Pomarine.Events.Mouse_Wheel
              and then Item.Wheel_Taker /= 0
              and then Event.Time > 0
              and then Event.Time >= Item.Wheel_Time
              and then Event.Time - Item.Wheel_Time <= Wheel_Stickiness
            then
               --  Still turning what it was turning.
               Over := Item.Wheel_Taker;
            end if;
            Bubble (Item, Over, Event, Taker);
            Handled := Taker /= 0;
            if Event.Kind = Pomarine.Events.Mouse_Wheel then
               Item.Wheel_Taker := Taker;
               Item.Wheel_Time := Event.Time;
            end if;

         when Pomarine.Events.Key_Down | Pomarine.Events.Text_Input
            | Pomarine.Events.Text_Editing =>
            Dispatch_Keys (Item, Event, Handled);

         when Pomarine.Events.Quit | Pomarine.Events.Redraw
            | Pomarine.Events.Theme_Changed | Pomarine.Events.Other =>
            null;
      end case;
      Deliver (Item);
   end Dispatch_Event;

   function Cursor_Wanted (Item : Tree) return SDL3.Cursors.Kind is
      use type SDL3.Cursors.Kind;
      Asking : Node_Index :=
        (if Item.Capture /= 0 then Item.Capture else Item.Hover);
   begin
      while Asking /= 0 loop
         if Cursor (Item.Nodes.Object (Asking).all) /= SDL3.Cursors.Default then
            return Cursor (Item.Nodes.Object (Asking).all);
         end if;
         Asking := (if Item.Capture /= 0 then 0 else Item.Nodes.Parent (Asking));
      end loop;
      return SDL3.Cursors.Default;
   end Cursor_Wanted;

end Pomarine.Widgets.Dispatching;
