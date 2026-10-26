with Clock_Faces;
with Clock_View;
with Pomarine.UI;
with Pomarine.Widgets;
with Pomarine.Windows;

--  A custom clock face, placed by a declarative view. The widget paints its hands and updates the time.
procedure Clock_GUI is
   Win    : Pomarine.Windows.Window;
   Tree   : aliased Pomarine.Widgets.Tree;
   Clock  : Clock_Faces.Face;
   Screen : Pomarine.UI.View (Tree'Access);
begin
   Pomarine.Windows.Open (Win, Tree, "Clock", 360, 360);
   Clock_View.Build (Screen, Clock);
   Pomarine.Windows.Run (Win, Tree);
end Clock_GUI;
