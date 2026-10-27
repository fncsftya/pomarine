with Pomarine.Widgets;

procedure Pomarine.UI.Run_Window
  (Model          : aliased in out Model_Type;
   Title          : String;
   Width          : Positive;
   Height         : Positive;
   Resizable      : Boolean := True;
   Tab_Navigation : Boolean := True;
   Idle           : Pomarine.Windows.Idle_Procedure := null;
   Idle_Period    : Positive := 100)
is
   Win    : Pomarine.Windows.Window;  --  before the tree that draws to it
   Tree   : aliased Pomarine.Widgets.Tree;
   Screen : View (Tree'Access);
begin
   Pomarine.Windows.Open (Win, Tree, Title, Width, Height, Resizable);
   Build (Screen, Model'Access);
   Pomarine.Widgets.Set_Tab_Navigation (Tree, Tab_Navigation);
   Pomarine.Windows.Run (Win, Tree, Idle, Idle_Period);
end Pomarine.UI.Run_Window;
