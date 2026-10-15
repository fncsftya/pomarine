with Ada.Unchecked_Conversion;

package body Pomarine.Widgets.Callbacks is

   type Context_Access is access all Context;

   function To_Context is new Ada.Unchecked_Conversion (System.Address, Context_Access);
      function To_Handler is new Ada.Unchecked_Conversion (System.Address, Handler);
   function To_Address is new Ada.Unchecked_Conversion (Handler, System.Address);

   procedure Run
     (Self, Proc : System.Address;
      Source     : in out Widget'Class;
      Event      : Widget_Event);
   --  What a widget calls: Proc, with the Self that went with it.

   procedure Run
     (Self, Proc : System.Address;
      Source     : in out Widget'Class;
      Event      : Widget_Event) is
   begin
      To_Handler (Proc) (To_Context (Self).all, Source, Event);
   end Run;

   procedure On
     (Item    : in out Widget'Class;
      Kind    : Event_Kind;
      Self    : not null access Context;
      Do_This : not null Handler) is
   begin
      Set_Hook
        (Item, Kind, Run'Unrestricted_Access,
         Self.all'Address, To_Address (Do_This));
   end On;

   procedure Off (Item : in out Widget'Class; Kind : Event_Kind) is
   begin
      Clear_Hook (Item, Kind);
   end Off;

end Pomarine.Widgets.Callbacks;
