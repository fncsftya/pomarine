with Ada.Unchecked_Conversion;
with System;

package body Pomarine.Widgets.Embeds.Callbacks is

   type Context_Access is access all Context;

   function To_Context is new Ada.Unchecked_Conversion (System.Address, Context_Access);
   function To_Handler is new Ada.Unchecked_Conversion (System.Address, Shortcut_Handler);
   function To_Address is new Ada.Unchecked_Conversion (Shortcut_Handler, System.Address);

   procedure Run_Shortcut (Self, Proc : System.Address; Source : in out Widget'Class; Code, Value : Natural);

   procedure Run_Shortcut (Self, Proc : System.Address; Source : in out Widget'Class; Code, Value : Natural) is
      pragma Unreferenced (Value);
   begin
      To_Handler (Proc) (To_Context (Self).all, Embed'Class (Source), Code);
   end Run_Shortcut;

   procedure On_Shortcut
     (Item : in out Embed'Class; Self : not null access Context; Do_This : not null Shortcut_Handler) is
   begin
      Item.Shortcut_Hook := (Run_Shortcut'Unrestricted_Access, Self.all'Address, To_Address (Do_This));
   end On_Shortcut;

   procedure Off_Shortcut (Item : in out Embed'Class) is
   begin
      Item.Shortcut_Hook := (others => <>);
   end Off_Shortcut;

end Pomarine.Widgets.Embeds.Callbacks;
