with Gallery;
with Gallery_VM;
with Pomarine.Themes;
with Pomarine.Widgets;
with Pomarine.Windows;

--  The window's loop as an application with a loop of its own uses it: a turn at a time (Step), a title and
--  size changed after it is open, the colours chosen, work handed to Idle, and Close. It opens a real window
--  for a moment, so it is not one of the offscreen tests.
procedure Windows_Test is
   package Windows renames Pomarine.Windows;

   Win    : Windows.Window;  --  before the tree that draws to it
   Tree   : aliased Pomarine.Widgets.Tree;
   Model  : aliased Gallery_VM.Model;
   Parts  : Gallery.Specimens;
   Screen : Gallery.UI.View (Tree'Access);
   Closed : Boolean;
   Idled  : Natural := 0;

   procedure Idle is
   begin
      Idled := Idled + 1;
      if Idled = 3 then
         Windows.Close (Win);
      end if;
   end Idle;
begin
   Gallery_VM.Seed (Model);
   Windows.Open (Win, Tree, "Windows test", Gallery.Width, Gallery.Height);
   Gallery.Build (Screen, Model'Access, Parts);

   --  A turn that waits for nothing returns at once, and the window goes on.
   Windows.Step (Win, Tree, Wait_For => 0, Closed => Closed);
   pragma Assert (not Closed and then not Windows.Is_Closing (Win));

   --  Said after it is open.
   Windows.Set_Title (Win, "Another title");
   Windows.Set_Size (Win, Gallery.Width - 40, Gallery.Height - 40);
   Windows.Set_Theme (Win, Pomarine.Themes.Dark);
   Windows.Step (Win, Tree, Wait_For => 0, Closed => Closed);
   Windows.Follow_System (Win);
   Windows.Step (Win, Tree, Wait_For => 0, Closed => Closed);
   pragma Assert (not Closed);

   --  Run waits no longer than the idle period for an event, and calls Idle after each turn; Close from it
   --  ends the loop.
   Windows.Run (Win, Tree, Idle => Idle'Unrestricted_Access, Idle_Period => 5);
   pragma Assert (Idled = 3 and then Windows.Is_Closing (Win));

   --  A window that is closing takes no more turns.
   Windows.Step (Win, Tree, Wait_For => 0, Closed => Closed);
   pragma Assert (Closed);
end Windows_Test;
