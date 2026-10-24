with Ada.Command_Line;
with Ada.Float_Text_IO;
with Ada.Real_Time;
with Ada.Text_IO;
with SDL3;
with Pomarine.Events;
with SDL3.Windows;
with SDL3.Windows.Renderers;
with Pomarine.Themes;
with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Labels;
with Pomarine.Widgets.Panels;
with Yoga.Nodes;

--  Measures what many small widgets cost, in a hidden window on the GPU:
--  ui_bench [pairs [rounds]]. A pair is a label and a button, in a wrapped
--  row; the cost is of building them, drawing every one, moving the pointer
--  between two, clicking (and finding the click by asking each button, as
--  an application does), and looking up a colour of the theme.
procedure UI_Bench is
   package Events renames Pomarine.Events;
   package Renderers renames SDL3.Windows.Renderers;
   package Widgets renames Pomarine.Widgets;
   package Buttons renames Pomarine.Widgets.Buttons;
   package Labels renames Pomarine.Widgets.Labels;
   package Panels renames Pomarine.Widgets.Panels;
   package Nodes renames Yoga.Nodes;
   package Themes renames Pomarine.Themes;

   use Ada.Real_Time;
   use Ada.Text_IO;

   Density : constant Float := 2.0;

   Pairs  : constant Positive :=
     (if Ada.Command_Line.Argument_Count > 0
      then Positive'Value (Ada.Command_Line.Argument (1)) else 150);
   Rounds : constant Positive :=
     (if Ada.Command_Line.Argument_Count > 1
      then Positive'Value (Ada.Command_Line.Argument (2)) else 300);

   Colors : constant Themes.Theme := Themes.Light;

   type Counter is limited new Widgets.Listener with record
      Count : Natural := 0;
   end record;

   overriding procedure Handle_Event
     (Self   : in out Counter;
      Source : in out Widgets.Widget'Class;
      Event  : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
   begin
      Self.Count := Self.Count + 1;
   end Handle_Event;

   Hearer : aliased Counter;

   procedure Report (What : String; Micros : Float) is
      Shown : String (1 .. 11);
   begin
      Ada.Float_Text_IO.Put (Shown, Micros, Aft => 3, Exp => 0);
      Put_Line ("  " & What & (1 .. Integer'Max (1, 46 - What'Length) => ' ')
                & Shown & " us");
   end Report;

   Win    : SDL3.Windows.Window;
   Target : Renderers.Renderer;

   Root    : aliased Panels.Panel;
   Wrapped : aliased Panels.Panel;
   Names   : array (1 .. Pairs) of aliased Labels.Label;
   Pushes  : array (1 .. Pairs) of aliased Buttons.Button;
   Tree    : Widgets.Tree;

   function Micros_Of (Span : Time_Span; Divisor : Positive) return Float is
     (Float (To_Duration (Span)) * 1.0E6 / Float (Divisor));

   procedure Build is
   begin
      Widgets.Set_Density (Tree, Density);
      Widgets.Set_Root (Tree, Root);
      Widgets.Add (Root, Wrapped);
      Nodes.Set_Flex_Direction (Widgets.Node (Root), Yoga.Column);
      Nodes.Set_Flex_Grow (Widgets.Node (Wrapped), 1.0);
      Nodes.Set_Flex_Direction (Widgets.Node (Wrapped), Yoga.Row);
      Nodes.Set_Wrap (Widgets.Node (Wrapped), Yoga.Wrap);
      for K in 1 .. Pairs loop
         Widgets.Add (Wrapped, Names (K));
         Widgets.Add (Wrapped, Pushes (K));
         Labels.Set_Text (Names (K), "Item" & K'Image);
         Buttons.Set_Label (Pushes (K), "Go");
         Nodes.Set_Width (Widgets.Node (Names (K)), 60.0 * Density);
         Nodes.Set_Height (Widgets.Node (Names (K)), 24.0 * Density);
         Nodes.Set_Width (Widgets.Node (Pushes (K)), 60.0 * Density);
         Nodes.Set_Height (Widgets.Node (Pushes (K)), 24.0 * Density);
      end loop;
   end Build;

   function Over (K : Positive) return Events.Event is
     --  The middle of button K, in points.
     ((Kind => Events.Mouse_Move,
       Mouse_X => Widgets.Left_Of (Pushes (K)) / Density + 10.0,
       Mouse_Y => Widgets.Top_Of (Pushes (K)) / Density + 10.0,
       others => <>));

   function Press (K : Positive; Kind : Events.Event_Kind) return Events.Event is
     ((Kind => Kind, Button => 1, Clicks => 1,
       Mouse_X => Widgets.Left_Of (Pushes (K)) / Density + 10.0,
       Mouse_Y => Widgets.Top_Of (Pushes (K)) / Density + 10.0,
       others => <>));

   procedure Frame is
      Resized : Boolean;
   begin
      Renderers.Fit (Target, Resized);
      Widgets.Paint (Tree, Target, Colors, Retained => Renderers.Keeps_Frame (Target));
   end Frame;

   Handled : Boolean;
   Start   : Time;
begin
   SDL3.Initialize;
   SDL3.Windows.Create (Win, "bench", 1000, 800, High_Density => True, Hidden => True);
   Renderers.Create (Target, Win, VSync => False, Keep_Frame => True);

   Put_Line (Pairs'Image & " label+button pairs," & Rounds'Image & " rounds:");

   Start := Clock;
   Build;
   Frame;
   Report ("build, first layout and paint (once)", Micros_Of (Clock - Start, 1));
   Frame;
   Renderers.Present (Target);

   Start := Clock;
   for K in 1 .. Rounds loop
      Widgets.Request_Layout (Wrapped);
      Widgets.Layout (Tree, Target);
   end loop;
   Report ("layout", Micros_Of (Clock - Start, Rounds));

   Start := Clock;
   for K in 1 .. Rounds loop
      Widgets.Invalidate_All (Tree);
      Frame;
   end loop;
   Report ("paint everything (no present)", Micros_Of (Clock - Start, Rounds));

   Start := Clock;
   for K in 1 .. Rounds loop
      Widgets.Dispatch (Tree, Over (1 + K mod 2), Handled);
      Frame;
   end loop;
   Report ("pointer between two buttons, paint damage", Micros_Of (Clock - Start, Rounds));

   Start := Clock;
   for K in 1 .. Rounds * 100 loop
      Widgets.Dispatch (Tree, Over (1 + K mod 2), Handled);
   end loop;
   Report ("pointer between two buttons (no paint)", Micros_Of (Clock - Start, Rounds * 100));

   Widgets.Set_Listener (Tree, Hearer'Unchecked_Access);
   Start := Clock;
   for K in 1 .. Rounds * 100 loop
      Widgets.Dispatch (Tree, Over (3), Handled);
      Widgets.Dispatch (Tree, Press (3, Events.Mouse_Down), Handled);
      Widgets.Dispatch (Tree, Press (3, Events.Mouse_Up), Handled);
   end loop;
   Report ("move, press, release (listener hears)", Micros_Of (Clock - Start, Rounds * 100));
   if Hearer.Count /= Rounds * 100 then
      Put_Line ("  heard:" & Hearer.Count'Image & " (expected" & Natural'Image (Rounds * 100) & ")");
   end if;

   declare
      Sum : Natural := 0;
      Slots : constant array (1 .. 4) of Themes.Slot := [Themes.Foreground, Themes.Border, Themes.Primary, Themes.Page];
   begin
      Start := Clock;
      for K in 1 .. 1_000_000 loop
         Sum := Sum + Natural (Themes.Resolve (Colors, Slots (1 + K mod 4)).Red);
      end loop;
      Report ("colour of a slot (x1)", Micros_Of (Clock - Start, 1_000_000));
      if Sum = 0 then
         Put_Line ("");
      end if;
   end;

   SDL3.Shutdown;
end UI_Bench;
