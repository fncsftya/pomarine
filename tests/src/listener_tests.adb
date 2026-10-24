with Ada.Strings.Fixed;
with Pomarine.Events;
with SDL3.Windows.Renderers;
with Texts.Documents;
with Goldens;
with Pomarine.Boxes;
with Pomarine.Clipboards;
with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Checks;
with Pomarine.Widgets.Commands;
with Pomarine.Widgets.Grips;
with Pomarine.Widgets.Layouts;
with Pomarine.Widgets.Panels;
with Pomarine.Widgets.Text_Fields;

package body Listener_Tests is

   package Events renames Pomarine.Events;
   package Renderers renames SDL3.Windows.Renderers;
   package Widgets renames Pomarine.Widgets;
   package Buttons renames Pomarine.Widgets.Buttons;
   package Checks renames Pomarine.Widgets.Checks;
   package Grips renames Pomarine.Widgets.Grips;
   package Panels renames Pomarine.Widgets.Panels;
   package Text_Fields renames Pomarine.Widgets.Text_Fields;
   package Docs renames Texts.Documents;
   package Layouts renames Pomarine.Widgets.Layouts;

   use type Widgets.Widget_Access;

   Density : constant Float := 2.0;
   Width   : constant := 300;
   Height  : constant := 200;
   --  In points.

   function Image (Value : Integer) return String is
     (Ada.Strings.Fixed.Trim (Integer'Image (Value), Ada.Strings.Left));

   --  What a listener heard.

   type Recorder is limited new Widgets.Listener with record
      Seen    : Widgets.Widget_Event_Array (1 .. 16);
      Count   : Natural := 0;
      Removes : Widgets.Widget_Access;
      --  If not null, removed from its tree when anything is heard.
   end record;

   overriding procedure Handle_Event
     (Self   : in out Recorder;
      Source : in out Widgets.Widget'Class;
      Event  : Widgets.Widget_Event) is
   begin
      if Self.Count < Self.Seen'Last then
         Self.Count := Self.Count + 1;
         Self.Seen (Self.Count) := Event;
      end if;
      if Self.Removes /= null and then Widgets.Is_Attached (Self.Removes.all) then
         Widgets.Remove (Self.Removes.all);
      end if;
      pragma Unreferenced (Source);
   end Handle_Event;

   function Heard (Item : Recorder) return String is
      Text : String (1 .. 400);
      Last : Natural := 0;

      procedure Add (Part : String) is
      begin
         Text (Last + 1 .. Last + Part'Length) := Part;
         Last := Last + Part'Length;
      end Add;
   begin
      for K in 1 .. Item.Count loop
         Add (Widgets.Event_Kind'Image (Item.Seen (K).Kind)
              & " tag" & Image (Item.Seen (K).Tag)
              & " index" & Image (Item.Seen (K).Index)
              & (if Item.Seen (K).Kind in Widgets.Choose | Widgets.Select_Tag
                      and then Item.Seen (K).Row > 0
                 then " row" & Image (Item.Seen (K).Row) else "")
              & "; ");
      end loop;
      return Text (1 .. Last);
   end Heard;

   type Fixture is limited record
      Tree   : Widgets.Tree;
      Target : Renderers.Renderer;
      Board  : Pomarine.Clipboards.Memory_Clipboard;
      Doc    : aliased Docs.Document;
      Root   : aliased Panels.Panel;
      First  : aliased Buttons.Button;
      Second : aliased Buttons.Button;
      Tick   : aliased Checks.Check;
      Grip   : aliased Grips.Grip;
      Field  : aliased Text_Fields.Text_Field;
      Ears   : aliased Recorder;
      --  after Tree, so that they are gone first
   end record;

   procedure Open (Item : in out Fixture) is
   begin
      Renderers.Create_Offscreen
        (Item.Target,
         Positive (Float (Width) * Density),
         Positive (Float (Height) * Density));
      Docs.Load (Item.Doc, "x");
      Widgets.Set_Density (Item.Tree, Density);
      Widgets.Set_Clipboard (Item.Tree, Item.Board);
      Widgets.Set_Listener (Item.Tree, Item.Ears'Unchecked_Access);

      Widgets.Set_Root (Item.Tree, Item.Root);
      Widgets.Add (Item.Root, Item.First, Item.Second, Item.Tick, Item.Grip);
      Widgets.Add (Item.Root, Item.Field);
      Layouts.Set_Layout (Item.Root, Flow => Layouts.Column, Padding => (others => 4.0), Gap => 4.0);
      Layouts.Set_Layout (Item.First, Width => 80.0, Height => 24.0);
      Layouts.Set_Layout (Item.Second, Width => 80.0, Height => 24.0);
      Layouts.Set_Layout (Item.Tick, Width => 80.0, Height => 24.0);
      Layouts.Set_Layout (Item.Grip, Width => 80.0, Height => 24.0);
      Layouts.Set_Layout (Item.Field, Width => 120.0, Height => 30.0);
      Buttons.Set_Label (Item.First, "One");
      Buttons.Set_Label (Item.Second, "Two");
      Checks.Set_Label (Item.Tick, "Tick");
      Text_Fields.Configure (Item.Field, "Georgia", 18.0);
      Text_Fields.Attach (Item.Field, Item.Doc'Unchecked_Access);
      Widgets.Layout (Item.Tree, Item.Target);
   end Open;

   function Middle_X (Part : Widgets.Widget'Class) return Float is
     ((Widgets.Left_Of (Part) + Widgets.Width_Of (Part) / 2.0) / Density);

   function Middle_Y (Part : Widgets.Widget'Class) return Float is
     ((Widgets.Top_Of (Part) + Widgets.Height_Of (Part) / 2.0) / Density);

   procedure Send (Item : in out Fixture; Event : Events.Event) is
      Handled : Boolean;
   begin
      Widgets.Dispatch (Item.Tree, Event, Handled);
   end Send;

   procedure Move_To (Item : in out Fixture; X, Y : Float) is
   begin
      Send (Item, (Kind => Events.Mouse_Move, Mouse_X => X, Mouse_Y => Y, others => <>));
   end Move_To;

   procedure Press (Item : in out Fixture; X, Y : Float; Clicks : Natural := 1) is
   begin
      Send (Item, (Kind => Events.Mouse_Down, Button => 1, Clicks => Clicks,
                   Mouse_X => X, Mouse_Y => Y, others => <>));
   end Press;

   procedure Release (Item : in out Fixture; X, Y : Float) is
   begin
      Send (Item, (Kind => Events.Mouse_Up, Button => 1, Mouse_X => X, Mouse_Y => Y,
                   others => <>));
   end Release;

   procedure Click_On (Item : in out Fixture; Part : Widgets.Widget'Class) is
   begin
      Move_To (Item, Middle_X (Part), Middle_Y (Part));
      Press (Item, Middle_X (Part), Middle_Y (Part));
      Release (Item, Middle_X (Part), Middle_Y (Part));
   end Click_On;

   --  The tests

   procedure Click is
      Item    : Fixture;
      Clicked : Boolean;
   begin
      Open (Item);
      Widgets.Set_Tag (Item.First, 7, Index => 3);
      Move_To (Item, Middle_X (Item.First), Middle_Y (Item.First));
      Press (Item, Middle_X (Item.First), Middle_Y (Item.First));
      Goldens.Check_Text ("listener-nothing-before-release", "", Heard (Item.Ears));
      Release (Item, Middle_X (Item.First), Middle_Y (Item.First));
      Goldens.Check_Text ("listener-click", "CLICK tag7 index3; ", Heard (Item.Ears));
      Buttons.Take_Click (Item.First, Clicked);
      Goldens.Check_Text ("listener-click-still-polled", "TRUE", Boolean'Image (Clicked));

      --  Let go elsewhere: no click, and nothing said.
      Item.Ears.Count := 0;
      Move_To (Item, Middle_X (Item.Second), Middle_Y (Item.Second));
      Press (Item, Middle_X (Item.Second), Middle_Y (Item.Second));
      Move_To (Item, 290.0, 190.0);
      Release (Item, 290.0, 190.0);
      Goldens.Check_Text ("listener-let-go-elsewhere", "", Heard (Item.Ears));

      --  A widget never given a tag says so.
      Click_On (Item, Item.Second);
      Goldens.Check_Text ("listener-no-tag", "CLICK tag-1 index0; ", Heard (Item.Ears));
   end Click;

   procedure Grip_Release is
      Item : Fixture;
   begin
      Open (Item);
      --  A press and let go on a grip: it was let go, and then clicked.
      Click_On (Item, Item.Grip);
      Goldens.Check_Text
        ("listener-grip-release", "RELEASE tag-1 index0; CLICK tag-1 index0; ", Heard (Item.Ears));
      --  Let go elsewhere, it is let go all the same, and not clicked.
      Item.Ears.Count := 0;
      Move_To (Item, Middle_X (Item.Grip), Middle_Y (Item.Grip));
      Press (Item, Middle_X (Item.Grip), Middle_Y (Item.Grip));
      Send (Item, (Kind => Events.Mouse_Move, Mouse_X => 290.0, Mouse_Y => 190.0, Left_Held => True,
                   others => <>));
      Release (Item, 290.0, 190.0);
      Goldens.Check_Text
        ("listener-grip-let-go-elsewhere", "DRAG tag-1 index0; RELEASE tag-1 index0; ",
         Heard (Item.Ears));
   end Grip_Release;

   procedure Command_Tags is
      type Command is (Save, Open_Settings, Rename_Card);
      package Cmd is new Widgets.Commands (Command);
      Item : Fixture;
   begin
      Open (Item);
      Cmd.Bind (Item.First, Open_Settings);
      Cmd.Bind (Item.Second, Rename_Card, Index => 5);
      Click_On (Item, Item.Second);
      Click_On (Item, Item.First);
      Goldens.Check_Text
        ("listener-commands",
         Command'Image (Cmd.What (Item.Ears.Seen (1))) & Item.Ears.Seen (1).Index'Image
         & "," & Command'Image (Cmd.What (Item.Ears.Seen (2))),
         "RENAME_CARD 5,OPEN_SETTINGS");
      Goldens.Check_Text
        ("listener-bound", "TRUE", Boolean'Image (Cmd.Is_Bound (Item.Ears.Seen (1))));
      Widgets.Set_Tag (Item.Tick, Widgets.No_Tag);
      Click_On (Item, Item.Tick);
      Goldens.Check_Text
        ("listener-unbound-tag", "FALSE", Boolean'Image (Cmd.Is_Bound (Item.Ears.Seen (3))));
   end Command_Tags;

   procedure Own_Listener is
      Item   : Fixture;
      Mine   : aliased Recorder;
   begin
      Open (Item);
      Widgets.Set_Listener (Item.First, Mine'Unchecked_Access);
      Click_On (Item, Item.First);
      Click_On (Item, Item.Second);
      Goldens.Check_Text
        ("listener-own",
         Image (Mine.Count) & "/" & Image (Item.Ears.Count), "1/1");
      Widgets.Set_Listener (Item.First, null);
      Click_On (Item, Item.First);
      Goldens.Check_Text
        ("listener-own-cleared",
         Image (Mine.Count) & "/" & Image (Item.Ears.Count), "1/2");
   end Own_Listener;

   procedure Deferred is
      Item : Fixture;
   begin
      Open (Item);
      Item.Ears.Removes := Item.First'Unchecked_Access;
      Click_On (Item, Item.First);
      Goldens.Check_Text
        ("listener-deferred-removed",
         Boolean'Image (Widgets.Is_Attached (Item.First)) & " " & Heard (Item.Ears),
         "FALSE CLICK tag-1 index0; ");
      Goldens.Check_Text
        ("listener-deferred-children", "4", Image (Widgets.Child_Count (Item.Root)));
   end Deferred;

   procedure Controls is
      Item    : Fixture;
      Handled : Boolean;
   begin
      Open (Item);
      Widgets.Set_Tag (Item.Tick, 1);
      Widgets.Set_Tag (Item.Grip, 2, Index => 9);
      Widgets.Set_Tag (Item.Field, 3);
      Click_On (Item, Item.Tick);
      Goldens.Check_Text ("listener-check", "CHANGE tag1 index0; ", Heard (Item.Ears));

      Item.Ears.Count := 0;
      Move_To (Item, Middle_X (Item.Grip), Middle_Y (Item.Grip));
      Press (Item, Middle_X (Item.Grip), Middle_Y (Item.Grip), Clicks => 2);
      Move_To (Item, Middle_X (Item.Grip) + 5.0, Middle_Y (Item.Grip) + 2.0);
      Release (Item, Middle_X (Item.Grip) + 5.0, Middle_Y (Item.Grip) + 2.0);
      Goldens.Check_Text
        ("listener-grip",
         "DOUBLE_CLICK tag2 index9; DRAG tag2 index9; RELEASE tag2 index9; CLICK tag2 index9; ", Heard (Item.Ears));
      Goldens.Check_Text
        ("listener-drag-distance",
         "5.0 2.0", Float'Image (Item.Ears.Seen (2).Across)(2 .. 4) & " "
         & Float'Image (Item.Ears.Seen (2).Down)(2 .. 4));

      Item.Ears.Count := 0;
      Widgets.Focus (Item.Field);
      Widgets.Dispatch
        (Item.Tree, (Kind => Events.Key_Down, Key => Events.Key_Return, others => <>), Handled);
      Goldens.Check_Text ("listener-submit", "SUBMIT tag3 index0; ", Heard (Item.Ears));
   end Controls;

   procedure Layout_Helpers is
      Item : Fixture;
   begin
      Open (Item);
      Widgets.Layout (Item.Tree, Item.Target);
      Goldens.Check_Text
        ("layouts-points",
         Image (Integer (Widgets.Width_Of (Item.First))) & "x"
         & Image (Integer (Widgets.Height_Of (Item.First))),
         "160x48");
      Goldens.Check_Text
        ("layouts-padding",
         Image (Integer (Widgets.Left_Of (Item.First))) & ","
         & Image (Integer (Widgets.Top_Of (Item.First))),
         "8,8");
      Goldens.Check_Text
        ("layouts-gap",
         Image (Integer (Widgets.Top_Of (Item.Second))), "64");
      Layouts.Set_Layout (Item.First, Width => Layouts.Hairline);
      Widgets.Layout (Item.Tree, Item.Target);
      Goldens.Check_Text
        ("layouts-hairline",
         Image (Integer (Widgets.Width_Of (Item.First))),
         Image (Integer (Pomarine.Boxes.Edge (Density))));
      --  A negative edge in pixels is not a hairline or a shadow's room, whatever its size.
      Layouts.Set_Layout
        (Item.First, Width => 80.0, Margin => (Left => -2.0, others => <>),
         Unit => Layouts.Device_Pixels);
      Widgets.Layout (Item.Tree, Item.Target);
      Goldens.Check_Text
        ("layouts-negative-pixels", "6", Image (Integer (Widgets.Left_Of (Item.First))));
      Layouts.Set_Layout
        (Item.Second, Padding => (Right => Layouts.Shadow_Room, others => <>),
         Width => 50.0, Height => 20.0, Shadowed => True);
      Widgets.Layout (Item.Tree, Item.Target);
      Goldens.Check_Text
        ("layouts-order",
         Image (Widgets.Child_Count (Item.Root)) & " "
         & Boolean'Image (Widgets.Child_At (Item.Root, 1) = Item.First'Unchecked_Access)
         & Boolean'Image (Widgets.Child_At (Item.Root, 4) = Item.Grip'Unchecked_Access),
         "5 TRUETRUE");
   end Layout_Helpers;

end Listener_Tests;
