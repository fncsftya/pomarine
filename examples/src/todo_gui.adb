with Pomarine.Widgets;
with Pomarine.Windows;
with Todo;
with Todo_VM;

--  A list of tasks: type one and press Return; choose one and mark it done or
--  delete it, or clear all that are done. The list
--  reads its rows from a model, so it would cost the same of a hundred
--  thousand. Close the window to end it.
procedure Todo_GUI is
   Win    : Pomarine.Windows.Window;  --  before the tree that draws to it
   Tree   : aliased Pomarine.Widgets.Tree;
   Model  : aliased Todo_VM.Model;     --  before the view that shows it
   Screen : Todo.UI.View (Tree'Access);
begin
   Todo_VM.Seed (Model);
   Pomarine.Windows.Open (Win, Tree, "Tasks", 640, 480);
   Todo.Build (Screen, Model'Access);
   Pomarine.Windows.Run (Win, Tree);
end Todo_GUI;
