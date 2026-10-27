with Pomarine.Testing;
with Pomarine.UI;

--  What a model does to the view that is calling it (the hooks of Form_VM), at library level, as hooks must be.

package Reentry is

   Window : access Pomarine.Testing.Session;
   Screen : access Pomarine.UI.View;

   Queued_Seen : Natural := 0;
   --  How many events the view was holding when the hook had made its own.

   procedure Press_Return;
   --  A Return, as the person would, while the view is in the middle of a command.

   procedure Fail;
   --  The model fails.

end Reentry;
