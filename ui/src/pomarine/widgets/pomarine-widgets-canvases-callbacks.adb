with Ada.Unchecked_Conversion;

package body Pomarine.Widgets.Canvases.Callbacks is

   type Context_Access is access all Context;

   function To_Context is new Ada.Unchecked_Conversion (System.Address, Context_Access);
   function To_Select is new Ada.Unchecked_Conversion (System.Address, Select_Handler);
   function To_Delete is new Ada.Unchecked_Conversion (System.Address, Delete_Handler);
   function To_Address is new Ada.Unchecked_Conversion (Select_Handler, System.Address);
   function To_Address is new Ada.Unchecked_Conversion (Delete_Handler, System.Address);

   procedure Run_Select
     (Self, Proc  : System.Address;
      Source      : in out Widget'Class;
      Code, Value : Natural);

   procedure Run_Select
     (Self, Proc  : System.Address;
      Source      : in out Widget'Class;
      Code, Value : Natural)
   is
      pragma Unreferenced (Code);
   begin
      To_Select (Proc) (To_Context (Self).all, Canvas'Class (Source), Value);
   end Run_Select;

   procedure Run_Delete
     (Self, Proc  : System.Address;
      Source      : in out Widget'Class;
      Code, Value : Natural);

   procedure Run_Delete
     (Self, Proc  : System.Address;
      Source      : in out Widget'Class;
      Code, Value : Natural)
   is
      pragma Unreferenced (Code, Value);
   begin
      To_Delete (Proc) (To_Context (Self).all, Canvas'Class (Source));
   end Run_Delete;

   procedure On_Select
     (Item    : in out Canvas'Class;
      Self    : not null access Context;
      Do_This : not null Select_Handler) is
   begin
      Item.Select_Hook := (Run_Select'Unrestricted_Access, Self.all'Address, To_Address (Do_This));
   end On_Select;

   procedure On_Delete
     (Item    : in out Canvas'Class;
      Self    : not null access Context;
      Do_This : not null Delete_Handler) is
   begin
      Item.Delete_Hook := (Run_Delete'Unrestricted_Access, Self.all'Address, To_Address (Do_This));
   end On_Delete;

   procedure Off_Select (Item : in out Canvas'Class) is
   begin
      Item.Select_Hook := (others => <>);
   end Off_Select;

   procedure Off_Delete (Item : in out Canvas'Class) is
   begin
      Item.Delete_Hook := (others => <>);
   end Off_Delete;

end Pomarine.Widgets.Canvases.Callbacks;
