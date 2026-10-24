with SDL3;
with SDL3.Events;
with SDL3.Windows;
with SDL3.Windows.Renderers;
with Pomarine.Themes;
with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Labels;
with Pomarine.Widgets.Layouts;
with Pomarine.Widgets.Panels;

--  A window with a greeting and a button that changes it: the smallest
--  program that builds a tree of widgets and runs the loop that
--  Pomarine.Widgets describes. Close the window to end it.
procedure Hello_GUI is
   package Renderers renames SDL3.Windows.Renderers;
   package Widgets renames Pomarine.Widgets;
   package Buttons renames Pomarine.Widgets.Buttons;
   package Labels renames Pomarine.Widgets.Labels;
   package Layouts renames Pomarine.Widgets.Layouts;
   package Panels renames Pomarine.Widgets.Panels;

   Colors : constant Pomarine.Themes.Theme := Pomarine.Themes.Light;

   --  The window, then what draws into it; then the widgets, which are
   --  ours, and the tree that links them (after the renderer they draw to).
   Win      : SDL3.Windows.Window;
   Target   : Renderers.Renderer;
   Root     : aliased Panels.Panel;
   Greeting : aliased Labels.Label;
   Greet    : aliased Buttons.Button;
   Tree     : Widgets.Tree;

   Event   : SDL3.Events.Event;
   Handled : Boolean;
   Clicked : Boolean;
   Done    : Boolean := False;
   Count   : Natural := 0;
begin
   SDL3.Initialize;
   SDL3.Windows.Create (Win, "Hello", 320, 160, Resizable => True, High_Density => True);
   Renderers.Create (Target, Win);

   --  Building goes from the top down, in points.
   Widgets.Set_Density (Tree, SDL3.Windows.Pixel_Density (Win));
   Widgets.Set_Root (Tree, Root);
   Widgets.Add (Root, Greeting, Greet);

   Layouts.Set_Layout
     (Root, Flow => Layouts.Column, Align => Layouts.Center, Spread => Layouts.Center,
      Padding => (others => 16.0), Gap => 12.0);
   Layouts.Set_Layout (Greeting, Width => 200.0, Height => 24.0);
   Layouts.Set_Layout (Greet, Width => 120.0, Height => 32.0);

   Labels.Set_Text (Greeting, "Hello, world!");
   Labels.Set_Centered (Greeting, True);
   Buttons.Set_Label (Greet, "Say hello");
   Buttons.Set_Kind (Greet, Buttons.Primary);

   while not Done loop
      --  Wait for an event, or for the time a widget wants to be told.
      if SDL3.Events.Wait (Event, Timeout_MS => Widgets.Until_Update (Tree)) then
         loop
            case Event.Kind is
               when SDL3.Events.Quit   => Done := True;
               when SDL3.Events.Redraw => Widgets.Invalidate_All (Tree);
               when others             => Widgets.Dispatch (Tree, Event, Handled);
            end case;
            exit when not SDL3.Events.Poll (Event);
         end loop;
      end if;
      Widgets.Update (Tree, SDL3.Events.Ticks);

      --  What the button said, taken when we like.
      Buttons.Take_Click (Greet, Clicked);
      if Clicked then
         Count := Count + 1;
         Labels.Set_Text (Greeting, "Hello again, x" & Count'Image & "!");
      end if;

      if Widgets.Needs_Paint (Tree) then
         declare
            Resized : Boolean;
         begin
            Renderers.Fit (Target, Resized);
            Widgets.Paint (Tree, Target, Colors, Retained => Renderers.Keeps_Frame (Target));
            Renderers.Present (Target);
         end;
      end if;
   end loop;

   SDL3.Shutdown;
end Hello_GUI;
