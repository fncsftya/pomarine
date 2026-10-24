with Pomarine.Widgets;
with Pomarine.Windows;
with Todo;

--  A list of tasks: type one and press Return; choose one and mark it done or
--  delete it, or clear all that are done. The list
--  reads its rows from a model, so it would cost the same of a hundred
--  thousand. Close the window to end it.
procedure Todo_GUI is
   Win  : Pomarine.Windows.Window;  --  before the tree that draws to it
   Tree : Pomarine.Widgets.Tree;
   Page : aliased Todo.Page;
begin
   Pomarine.Windows.Open (Win, Tree, "Tasks", 640, 480);
   Todo.Build (Page, Tree);
   Pomarine.Windows.Run (Win, Tree);
end Todo_GUI;
