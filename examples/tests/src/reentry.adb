with Pomarine.Events;

package body Reentry is

   procedure Press_Return is
   begin
      Pomarine.Testing.Feed
        (Window.all, (Kind => Pomarine.Events.Key_Down, Key => Pomarine.Events.Key_Return, others => <>));
      Queued_Seen := Pomarine.UI.Queued_Events (Screen.all);
   end Press_Return;

   procedure Fail is
   begin
      raise Program_Error with "the model failed";
   end Fail;

end Reentry;
