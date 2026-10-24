with Ada.Unchecked_Conversion;

package body Pomarine.Widgets.Editors.Callbacks is

   type Context_Access is access all Context;

   function To_Context is new Ada.Unchecked_Conversion (System.Address, Context_Access);
   function To_Tool is new Ada.Unchecked_Conversion (System.Address, Tool_Handler);
   function To_Link is new Ada.Unchecked_Conversion (System.Address, Link_Handler);
   function To_Address is new Ada.Unchecked_Conversion (Tool_Handler, System.Address);
   function To_Address is new Ada.Unchecked_Conversion (Link_Handler, System.Address);

   procedure Run_Tool
     (Self, Proc  : System.Address;
      Source      : in out Widget'Class;
      Code, Value : Natural);

   procedure Run_Tool
     (Self, Proc  : System.Address;
      Source      : in out Widget'Class;
      Code, Value : Natural)
   is
      pragma Unreferenced (Code);
   begin
      To_Tool (Proc) (To_Context (Self).all, Editor'Class (Source), Value);
   end Run_Tool;

   procedure Run_Link
     (Self, Proc  : System.Address;
      Source      : in out Widget'Class;
      Code, Value : Natural);

   procedure Run_Link
     (Self, Proc  : System.Address;
      Source      : in out Widget'Class;
      Code, Value : Natural)
   is
      pragma Unreferenced (Code, Value);
   begin
      To_Link (Proc) (To_Context (Self).all, Editor'Class (Source));
   end Run_Link;

   procedure On_Tool
     (Item    : in out Editor'Class;
      Self    : not null access Context;
      Do_This : not null Tool_Handler) is
   begin
      Item.Tool_Hook := (Run_Tool'Unrestricted_Access, Self.all'Address, To_Address (Do_This));
   end On_Tool;

   procedure On_Follow
     (Item    : in out Editor'Class;
      Self    : not null access Context;
      Do_This : not null Link_Handler) is
   begin
      Item.Follow_Hook := (Run_Link'Unrestricted_Access, Self.all'Address, To_Address (Do_This));
   end On_Follow;

   procedure On_Ask_Link
     (Item    : in out Editor'Class;
      Self    : not null access Context;
      Do_This : not null Link_Handler) is
   begin
      Item.Link_Hook := (Run_Link'Unrestricted_Access, Self.all'Address, To_Address (Do_This));
   end On_Ask_Link;

   procedure Off_Tool (Item : in out Editor'Class) is
   begin
      Item.Tool_Hook := (others => <>);
   end Off_Tool;

   procedure Off_Follow (Item : in out Editor'Class) is
   begin
      Item.Follow_Hook := (others => <>);
   end Off_Follow;

   procedure Off_Ask_Link (Item : in out Editor'Class) is
   begin
      Item.Link_Hook := (others => <>);
   end Off_Ask_Link;

end Pomarine.Widgets.Editors.Callbacks;
