with Ada.Unchecked_Conversion;
with Interfaces.C;
with Pomarine.Events;

package body Pomarine.Accessibility is

   use type System.Address;
   use type Interfaces.Unsigned_32;

   package C renames Interfaces.C;

   use type C.unsigned_char;
   type Adapter_Access is access all Adapter;

   --  AccessKit's interface (see rust/src/lib.rs): the roles and actions are
   --  numbered as the tables there are.

   type Node_Record is record
      Id            : Interfaces.Unsigned_64;
      Role          : C.unsigned_char;
      Toggled       : C.unsigned_char;
      Flags         : Interfaces.Unsigned_32;
      Actions       : Interfaces.Unsigned_32;
      Left, Top, Right, Bottom : C.double;
      Name          : System.Address;
      Name_Length   : Interfaces.Unsigned_32;
      Value         : System.Address;
      Value_Length  : Interfaces.Unsigned_32;
      Help          : System.Address;
      Help_Length   : Interfaces.Unsigned_32;
      Number, Minimum, Maximum, Step : C.double;
      Anchor_Node   : Interfaces.Unsigned_64;
      Anchor_Chars  : Interfaces.Unsigned_32;
      Caret_Node    : Interfaces.Unsigned_64;
      Caret_Chars   : Interfaces.Unsigned_32;
      Children      : System.Address;
      Child_Count   : Interfaces.Unsigned_32;
      Position      : Interfaces.Unsigned_32;
      Set_Size      : Interfaces.Unsigned_32;
   end record
     with Convention => C;

   Flag_Disabled     : constant Interfaces.Unsigned_32 := 2 ** 0;
   Flag_Selected     : constant Interfaces.Unsigned_32 := 2 ** 1;
   Flag_Expanded     : constant Interfaces.Unsigned_32 := 2 ** 2;
   Flag_Has_Expanded : constant Interfaces.Unsigned_32 := 2 ** 3;
   Flag_Read_Only    : constant Interfaces.Unsigned_32 := 2 ** 4;
   Flag_Invalid      : constant Interfaces.Unsigned_32 := 2 ** 5;
   Flag_Modal        : constant Interfaces.Unsigned_32 := 2 ** 6;
   Flag_Live         : constant Interfaces.Unsigned_32 := 2 ** 7;
   Flag_Has_Number   : constant Interfaces.Unsigned_32 := 2 ** 8;
   Flag_Has_Selection : constant Interfaces.Unsigned_32 := 2 ** 9;
   Flag_Named        : constant Interfaces.Unsigned_32 := 2 ** 10;

   type Activated_Callback is access procedure (User : System.Address)
     with Convention => C;

   type Acted_Callback is access procedure
     (User         : System.Address;
      Action       : Interfaces.Unsigned_32;
      Node         : Interfaces.Unsigned_64;
      Number       : C.double;
      Value        : System.Address;
      Value_Length : Interfaces.Unsigned_32;
      Anchor_Node  : Interfaces.Unsigned_64;
      Anchor_Chars : Interfaces.Unsigned_32;
      Focus_Node   : Interfaces.Unsigned_64;
      Focus_Chars  : Interfaces.Unsigned_32)
     with Convention => C;

   function Adapter_New
     (Window    : System.Address;
      Activated : Activated_Callback;
      Acted     : Acted_Callback;
      User      : System.Address) return System.Address
     with Import, Convention => C, External_Name => "ak_adapter_new";

   procedure Adapter_Free (Handle : System.Address)
     with Import, Convention => C, External_Name => "ak_adapter_free";

   function Adapter_Is_Active (Handle : System.Address) return C.unsigned_char
     with Import, Convention => C, External_Name => "ak_adapter_is_active";

   procedure Adapter_Send
     (Handle : System.Address;
      Batch  : System.Address;
      Title  : System.Address;
      Length : Interfaces.Unsigned_32)
     with Import, Convention => C, External_Name => "ak_adapter_send";

   procedure Adapter_Window_Focus (Handle : System.Address; Focused : C.unsigned_char)
     with Import, Convention => C, External_Name => "ak_adapter_window_focus";

   function Update_New
     (Root : Interfaces.Unsigned_64;
      Focus : Interfaces.Unsigned_64;
      Whole : C.unsigned_char) return System.Address
     with Import, Convention => C, External_Name => "ak_update_new";

   procedure Update_Add (Batch : System.Address; Node : access constant Node_Record)
     with Import, Convention => C, External_Name => "ak_update_add";

   --  The numbers must be as rust/src/lib.rs has them.

   function Role_Code (Item : Semantics.Role) return C.unsigned_char is
     (C.unsigned_char (Semantics.Role'Pos (Item)));

   function Action_Bits (Item : Semantics.Action_Set) return Interfaces.Unsigned_32 is
      Result : Interfaces.Unsigned_32 := 0;
   begin
      for A in Semantics.Action loop
         if Item (A) then
            Result := Result or Interfaces.Shift_Left (1, Semantics.Action'Pos (A));
         end if;
      end loop;
      return Result;
   end Action_Bits;

   pragma Assert (Semantics.Role'Pos (Semantics.Text_Run) = 26
                  and then Semantics.Role'Pos (Semantics.Window) = 1
                  and then Semantics.Action'Pos (Semantics.Hide_Tooltip) = 17);

   --  The system's requests

   procedure Activated (User : System.Address)
     with Convention => C;

   procedure Acted
     (User         : System.Address;
      Action       : Interfaces.Unsigned_32;
      Node         : Interfaces.Unsigned_64;
      Number       : C.double;
      Value        : System.Address;
      Value_Length : Interfaces.Unsigned_32;
      Anchor_Node  : Interfaces.Unsigned_64;
      Anchor_Chars : Interfaces.Unsigned_32;
      Focus_Node   : Interfaces.Unsigned_64;
      Focus_Chars  : Interfaces.Unsigned_32)
     with Convention => C;

   function Owner_Of (User : System.Address) return access Adapter is
      function Convert is new Ada.Unchecked_Conversion (System.Address, Adapter_Access);
   begin
      return Convert (User);
   end Owner_Of;

   procedure Activated (User : System.Address) is
   begin
      Owner_Of (User).Mail.Activated;
      Pomarine.Events.Wake;
   end Activated;

   procedure Acted
     (User         : System.Address;
      Action       : Interfaces.Unsigned_32;
      Node         : Interfaces.Unsigned_64;
      Number       : C.double;
      Value        : System.Address;
      Value_Length : Interfaces.Unsigned_32;
      Anchor_Node  : Interfaces.Unsigned_64;
      Anchor_Chars : Interfaces.Unsigned_32;
      Focus_Node   : Interfaces.Unsigned_64;
      Focus_Chars  : Interfaces.Unsigned_32)
   is
      Request : Semantics.Request;
   begin
      if Action > Interfaces.Unsigned_32 (Semantics.Action'Pos (Semantics.Action'Last)) then
         return;
      end if;
      Request.Doing := Semantics.Action'Val (Action);
      Request.Number := Float (Number);
      if Value /= System.Null_Address and then Value_Length > 0 then
         declare
            Text : String (1 .. Natural (Value_Length))
              with Import, Address => Value;
         begin
            Semantics.Set (Request.Contents, Text);
            Request.Has_Text := True;
         end;
      end if;
      Request.Anchor_Part := Widgets.Part_Number_Of (Widgets.From_Unsigned_64 (Anchor_Node));
      Request.Anchor := Natural (Anchor_Chars);
      Request.Focus_Part := Widgets.Part_Number_Of (Widgets.From_Unsigned_64 (Focus_Node));
      Request.Focus := Natural (Focus_Chars);
      Owner_Of (User).Mail.Put (Widgets.From_Unsigned_64 (Node), Request);
      Pomarine.Events.Wake;
   end Acted;

   protected body Mailbox is

      procedure Activated is
      begin
         Asked := True;
      end Activated;

      procedure Put (Node : Widgets.Node_Id; Request : Semantics.Request) is
      begin
         if Count = Request_Capacity then
            Lost := Lost + 1;
         else
            Queue ((First + Count - 1) mod Request_Capacity + 1) := (Node, Request);
            Count := Count + 1;
         end if;
      end Put;

      procedure Take
        (Node : out Widgets.Node_Id; Request : out Semantics.Request;
         Found : out Boolean) is
      begin
         Found := Count > 0;
         if Found then
            Node := Queue (First).Node;
            Request := Queue (First).Request;
            First := First mod Request_Capacity + 1;
            Count := Count - 1;
         else
            Node := Widgets.No_Node;
         end if;
      end Take;

      procedure Take_Activation (Was : out Boolean) is
      begin
         Was := Asked;
         Asked := False;
      end Take_Activation;

      function Waiting return Boolean is (Asked or else Count > 0);

      function Dropped return Natural is (Lost);

   end Mailbox;

   --  Attaching

   procedure Attach (Item : in out Adapter; Window : SDL3.Windows.Window) is
      Native : constant System.Address := SDL3.Windows.Native_Handle (Window);
   begin
      if Native /= System.Null_Address then
         Item.Handle :=
           Adapter_New (Native, Activated'Access, Acted'Access, Item'Address);
      end if;
   end Attach;

   overriding procedure Finalize (Item : in out Adapter) is
   begin
      Detach (Item);
   end Finalize;

   function Is_Attached (Item : Adapter) return Boolean is
     (Item.Handle /= System.Null_Address);

   procedure Detach (Item : in out Adapter) is
   begin
      if Item.Handle /= System.Null_Address then
         Adapter_Free (Item.Handle);
         Item.Handle := System.Null_Address;
      end if;
   end Detach;

   function Is_Active (Item : Adapter) return Boolean is
     (Item.Handle /= System.Null_Address
      and then Adapter_Is_Active (Item.Handle) /= 0);

   function Is_Waiting (Item : Adapter) return Boolean is (Item.Mail.Waiting);

   function Requests_Dropped (Item : Adapter) return Natural is (Item.Mail.Dropped);

   procedure Window_Focus_Changed (Item : in out Adapter; Focused : Boolean) is
   begin
      Adapter_Window_Focus (Item.Handle, (if Focused then 1 else 0));
   end Window_Focus_Changed;

   --  Updating

   procedure Update (Item : in out Adapter; Tree : in out Widgets.Tree) is
      Node    : Widgets.Node_Id;
      Request : Semantics.Request;
      Found   : Boolean;
      Done    : Boolean;
      Asked   : Boolean;
   begin
      Item.Mail.Take_Activation (Asked);
      if Asked then
         Item.Whole := True;
      end if;
      loop
         Item.Mail.Take (Node, Request, Found);
         exit when not Found;
         Widgets.Act (Tree, Node, Request, Done);
      end loop;
      if Is_Active (Item) then
         Widgets.Describe_Changes (Tree, Item, Whole => Item.Whole);
         Item.Whole := False;
      end if;
   end Update;

   overriding procedure Begin_Update
     (Self : in out Adapter;
      Root : Widgets.Node_Id;
      Focused : Widgets.Node_Id;
      Whole : Boolean) is
   begin
      Self.Pending :=
        Update_New
          (Widgets.To_Unsigned_64 (Root), Widgets.To_Unsigned_64 (Focused),
           (if Whole then 1 else 0));
   end Begin_Update;

   overriding procedure Describe_Node
     (Self     : in out Adapter;
      Id       : Widgets.Node_Id;
      Facts    : Semantics.Description;
      Bounds   : Semantics.Rectangle;
      Children : Widgets.Node_Id_Array)
   is
      Name  : constant String := Semantics.To_String (Facts.Name);
      Value : constant String := Semantics.To_String (Facts.Value);
      Help  : constant String := Semantics.To_String (Facts.Help);
      Kids  : array (1 .. Natural'Max (1, Children'Length)) of Interfaces.Unsigned_64;
      Flags : Interfaces.Unsigned_32 := 0;
      Raw   : aliased Node_Record;

      procedure Flag (On : Boolean; Bit : Interfaces.Unsigned_32) is
      begin
         if On then
            Flags := Flags or Bit;
         end if;
      end Flag;
   begin
      for I in Children'Range loop
         Kids (I - Children'First + 1) := Widgets.To_Unsigned_64 (Children (I));
      end loop;
      Flag (Facts.Disabled, Flag_Disabled);
      Flag (Facts.Selected, Flag_Selected);
      Flag (Facts.Expanded, Flag_Expanded);
      Flag (Facts.Has_Expanded, Flag_Has_Expanded);
      Flag (Facts.Read_Only, Flag_Read_Only);
      Flag (Facts.Invalid, Flag_Invalid);
      Flag (Facts.Modal, Flag_Modal);
      Flag (Facts.Live, Flag_Live);
      Flag (Facts.Has_Number, Flag_Has_Number);
      Flag (Facts.Has_Selection, Flag_Has_Selection);
      Flag (Semantics.Is_Named (Facts), Flag_Named);

      Raw :=
        (Id           => Widgets.To_Unsigned_64 (Id),
         Role         => Role_Code (Facts.Kind),
         Toggled      => C.unsigned_char (Semantics.Toggle'Pos (Facts.Checked)),
         Flags        => Flags,
         Actions      => Action_Bits (Facts.Actions),
         Left         => C.double (Bounds.Left),
         Top          => C.double (Bounds.Top),
         Right        => C.double (Bounds.Right),
         Bottom       => C.double (Bounds.Bottom),
         Name         => (if Name'Length > 0 then Name'Address else System.Null_Address),
         Name_Length  => Interfaces.Unsigned_32 (Name'Length),
         Value        => (if Value'Length > 0 then Value'Address else System.Null_Address),
         Value_Length => Interfaces.Unsigned_32 (Value'Length),
         Help         => (if Help'Length > 0 then Help'Address else System.Null_Address),
         Help_Length  => Interfaces.Unsigned_32 (Help'Length),
         Number       => C.double (Facts.Number),
         Minimum      => C.double (Facts.Minimum),
         Maximum      => C.double (Facts.Maximum),
         Step         => C.double (Facts.Step),
         Anchor_Node  => (if Facts.Has_Selection
                          then Widgets.To_Unsigned_64
                                 (Widgets.Part_Of (Id, Facts.Anchor.Part))
                          else 0),
         Anchor_Chars => Interfaces.Unsigned_32 (Facts.Anchor.Characters),
         Caret_Node   => (if Facts.Has_Selection
                          then Widgets.To_Unsigned_64
                                 (Widgets.Part_Of (Id, Facts.Caret.Part))
                          else 0),
         Caret_Chars  => Interfaces.Unsigned_32 (Facts.Caret.Characters),
         Children     => (if Children'Length > 0 then Kids'Address else System.Null_Address),
         Child_Count  => Interfaces.Unsigned_32 (Children'Length),
         Position     => Interfaces.Unsigned_32 (Facts.Position),
         Set_Size     => Interfaces.Unsigned_32 (Facts.Set_Size));
      Update_Add (Self.Pending, Raw'Access);
   end Describe_Node;

   overriding procedure End_Update (Self : in out Adapter) is
   begin
      Adapter_Send (Self.Handle, Self.Pending, System.Null_Address, 0);
      Self.Pending := System.Null_Address;
   end End_Update;

end Pomarine.Accessibility;
