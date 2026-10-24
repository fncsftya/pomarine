with Greeter;
with Pomarine.Widgets;
with Pomarine.Windows;

--  A window with a greeting and a button that changes it: the smallest
--  program that builds a tree of widgets and runs it. Close the window to
--  end it. The widgets and what the button does are in Greeter.
procedure Hello_GUI is
   Win  : Pomarine.Windows.Window;  --  before the tree that draws to it
   Tree : Pomarine.Widgets.Tree;
   Page : aliased Greeter.Greeting;
begin
   Pomarine.Windows.Open (Win, Tree, "Hello", 320, 160);
   Greeter.Build (Page, Tree);
   Pomarine.Windows.Run (Win, Tree);
end Hello_GUI;
