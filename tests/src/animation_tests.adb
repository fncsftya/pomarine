with Ada.Strings.Fixed;
with SDL3.Windows.Renderers;
with Goldens;
with Pomarine.Widgets.Panels;
with Pomarine.Widgets.Scrollers;
with Yoga.Nodes;

package body Animation_Tests is

   package Widgets renames Pomarine.Widgets;
   package Panels renames Pomarine.Widgets.Panels;
   package Renderers renames SDL3.Windows.Renderers;

   function Image (Value : Integer) return String is
     (Ada.Strings.Fixed.Trim (Integer'Image (Value), Ada.Strings.Left));

   --  A widget that shows the numbers it is given

   type Meter is new Panels.Panel with record
      Shown : Float := 0.0;
      Told  : Natural := 0;
   end record;

   procedure Show (Item : in out Widgets.Widget'Class; Value : Float) is
   begin
      Meter (Item).Shown := Value;
      Meter (Item).Told := Meter (Item).Told + 1;
   end Show;

   procedure Other (Item : in out Widgets.Widget'Class; Value : Float) is
      pragma Unreferenced (Item, Value);
   begin
      null;
   end Other;

   function Percent (Item : Meter) return String is
     (Image (Integer (Item.Shown * 100.0)));

   type Fixture is limited record
      Tree   : Widgets.Tree;
      Target : Renderers.Renderer;
      Root   : aliased Panels.Panel;
      Gauge  : aliased Meter;
   end record;

   procedure Open (Item : in out Fixture) is
   begin
      Renderers.Create_Offscreen (Item.Target, 100, 100);
      Widgets.Set_Root (Item.Tree, Item.Root);
      Widgets.Add (Item.Root, Item.Gauge);
      Widgets.Layout (Item.Tree, Item.Target);
      Widgets.Update (Item.Tree, 1000);
   end Open;

   procedure Moves_Over_Time is
      Item : Fixture;
   begin
      Open (Item);
      Widgets.Animate (Item.Gauge, 0.0, 1.0, 200, Widgets.Linear, Show'Access);
      Goldens.Check_Text
        ("animation-starts", "0 TRUE",
         Percent (Item.Gauge) & " " & Widgets.Is_Animating (Item.Tree)'Image);

      Widgets.Update (Item.Tree, 1050);
      Goldens.Check_Text ("animation-quarter", "25", Percent (Item.Gauge));
      Widgets.Update (Item.Tree, 1100);
      Goldens.Check_Text ("animation-half", "50", Percent (Item.Gauge));

      --  The end is exact, and it is over.
      Widgets.Update (Item.Tree, 1500);
      Goldens.Check_Text
        ("animation-end", "100 FALSE",
         Percent (Item.Gauge) & " " & Widgets.Is_Animating (Item.Tree)'Image);
      declare
         Told : constant Natural := Item.Gauge.Told;
      begin
         Widgets.Update (Item.Tree, 1600);
         Goldens.Check_Text ("animation-over", "TRUE", Boolean'Image (Item.Gauge.Told = Told));
      end;

      --  An ease out is ahead of a steady rate.
      Widgets.Animate (Item.Gauge, 0.0, 1.0, 100, Widgets.Ease_Out, Show'Access);
      Widgets.Update (Item.Tree, 1650);
      Goldens.Check_Text ("animation-ease-out", "TRUE", Boolean'Image (Item.Gauge.Shown > 0.6));
   end Moves_Over_Time;

   procedure Replaced is
      Item : Fixture;
   begin
      Open (Item);
      Widgets.Animate (Item.Gauge, 0.0, 1.0, 200, Widgets.Linear, Show'Access);
      Widgets.Update (Item.Tree, 1100);
      --  Sent somewhere else from where it is: it goes on from there.
      Widgets.Animate (Item.Gauge, Item.Gauge.Shown, 0.0, 100, Widgets.Linear, Show'Access);
      Widgets.Update (Item.Tree, 1150);
      Goldens.Check_Text ("animation-replaced", "25", Percent (Item.Gauge));
      Widgets.Update (Item.Tree, 1200);
      Goldens.Check_Text
        ("animation-replaced-end", "0 FALSE",
         Percent (Item.Gauge) & " " & Widgets.Is_Animating (Item.Tree)'Image);

      --  Another number of the same widget runs beside it.
      Widgets.Animate (Item.Gauge, 0.0, 1.0, 100, Widgets.Linear, Show'Access);
      Widgets.Animate (Item.Gauge, 0.0, 1.0, 100, Widgets.Linear, Other'Access);
      Widgets.Stop_Animations (Item.Gauge);
      Goldens.Check_Text ("animation-stopped", "FALSE", Widgets.Is_Animating (Item.Tree)'Image);
   end Replaced;

   procedure Less_Movement is
      Item : Fixture;
   begin
      Open (Item);
      Widgets.Set_Reduced_Motion (Item.Tree, True);
      Widgets.Animate (Item.Gauge, 0.0, 1.0, 200, Widgets.Linear, Show'Access);
      Goldens.Check_Text
        ("animation-reduced", "100 FALSE",
         Percent (Item.Gauge) & " " & Widgets.Is_Animating (Item.Tree)'Image);
   end Less_Movement;

   procedure Wakes_The_Loop is
      Item : Fixture;
   begin
      Open (Item);
      Goldens.Check_Text ("animation-idle", "-1", Image (Widgets.Until_Update (Item.Tree)));
      Widgets.Animate (Item.Gauge, 0.0, 1.0, 200, Widgets.Linear, Show'Access);
      Goldens.Check_Text ("animation-frame", "16", Image (Widgets.Until_Update (Item.Tree)));
      Widgets.Update (Item.Tree, 5000);
      Goldens.Check_Text ("animation-idle-again", "-1", Image (Widgets.Until_Update (Item.Tree)));
   end Wakes_The_Loop;

   procedure Smooth_Scroll is
      Tree   : Widgets.Tree;
      Target : Renderers.Renderer;
      Root   : aliased Panels.Panel;
      Window : aliased Pomarine.Widgets.Scrollers.Scroller;
      Tall   : aliased Panels.Panel;
   begin
      Renderers.Create_Offscreen (Target, 100, 100);
      Widgets.Set_Root (Tree, Root);
      Widgets.Add (Root, Window);
      Widgets.Add (Window, Tall);
      Yoga.Nodes.Set_Height (Widgets.Node (Window), 100.0);
      Yoga.Nodes.Set_Height (Widgets.Node (Tall), 500.0);
      Widgets.Layout (Tree, Target);
      Widgets.Update (Tree, 0);

      Pomarine.Widgets.Scrollers.Scroll_Smoothly (Window, 200.0, 100);
      Widgets.Update (Tree, 50);
      Widgets.Layout (Tree, Target);
      Goldens.Check_Text
        ("animation-scroll-between", "TRUE",
         Boolean'Image (Pomarine.Widgets.Scrollers.Offset (Window) > 100.0
                        and then Pomarine.Widgets.Scrollers.Offset (Window) < 200.0));
      Widgets.Update (Tree, 200);
      Goldens.Check_Text
        ("animation-scroll-end", "200", Image (Integer (Pomarine.Widgets.Scrollers.Offset (Window))));
   end Smooth_Scroll;

end Animation_Tests;
