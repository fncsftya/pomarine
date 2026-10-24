with Clock_Faces;
with Pomarine.Widgets;
with Pomarine.Widgets.Layouts;
with Pomarine.Widgets.Panels;
with Pomarine.Windows;

--  An analogue clock showing the local time, drawn by a widget of its own
--  (Clock_Faces) with lines and discs rather than made of the library's
--  widgets: the way to add to them what they do not have. It grows and
--  shrinks with the window. Close the window to end it.
procedure Clock_GUI is
   package Layouts renames Pomarine.Widgets.Layouts;

   Win   : Pomarine.Windows.Window;  --  before the tree that draws to it
   Tree  : Pomarine.Widgets.Tree;
   Page  : aliased Pomarine.Widgets.Panels.Panel;
   Clock : aliased Clock_Faces.Face;
begin
   Pomarine.Windows.Open (Win, Tree, "Clock", 360, 360);
   Pomarine.Widgets.Set_Root (Tree, Page);
   Pomarine.Widgets.Add (Page, Clock);
   Layouts.Set_Layout (Page, Flow => Layouts.Column, Padding => (others => 12.0));
   Layouts.Set_Layout (Clock, Grow => 1.0);
   Pomarine.Widgets.Set_Accessible_Name (Clock, "Analogue clock");
   Pomarine.Windows.Run (Win, Tree);
end Clock_GUI;
