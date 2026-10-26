with Ada.Unchecked_Deallocation;

package body Pomarine.UI.Hosts is

   procedure Free is new Ada.Unchecked_Deallocation (View, View_Access);

   function Screen (Item : Host) return View_Access is (Item.Owned);

   procedure Open (Item : in out Host; Parent : Widgets.Widget'Class) is
   begin
      Item.Owned := new View (Widgets.Tree_Of (Parent));
   end Open;

   overriding procedure Finalize (Item : in out Host) is
   begin
      Free (Item.Owned);
   end Finalize;

end Pomarine.UI.Hosts;
