with Ada.Finalization;

--  Own an embedded view when its tree is known only at build time. Declare the host after every
--  borrowed widget and model, so its bindings detach before those objects are finalized.
package Pomarine.UI.Hosts is

   type Host is limited new Ada.Finalization.Limited_Controlled with private;
   type View_Access is access all View;

   function Screen (Item : Host) return View_Access;

   procedure Open (Item : in out Host; Parent : Widgets.Widget'Class)
     with Pre => Screen (Item) = null and then Widgets.Is_Attached (Parent),
          Post => Screen (Item) /= null;

private

   type Host is limited new Ada.Finalization.Limited_Controlled with record
      Owned : View_Access;
   end record;

   overriding procedure Finalize (Item : in out Host);

end Pomarine.UI.Hosts;
