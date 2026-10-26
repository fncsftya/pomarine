with Greeter;
with Greeter_VM;
with Pomarine.Widgets;
with Pomarine.Windows;

--  A greeting and a command button, declared with their model bindings in Greeter.
procedure Hello_GUI is
   Win    : Pomarine.Windows.Window;
   Tree   : aliased Pomarine.Widgets.Tree;
   Model  : aliased Greeter_VM.Model;
   Screen : Greeter.UI.View (Tree'Access);
begin
   Pomarine.Windows.Open (Win, Tree, "Hello", 320, 160);
   Greeter.Build (Screen, Model'Access);
   Pomarine.Widgets.Set_Tab_Navigation (Tree, True);
   Pomarine.Windows.Run (Win, Tree);
end Hello_GUI;
