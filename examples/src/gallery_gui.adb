with Gallery;
with Gallery_VM;
with Pomarine.Widgets;
with Pomarine.Windows;

--  Every widget the library has, on one window: the buttons, fields, checks, radios, switch, slider, select,
--  list, menu, badge, chip, toast and tooltip. Click, type and tab about to see how each answers. Close the
--  window to end it.
procedure Gallery_GUI is
   Win    : Pomarine.Windows.Window;  --  before the tree that draws to it
   Tree   : aliased Pomarine.Widgets.Tree;
   Model  : aliased Gallery_VM.Model;     --  before the view that shows it
   Parts  : Gallery.Specimens;            --  likewise
   Screen : Gallery.UI.View (Tree'Access);
begin
   Gallery_VM.Seed (Model);
   Pomarine.Windows.Open (Win, Tree, "Pomarine gallery", Gallery.Width, Gallery.Height);
   Gallery.Build (Screen, Model'Access, Parts);
   Pomarine.Widgets.Set_Tab_Navigation (Tree, True);
   Pomarine.Windows.Run (Win, Tree);
end Gallery_GUI;
