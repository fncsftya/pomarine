with Gallery;
with Gallery_VM;
with Pomarine.Widgets;
with Pomarine.Windows;

--  Every widget the library has, on one window: the buttons, fields, checks, radios, switch, slider, a select that
--  opens its own menu, tabs, a stepper, a disclosure, list, menu, badge, chip, toast and tooltips (rest the pointer on
--  the slider). The Popover and Dialog buttons open what floats over the window. Click, type and tab about to see how
--  each answers. Close the window to end it.
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
