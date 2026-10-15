with Ada.Unchecked_Conversion;
with Interfaces;
with Interfaces.C;
with SDL3.Events;

package body Pomarine.Native_Menus is

   use type System.Address;
   use type Widgets.Command_State;
   use type Widgets.Command_Validator;

   package C renames Interfaces.C;

   use type C.unsigned_char;
   use type Interfaces.Unsigned_32;

   type Chosen_Callback is access procedure (User : System.Address; Tag : Interfaces.Integer_32)
     with Convention => C;

   function Install_Native (Callback : Chosen_Callback; User : System.Address)
      return C.unsigned_char
     with Import, Convention => C, External_Name => "pn_menu_install";

   function Add_Menu_Native (Title : System.Address; Length : Interfaces.Unsigned_32)
      return System.Address
     with Import, Convention => C, External_Name => "pn_menu_add_menu";

   procedure Add_Item_Native
     (Target : System.Address;
      Title : System.Address; Title_Length : Interfaces.Unsigned_32;
      Key : System.Address; Key_Length : Interfaces.Unsigned_32;
      Modifiers : Interfaces.Unsigned_32;
      Tag : Interfaces.Integer_32)
     with Import, Convention => C, External_Name => "pn_menu_add_item";

   procedure Add_Separator_Native (Target : System.Address)
     with Import, Convention => C, External_Name => "pn_menu_add_separator";

   procedure Set_State_Native
     (Tag : Interfaces.Integer_32; Offered, Enabled, Ticked : C.unsigned_char)
     with Import, Convention => C, External_Name => "pn_menu_set_state";

   protected body Mailbox is

      procedure Put (Tag : Integer) is
      begin
         if Count < Chosen_Capacity then
            Items ((First + Count - 1) mod Chosen_Capacity + 1) := Tag;
            Count := Count + 1;
         end if;
      end Put;

      procedure Take (Tag : out Integer; Found : out Boolean) is
      begin
         Found := Count > 0;
         if Found then
            Tag := Items (First);
            First := First mod Chosen_Capacity + 1;
            Count := Count - 1;
         else
            Tag := Widgets.No_Tag;
         end if;
      end Take;

      function Waiting return Boolean is (Count > 0);

   end Mailbox;

   type Bar_Access is access all Menu_Bar;
   function To_Bar is new Ada.Unchecked_Conversion (System.Address, Bar_Access);

   procedure Chosen (User : System.Address; Tag : Interfaces.Integer_32)
     with Convention => C;

   procedure Chosen (User : System.Address; Tag : Interfaces.Integer_32) is
   begin
      To_Bar (User).Mail.Put (Integer (Tag));
      SDL3.Events.Wake;
   end Chosen;

   procedure Install (Item : in out Menu_Bar) is
   begin
      Item.Installed :=
        Install_Native (Chosen'Access, Item'Address) /= 0;
   end Install;

   function Is_Installed (Item : Menu_Bar) return Boolean is (Item.Installed);

   procedure Add_Menu (Item : in out Menu_Bar; Title : String; Result : out Menu) is
      pragma Unreferenced (Item);
   begin
      Result.Handle :=
        Add_Menu_Native (Title'Address, Interfaces.Unsigned_32 (Title'Length));
   end Add_Menu;

   procedure Add_Item
     (Item    : in out Menu_Bar;
      To      : Menu;
      Title   : String;
      Tag     : Integer;
      Key     : String := "";
      Command : Boolean := True;
      Shift   : Boolean := False;
      Option  : Boolean := False;
      Control : Boolean := False)
   is
      Modifiers : Interfaces.Unsigned_32 := 0;
   begin
      if Command then
         Modifiers := Modifiers + 1;
      end if;
      if Shift then
         Modifiers := Modifiers + 2;
      end if;
      if Option then
         Modifiers := Modifiers + 4;
      end if;
      if Control then
         Modifiers := Modifiers + 8;
      end if;
      Add_Item_Native
        (To.Handle, Title'Address, Interfaces.Unsigned_32 (Title'Length),
         Key'Address, Interfaces.Unsigned_32 (Key'Length), Modifiers,
         Interfaces.Integer_32 (Tag));
      pragma Assert (Item.Tag_Count < Capacity, "more menu items than the bar keeps");
      Item.Tag_Count := Item.Tag_Count + 1;
      Item.Tags (Item.Tag_Count) := Tag;
   end Add_Item;

   procedure Add_Separator (Item : in out Menu_Bar; To : Menu) is
      pragma Unreferenced (Item);
   begin
      Add_Separator_Native (To.Handle);
   end Add_Separator;

   procedure Update_States
     (Item      : in out Menu_Bar;
      Validator : Widgets.Command_Validator) is
   begin
      for Tag of Item.Tags (1 .. Item.Tag_Count) loop
         declare
            State : constant Widgets.Command_State :=
              (if Validator = null then Widgets.Enabled else Validator (Tag));
         begin
            Set_State_Native
              (Interfaces.Integer_32 (Tag),
               Offered => (if State = Widgets.Not_Offered then 0 else 1),
               Enabled => (if State in Widgets.Enabled | Widgets.Ticked then 1 else 0),
               Ticked  => (if State = Widgets.Ticked then 1 else 0));
         end;
      end loop;
   end Update_States;

   function Is_Waiting (Item : Menu_Bar) return Boolean is (Item.Mail.Waiting);

   procedure Pump (Item : in out Menu_Bar; Tree : in out Widgets.Tree) is
      Tag   : Integer;
      Found : Boolean;
      Done  : Boolean;
   begin
      loop
         Item.Mail.Take (Tag, Found);
         exit when not Found;
         Widgets.Perform_Command (Tree, Tag, Done);
      end loop;
   end Pump;

   procedure Choose (Item : in out Menu_Bar; Tag : Integer) is
   begin
      Item.Mail.Put (Tag);
   end Choose;

end Pomarine.Native_Menus;
