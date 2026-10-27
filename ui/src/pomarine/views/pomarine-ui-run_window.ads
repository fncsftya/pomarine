--  A window of one screen: the whole of a program that has a model and a screen to build of it.
--
--     procedure Show is new Pomarine.UI.Run_Window (Todo_VM.Model, Todo.Build);
--     ...
--     Show (Model, "Tasks", 640, 480);
--
--  It makes the window, the tree it draws and the view, in the order they must be (the window before the tree
--  that draws to it, both before the view), has Build make the screen of Model in the view and mount it, and
--  steps until the window is closed. The model is the caller's and so is declared before the call, which is
--  what Pomarine.UI asks (it must outlive the view); a model that needs a start is given it first.
with Pomarine.Windows;

generic
   type Model_Type (<>) is limited private;
   with procedure Build (Screen : in out View; Data : not null access Model_Type);
procedure Pomarine.UI.Run_Window
  (Model          : aliased in out Model_Type;
   Title          : String;
   Width          : Positive;
   Height         : Positive;
   Resizable      : Boolean := True;
   Tab_Navigation : Boolean := True;
   Idle           : Pomarine.Windows.Idle_Procedure := null;
   Idle_Period    : Positive := 100);
--  Tab_Navigation: Tab and Shift-Tab move the focus among the controls, in the order they are placed.
--  Idle and Idle_Period are those of Pomarine.Windows.Run.
