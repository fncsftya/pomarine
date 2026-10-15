with SDL3.Events;
with SDL3.Windows.Renderers;
with Goldens;
with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Callbacks;
with Pomarine.Widgets.Checks;
with Pomarine.Widgets.Panels;
with Yoga.Nodes;

package body Command_Tests is

   package Widgets renames Pomarine.Widgets;
   package Events renames SDL3.Events;
   package Renderers renames SDL3.Windows.Renderers;
   package Nodes renames Yoga.Nodes;

   use type Widgets.Command_State;

   --  Who heard what

   type Ears is limited new Widgets.Listener with record
      Count : Natural := 0;
      Last_Tag : Integer := Widgets.No_Tag;
   end record;

   overriding procedure Handle_Event
     (Self   : in out Ears;
      Source : in out Widgets.Widget'Class;
      Event  : Widgets.Widget_Event) is
      pragma Unreferenced (Source);
   begin
      Self.Count := Self.Count + 1;
      Self.Last_Tag := Event.Tag;
   end Handle_Event;

   type Counter is limited record
      Clicks : Natural := 0;
      Kind   : Widgets.Event_Kind := Widgets.Close;
   end record;

   procedure Clicked
     (Self   : in out Counter;
      Source : in out Widgets.Widget'Class;
      Event  : Widgets.Widget_Event) is
      pragma Unreferenced (Source);
   begin
      Self.Clicks := Self.Clicks + 1;
      Self.Kind := Event.Kind;
   end Clicked;

   package Counter_Callbacks is new Widgets.Callbacks (Counter);

   --  A widget that takes a command, to be offered to

   type Taker is new Widgets.Widget with record
      Took : Natural := 0;
   end record;

   overriding function Accepts_Focus (Item : Taker) return Boolean is (True);

   overriding procedure Handle_Command
     (Item : in out Taker; Tag : Integer; Done : out Boolean) is
   begin
      Done := Tag = 9;
      if Done then
         Item.Took := Item.Took + 1;
      end if;
   end Handle_Command;

   type Fixture is limited record
      Tree   : Widgets.Tree;
      Target : Renderers.Renderer;
      Heard  : aliased Ears;
      Root   : aliased Widgets.Panels.Panel;
      First  : aliased Widgets.Buttons.Button;
      Second : aliased Widgets.Buttons.Button;
      Box    : aliased Widgets.Checks.Check;
      Field  : aliased Taker;
   end record;

   procedure Open (Item : in out Fixture) is
   begin
      Renderers.Create_Offscreen (Item.Target, 300, 100);
      Widgets.Set_Listener (Item.Tree, Item.Heard'Unchecked_Access);
      Widgets.Set_Root (Item.Tree, Item.Root);
      Widgets.Add (Item.Root, Item.First, Item.Second, Item.Box);
      Widgets.Add (Item.Root, Item.Field);
      Widgets.Buttons.Set_Label (Item.First, "One");
      Widgets.Buttons.Set_Label (Item.Second, "Two");
      Widgets.Checks.Set_Label (Item.Box, "Three");
      Nodes.Set_Flex_Direction (Widgets.Node (Item.Root), Yoga.Row);
      Nodes.Set_Width (Widgets.Node (Item.First), 80.0);
      Nodes.Set_Width (Widgets.Node (Item.Second), 80.0);
      Nodes.Set_Width (Widgets.Node (Item.Box), 80.0);
      Nodes.Set_Width (Widgets.Node (Item.Field), 20.0);
      Widgets.Layout (Item.Tree, Item.Target);
   end Open;

   procedure Click_At (Item : in out Fixture; X : Float) is
      Handled : Boolean;
   begin
      Widgets.Dispatch
        (Item.Tree, (Kind => Events.Mouse_Move, Mouse_X => X, Mouse_Y => 10.0, others => <>), Handled);
      Widgets.Dispatch
        (Item.Tree,
         (Kind => Events.Mouse_Down, Mouse_X => X, Mouse_Y => 10.0, Button => 1, others => <>), Handled);
      Widgets.Dispatch
        (Item.Tree,
         (Kind => Events.Mouse_Up, Mouse_X => X, Mouse_Y => 10.0, Button => 1, others => <>), Handled);
   end Click_At;

   procedure Own_Handlers is
      Item  : Fixture;
      Mine  : aliased Counter;
   begin
      Open (Item);
      Counter_Callbacks.On (Item.First, Widgets.Click, Mine'Access, Clicked'Access);
      Click_At (Item, 40.0);
      Click_At (Item, 40.0);
      --  The other button has none: its click goes to the listener.
      Click_At (Item, 120.0);
      Goldens.Check_Text
        ("commands-own-handler", "2 CLICK listener 1",
         Mine.Clicks'Image (2 .. 2) & " " & Mine.Kind'Image & " listener" & Item.Heard.Count'Image);

      Counter_Callbacks.Off (Item.First, Widgets.Click);
      Click_At (Item, 40.0);
      Goldens.Check_Text ("commands-handler-off", "2 listener 2",
                          Mine.Clicks'Image (2 .. 2) & " listener" & Item.Heard.Count'Image);
   end Own_Handlers;

   procedure Losing_Focus is
      Item : Fixture;
      Mine : aliased Counter;
   begin
      Open (Item);
      Widgets.Buttons.Set_Focusable (Item.First, True);
      Widgets.Checks.Set_Focusable (Item.Box, True);
      Counter_Callbacks.On (Item.Box, Widgets.Blur, Mine'Access, Clicked'Access);
      Widgets.Focus (Item.Box);
      Goldens.Check_Text ("commands-blur-not-yet", "0", Mine.Clicks'Image (2 .. 2));
      Widgets.Focus (Item.First);
      Goldens.Check_Text
        ("commands-blur", "1 BLUR listener 0",
         Mine.Clicks'Image (2 .. 2) & " " & Mine.Kind'Image & " listener" & Item.Heard.Count'Image);
      --  A widget without one says nothing of it: nor to the listener.
      Widgets.Focus (Item.Box);
      Goldens.Check_Text ("commands-blur-silent", "listener 0", "listener" & Item.Heard.Count'Image);
      Widgets.Clear_Focus (Item.Tree);
      Goldens.Check_Text ("commands-blur-cleared", "2", Mine.Clicks'Image (2 .. 2));
   end Losing_Focus;

   Save_Tag  : constant := 1;
   Undo_Tag  : constant := 2;
   Pin_Tag   : constant := 3;
   Fold_Tag  : constant := 4;

   Offering : Widgets.Command_State := Widgets.Enabled;
   Pinned   : Widgets.Command_State := Widgets.Enabled;
   Folding  : Widgets.Command_State := Widgets.Enabled;

   function State_Of (Tag : Integer) return Widgets.Command_State is
     (case Tag is
         when Save_Tag => Offering,
         when Pin_Tag  => Pinned,
         when Fold_Tag => Folding,
         when others   => Widgets.Enabled);

   procedure Validated is
      Item : Fixture;
   begin
      Open (Item);
      Widgets.Set_Tag (Item.First, Save_Tag);
      Widgets.Set_Tag (Item.Second, Pin_Tag);
      Widgets.Set_Tag (Item.Box, Fold_Tag);
      Widgets.Set_Validator (Item.Tree, State_Of'Access);

      Offering := Widgets.Disabled;
      Pinned := Widgets.Ticked;
      Folding := Widgets.Not_Offered;
      Widgets.Update (Item.Tree, 0);
      Goldens.Check_Text
        ("commands-validated", "FALSE TRUE FALSE",
         Widgets.Buttons.Is_Enabled (Item.First)'Image & " "
         & Widgets.Buttons.Is_Selected (Item.Second)'Image & " "
         & Widgets.Is_Visible (Item.Box)'Image);

      --  A disabled button is not clicked.
      Click_At (Item, 40.0);
      Goldens.Check_Text ("commands-disabled-no-click", "0", Item.Heard.Count'Image (2 .. 2));

      --  What was in force is not, and what was hidden is shown again.
      Offering := Widgets.Enabled;
      Pinned := Widgets.Enabled;
      Folding := Widgets.Enabled;
      Widgets.Update (Item.Tree, 0);
      Goldens.Check_Text
        ("commands-validated-back", "TRUE FALSE TRUE",
         Widgets.Buttons.Is_Enabled (Item.First)'Image & " "
         & Widgets.Buttons.Is_Selected (Item.Second)'Image & " "
         & Widgets.Is_Visible (Item.Box)'Image);
   end Validated;

   procedure Keys is
      Item    : Fixture;
      Handled : Boolean;
   begin
      Open (Item);
      Widgets.Bind_Key (Item.Tree, Events.Key_S, Command => True, Tag => Save_Tag);
      Widgets.Bind_Key (Item.Tree, Events.Key_Z, Command => True, Shift => True, Tag => Undo_Tag);

      Widgets.Dispatch
        (Item.Tree, (Kind => Events.Key_Down, Key => Events.Key_S, Command => True, others => <>), Handled);
      Goldens.Check_Text ("commands-key", "TRUE 1 1",
                          Handled'Image & Item.Heard.Count'Image & Item.Heard.Last_Tag'Image);

      --  Another key, or not the same modifiers, is not that command.
      Widgets.Dispatch
        (Item.Tree, (Kind => Events.Key_Down, Key => Events.Key_S, others => <>), Handled);
      Widgets.Dispatch
        (Item.Tree, (Kind => Events.Key_Down, Key => Events.Key_Z, Command => True, others => <>), Handled);
      Goldens.Check_Text ("commands-key-not", "FALSE 1", Handled'Image & Item.Heard.Count'Image);

      Widgets.Dispatch
        (Item.Tree, (Kind => Events.Key_Down, Key => Events.Key_Z, Command => True, Shift => True, others => <>),
         Handled);
      Goldens.Check_Text ("commands-key-shift", "TRUE 2 2",
                          Handled'Image & Item.Heard.Count'Image & Item.Heard.Last_Tag'Image);

      --  Bound again, it does the new.
      Widgets.Bind_Key (Item.Tree, Events.Key_S, Command => True, Tag => Pin_Tag);
      Widgets.Dispatch
        (Item.Tree, (Kind => Events.Key_Down, Key => Events.Key_S, Command => True, others => <>), Handled);
      Goldens.Check_Text ("commands-key-rebound", "3", Item.Heard.Last_Tag'Image (2 .. 2));
   end Keys;

   procedure Responders is
      Item : Fixture;
      Done : Boolean;
   begin
      Open (Item);
      --  With no focus there is only the listener.
      Widgets.Perform_Command (Item.Tree, 9, Done);
      Widgets.Deliver (Item.Tree);
      Goldens.Check_Text ("commands-unfocused", "TRUE 0 1",
                          Done'Image & Item.Field.Took'Image & Item.Heard.Count'Image);

      --  With the focus on a widget that takes it, it is not the listener's.
      Widgets.Focus (Item.Field);
      Widgets.Perform_Command (Item.Tree, 9, Done);
      Widgets.Deliver (Item.Tree);
      Goldens.Check_Text ("commands-taken", "TRUE 1 1",
                          Done'Image & Item.Field.Took'Image & Item.Heard.Count'Image);

      --  One it does not take goes on to the listener.
      Widgets.Perform_Command (Item.Tree, 10, Done);
      Widgets.Deliver (Item.Tree);
      Goldens.Check_Text ("commands-passed-on", "TRUE 1 2 10",
                          Done'Image & Item.Field.Took'Image & Item.Heard.Count'Image
                          & Item.Heard.Last_Tag'Image);
   end Responders;

   procedure Event_Payloads is
      Moved   : constant Widgets.Widget_Event := (Kind => Widgets.Drag, Across => 3.0, Down => 4.0, others => <>);
      Chosen  : constant Widgets.Widget_Event := (Kind => Widgets.Choose, Row => 5, others => <>);
      Pressed : constant Widgets.Widget_Event := (Kind => Widgets.Click, others => <>);
   begin
      Goldens.Check_Text
        ("commands-payloads", "3 4 5 CLICK",
         Integer'Image (Integer (Moved.Across))(2 .. 2) & " "
         & Integer'Image (Integer (Moved.Down))(2 .. 2) & " "
         & Chosen.Row'Image (2 .. 2) & " " & Pressed.Kind'Image);
   end Event_Payloads;

end Command_Tests;
