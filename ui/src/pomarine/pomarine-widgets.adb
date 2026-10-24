with Ada.Unchecked_Conversion;
with Ada.Unchecked_Deallocation;
package body Pomarine.Widgets is

   package Renderers renames SDL3.Windows.Renderers;

   use type Pomarine.Events.Event_Kind;
   use type Interfaces.Unsigned_64;
   use type Interfaces.Unsigned_32;
   use type Pomarine.Events.Milliseconds;
   use type Semantics.Role;

   No_Yoga : Yoga.Nodes.Node;
   --  A node that is none.

   --  Boxes

   Far : constant := 2 ** 28;
   --  No pixel is further than this from the origin, so that sums and
   --  differences of two of them stay in Integer.

   function To_Pixel (Value : Float) return Integer
   with Post => To_Pixel'Result in -Far .. Far;
   --  Value as a pixel, kept within Far of the origin: a layout that has
   --  gone wrong (not a number, infinite, or beyond any screen) must not
   --  stop the application from drawing.

   function To_Pixel (Value : Float) return Integer is
     (if Value /= Value then 0
      elsif Value <= -Float (Far) then -Far
      elsif Value >= Float (Far) then Far
      else Integer (Value));

   function Around (Across, Down, Wide, High : Float) return Pixel_Box
   with Post => Around'Result.Left in -Far .. Far
                  and then Around'Result.Top in -Far .. Far
                  and then Around'Result.Width in -2 * Far .. 2 * Far
                  and then Around'Result.Height in -2 * Far .. 2 * Far
                  and then (if Wide >= 0.0 and then High >= 0.0
                            then Around'Result.Width >= 0 and then Around'Result.Height >= 0);
   --  The pixels that any of the box touches. A position or size that is
   --  not a number counts as zero, and one beyond Far as Far.

   function Around (Across, Down, Wide, High : Float) return Pixel_Box is
      function Number (Value : Float) return Float is
        (if Value /= Value then 0.0 else Value);

      First  : constant Integer := To_Pixel (Float'Floor (Number (Across)));
      Above  : constant Integer := To_Pixel (Float'Floor (Number (Down)));
      Last   : constant Integer :=
        To_Pixel (Float'Ceiling (Number (Across) + Number (Wide)));
      Below  : constant Integer :=
        To_Pixel (Float'Ceiling (Number (Down) + Number (High)));
   begin
      return (First, Above, Last - First, Below - Above);
   end Around;

   function Union (A, B : Pixel_Box) return Pixel_Box is
   begin
      if Is_Empty (A) then
         return B;
      elsif Is_Empty (B) then
         return A;
      end if;
      declare
         First  : constant Integer := Integer'Min (A.Left, B.Left);
         Above  : constant Integer := Integer'Min (A.Top, B.Top);
         Last   : constant Integer :=
           Integer'Max (A.Left + A.Width, B.Left + B.Width);
         Below  : constant Integer :=
           Integer'Max (A.Top + A.Height, B.Top + B.Height);
      begin
         return (First, Above, Last - First, Below - Above);
      end;
   end Union;

   function Intersection (A, B : Pixel_Box) return Pixel_Box is
      First  : constant Integer := Integer'Max (A.Left, B.Left);
      Above  : constant Integer := Integer'Max (A.Top, B.Top);
      Last   : constant Integer :=
        Integer'Min (A.Left + A.Width, B.Left + B.Width);
      Below  : constant Integer :=
        Integer'Min (A.Top + A.Height, B.Top + B.Height);
   begin
      return (First, Above,
              Integer'Max (0, Last - First), Integer'Max (0, Below - Above));
   end Intersection;

   --  The seldom-used parts of widgets, kept apart from them: the names the
   --  application gave, and its handlers. Most widgets have none, and the
   --  rest do not use them while they are drawn and walked over, so they
   --  are not in the way of those, which are most of what is done.

   type Cold_Block is record
      Name  : Semantics.Text;
      Help  : Semantics.Text;
      Hooks : Hook_Array;
      Link  : Natural;
      --  While it is given back: the next that is.
   end record;
   pragma Suppress_Initialization (Cold_Block);

   Chunk_Size : constant := 256;
   type Cold_Chunk is array (1 .. Chunk_Size) of aliased Cold_Block;
   type Cold_Chunk_Access is access Cold_Chunk;
   Chunks : array (1 .. Node_Capacity / Chunk_Size + 1) of Cold_Chunk_Access := [others => null];
   Cold_Free : Natural := 0;
   Cold_Fresh : Natural := 0;
   --  Made a chunk at a time, as they are wanted, and never moved, so that
   --  what runs a widget's handlers may make more. A block the application
   --  gave back is used again before one never used.

   function Block (Index : Positive) return not null access Cold_Block is
     (Chunks ((Index - 1) / Chunk_Size + 1) ((Index - 1) mod Chunk_Size + 1)'Access);

   function Cold (Item : in out Widget'Class) return Natural is
      Index : Natural;
   begin
      if Item.Cold = 0 then
         if Cold_Free /= 0 then
            Index := Cold_Free;
            Cold_Free := Block (Index).Link;
         else
            pragma Assert (Cold_Fresh < Node_Capacity,
                           "more widgets with names or handlers than there is room for");
            Cold_Fresh := Cold_Fresh + 1;
            Index := Cold_Fresh;
            if Chunks ((Index - 1) / Chunk_Size + 1) = null then
               Chunks ((Index - 1) / Chunk_Size + 1) := new Cold_Chunk;
            end if;
         end if;
         Block (Index).all := (Name => Semantics.Empty_Text, Help => Semantics.Empty_Text,
                               Hooks => [others => <>], Link => 0);
         Item.Cold := Index;
      end if;
      return Item.Cold;
   end Cold;
   --  Where Item's seldom-used parts are, made if it has none.

   procedure Give_Back_Cold (Item : in out Widget'Class) is
   begin
      if Item.Cold /= 0 then
         Block (Item.Cold).Link := Cold_Free;
         Cold_Free := Item.Cold;
         Item.Cold := 0;
      end if;
   end Give_Back_Cold;

   --  The table

   Slot_Bits : constant := 21;
   Use_Bits  : constant := 19;
   --  Bits of a slot and of a use of it that a part's number keeps.

   procedure Free_Table is new Ada.Unchecked_Deallocation (Node_Table, Table_Access);

   function Object (Item : Tree; Slot : Node_Index) return Widget_Access is
     (if Slot = 0 then null else Item.Nodes.Object (Slot));
   --  The widget in Slot, or null for none.

   function Box_Of (Item : Tree; Slot : Node_Index) return Pixel_Box is
     (Around (Item.Nodes.Spot (Slot).Left, Item.Nodes.Spot (Slot).Top,
              Item.Nodes.Spot (Slot).Wide, Item.Nodes.Spot (Slot).High));

   function Box_Of (Item : Widget'Class) return Pixel_Box is
     (Box_Of (Item.Owner.all, Item.Slot));

   function Is_Attached (Item : Widget'Class) return Boolean is
     (Item.Owner /= null);

   function Id_Of (Item : Widget'Class) return Node_Id is
     (if Item.Owner = null then No_Node
      else (Item.Slot, Item.Owner.Nodes.Use_Number (Item.Slot), 0));

   function Part_Id (Item : Widget'Class; Part : Positive) return Node_Id is
     (if Item.Owner = null then No_Node
      else (Item.Slot, Item.Owner.Nodes.Use_Number (Item.Slot), Part));

   function Is_Live (Item : Tree; Id : Node_Id) return Boolean is
     (Id.Slot /= 0 and then Item.Nodes /= null
      and then Id.Slot <= Item.Nodes.Fresh
      and then Item.Nodes.Object (Id.Slot) /= null
      and then (if Id.Part = 0 then Item.Nodes.Use_Number (Id.Slot) = Id.Use_Number
                else Item.Nodes.Use_Number (Id.Slot) mod 2 ** Use_Bits
                     = Id.Use_Number));

   function Resolve (Item : Tree; Id : Node_Id) return Widget_Access is
     (if Is_Live (Item, Id) then Item.Nodes.Object (Id.Slot) else null);

   function Id_Of_Slot (Item : Tree; Slot : Node_Index) return Node_Id is
     (if Slot = 0 then No_Node else (Slot, Item.Nodes.Use_Number (Slot), 0));

   function Part_Of (Id : Node_Id; Part : Natural) return Node_Id is
     ((Id.Slot, Id.Use_Number, Part));

   function Part_Number_Of (Id : Node_Id) return Natural is (Id.Part);

   function Root_Id (Item : Tree) return Node_Id is
     (Id_Of_Slot (Item, Item.Root));

   function Parent_Id (Item : Tree; Id : Node_Id) return Node_Id is
     (Id_Of_Slot (Item, Item.Nodes.Parent (Id.Slot)));

   function First_Child_Id (Item : Tree; Id : Node_Id) return Node_Id is
     (Id_Of_Slot (Item, Item.Nodes.First (Id.Slot)));

   function Next_Sibling_Id (Item : Tree; Id : Node_Id) return Node_Id is
     (Id_Of_Slot (Item, Item.Nodes.Next (Id.Slot)));

   --  A number for an id: the use of the slot in the high half and the
   --  slot in the low, for a widget; with the top bit, and a part's number
   --  between, for a part, where the use is cut to fit.

   function To_Unsigned_64 (Id : Node_Id) return Interfaces.Unsigned_64 is
     (if Id.Part = 0
      then Interfaces.Shift_Left (Interfaces.Unsigned_64 (Id.Use_Number), 32)
           or Interfaces.Unsigned_64 (Id.Slot)
      else 16#8000_0000_0000_0000#
           or Interfaces.Shift_Left (Interfaces.Unsigned_64 (Id.Part), Slot_Bits + Use_Bits)
           or Interfaces.Shift_Left
                (Interfaces.Unsigned_64 (Id.Use_Number mod 2 ** Use_Bits), Slot_Bits)
           or Interfaces.Unsigned_64 (Id.Slot));

   function From_Unsigned_64 (Value : Interfaces.Unsigned_64) return Node_Id is
   begin
      if (Value and 16#8000_0000_0000_0000#) /= 0 then
         declare
            Slot : constant Interfaces.Unsigned_64 := Value and (2 ** Slot_Bits - 1);
            Used : constant Interfaces.Unsigned_64 :=
              Interfaces.Shift_Right (Value, Slot_Bits) and (2 ** Use_Bits - 1);
            Part : constant Interfaces.Unsigned_64 :=
              Interfaces.Shift_Right (Value, Slot_Bits + Use_Bits) and (2 ** 23 - 1);
         begin
            if Slot > Interfaces.Unsigned_64 (Node_Capacity) or else Part = 0 then
               return No_Node;
            end if;
            return (Node_Index (Slot), Natural (Used), Natural (Part));
         end;
      end if;
      declare
         Slot : constant Interfaces.Unsigned_64 := Value and 16#FFFF_FFFF#;
         Used : constant Interfaces.Unsigned_64 := Interfaces.Shift_Right (Value, 32);
      begin
         if Slot > Interfaces.Unsigned_64 (Node_Capacity)
           or else Used > Interfaces.Unsigned_64 (Natural'Last)
         then
            return No_Node;
         end if;
         return (Node_Index (Slot), Natural (Used), 0);
      end;
   end From_Unsigned_64;

   function Image (Id : Node_Id) return String is
      function Trim (Value : Natural) return String is
         Text : constant String := Natural'Image (Value);
      begin
         return Text (Text'First + 1 .. Text'Last);
      end Trim;
   begin
      return (if Id = No_Node then "none"
              else Trim (Id.Slot) & "." & Trim (Id.Use_Number)
                   & (if Id.Part = 0 then "" else ":" & Trim (Id.Part)));
   end Image;

   procedure Mark_Dirty (Item : in out Widget'Class; What : Dirty_Kind) is
      Table : Node_Table renames Item.Owner.Nodes.all;
   begin
      case What is
         when Layout_Dirty =>
            Table.Layout_Dirty (Item.Slot) := True;
            Item.Owner.Layout_Pending := True;
         when Paint_Dirty =>
            Table.Paint_Dirty (Item.Slot) := True;
         when Semantics_Dirty =>
            Table.Semantics_Dirty (Item.Slot) := True;
      end case;
   end Mark_Dirty;

   function Is_Dirty (Item : Widget'Class; What : Dirty_Kind) return Boolean is
     (Item.Owner /= null
      and then (case What is
                   when Layout_Dirty => Item.Owner.Nodes.Layout_Dirty (Item.Slot),
                   when Paint_Dirty => Item.Owner.Nodes.Paint_Dirty (Item.Slot),
                   when Semantics_Dirty =>
                     Item.Owner.Nodes.Semantics_Dirty (Item.Slot)));

   --  The widgets

   function Node (Item : Widget'Class) return Yoga.Nodes.Node is
     (Item.Owner.Nodes.Yoga_Node (Item.Slot));

   function Parent_Of (Item : Widget'Class) return Widget_Access is
     (if Item.Owner = null then null
      else Object (Item.Owner.all, Item.Owner.Nodes.Parent (Item.Slot)));

   function Child_Count (Item : Widget'Class) return Natural is
     (if Item.Owner = null then 0 else Item.Owner.Nodes.Children (Item.Slot));

   function Child_At (Item : Widget'Class; Index : Positive)
      return Widget_Access
   is
      Table  : Node_Table renames Item.Owner.Nodes.all;
      Result : Node_Index := Table.First (Item.Slot);
   begin
      for Skipped in 2 .. Index loop
         Result := Table.Next (Result);
      end loop;
      return Table.Object (Result);
   end Child_At;

   function Left_Of (Item : Widget'Class) return Float is
     (if Item.Owner = null then 0.0 else Item.Owner.Nodes.Spot (Item.Slot).Left);
   function Top_Of (Item : Widget'Class) return Float is
     (if Item.Owner = null then 0.0 else Item.Owner.Nodes.Spot (Item.Slot).Top);
   function Width_Of (Item : Widget'Class) return Float is
     (if Item.Owner = null then 0.0 else Item.Owner.Nodes.Spot (Item.Slot).Wide);
   function Height_Of (Item : Widget'Class) return Float is
     (if Item.Owner = null then 0.0 else Item.Owner.Nodes.Spot (Item.Slot).High);
   function Is_Placed (Item : Widget'Class) return Boolean is
     (Item.Owner /= null and then Item.Owner.Nodes.Spot (Item.Slot).Placed);

   function Contains (Item : Tree; Slot : Node_Index; X, Y : Float) return Boolean is
      Box : Spot renames Item.Nodes.Spot (Slot);
   begin
      return X >= Box.Left and then X < Box.Left + Box.Wide
        and then Y >= Box.Top and then Y < Box.Top + Box.High;
   end Contains;

   function Contains (Item : Widget'Class; X, Y : Float) return Boolean is
     (Item.Owner /= null and then Contains (Item.Owner.all, Item.Slot, X, Y));

   function Is_Hovered (Item : Widget'Class) return Boolean is
     (Item.Owner /= null and then Item.Owner.Nodes.Hovered (Item.Slot));

   function Painting_Part (Item : Widget'Class) return Pixel_Box is
     (Item.Owner.Nodes.Paint_Box (Item.Slot));

   function Is_Visible (Item : Widget'Class) return Boolean is
     (Item.Owner = null or else Item.Owner.Nodes.Spot (Item.Slot).Visible);

   function Is_Shown (Item : Widget'Class) return Boolean is
   begin
      if Item.Owner = null then
         return True;
      end if;
      declare
         Table    : Node_Table renames Item.Owner.Nodes.all;
         Climbing : Node_Index := Item.Slot;
      begin
         while Climbing /= 0 loop
            if not Table.Spot (Climbing).Visible then
               return False;
            end if;
            Climbing := Table.Parent (Climbing);
         end loop;
         return True;
      end;
   end Is_Shown;

   function Has_Focus (Item : Widget'Class) return Boolean is
     (Item.Owner /= null and then Item.Owner.Nodes.Focused (Item.Slot));

   function Is_Focus_Visible (Item : Widget'Class) return Boolean is
     (Has_Focus (Item) and then Item.Owner.Keyboard_Focus);

   function Density (Item : Widget'Class) return Float is
     (Item.Owner.Density);

   function Is_Settled (Item : Widget'Class) return Boolean is
     (Item.Owner.Settled);

   function Clipboard (Item : Widget'Class) return Clipboard_Access is
     (Item.Owner.Board);

   procedure Handle
     (Item    : in out Widget;
      Event   : Pomarine.Events.Event;
      Handled : out Boolean)
   is
      pragma Unreferenced (Item, Event);
   begin
      Handled := False;
   end Handle;

   --  Measuring

   function To_Widget is new Ada.Unchecked_Conversion (System.Address, Widget_Access);

   function Measure_Bridge
     (Context     : System.Address;
      Width       : Float;
      Width_Mode  : Yoga.Nodes.Measure_Mode;
      Height      : Float;
      Height_Mode : Yoga.Nodes.Measure_Mode) return Yoga.Nodes.Measured_Size;
   --  What the layout calls to measure a node: the widget it is of does.

   function Measure_Bridge
     (Context     : System.Address;
      Width       : Float;
      Width_Mode  : Yoga.Nodes.Measure_Mode;
      Height      : Float;
      Height_Mode : Yoga.Nodes.Measure_Mode) return Yoga.Nodes.Measured_Size
   is
      Result : Yoga.Nodes.Measured_Size;
   begin
      Measure (To_Widget (Context).all, Width, Width_Mode, Height, Height_Mode, Result);
      return Result;
   end Measure_Bridge;

   procedure Measure
     (Item      : in out Widget;
      Room_Wide : Float;
      Wide_Mode : Yoga.Nodes.Measure_Mode;
      Room_High : Float;
      High_Mode : Yoga.Nodes.Measure_Mode;
      Result    : out Yoga.Nodes.Measured_Size)
   is
      pragma Unreferenced (Item, Room_Wide, Wide_Mode, Room_High, High_Mode);
   begin
      Result := (Width => 0.0, Height => 0.0);
   end Measure;

   procedure Start_Measuring (Item : in out Widget'Class) is
   begin
      Yoga.Nodes.Set_Measured (Node (Item), Item'Address);
   end Start_Measuring;

   procedure Set_Measured (Item : in out Widget'Class; To : Boolean := True) is
   begin
      Item.Measured := To;
      if To and then Item.Owner /= null then
         Start_Measuring (Item);
         Yoga.Nodes.Mark_Dirty (Node (Item));
         Request_Layout (Item);
      end if;
   end Set_Measured;

   procedure Content_Changed (Item : in out Widget'Class) is
   begin
      if Item.Owner /= null and then Item.Measured then
         Yoga.Nodes.Mark_Dirty (Node (Item));
         Request_Layout (Item);
      end if;
   end Content_Changed;

   --  Building

   function Has_Root (Item : Tree) return Boolean is (Item.Root /= 0);

   procedure Set_Listener (Item : in out Tree; To : not null access Listener'Class) is
   begin
      Item.Hearer := Listener_Access (To);
   end Set_Listener;

   procedure Set_Listener (Item : in out Widget'Class; To : access Listener'Class) is
   begin
      Item.Own := Listener_Access (To);
   end Set_Listener;

   procedure Set_Tag
     (Item     : in out Widget'Class;
      Tag      : Integer;
      Index    : Natural := 0;
      Reflects : Boolean := True) is
   begin
      Item.Tag := Tag;
      Item.Index := Index;
      Item.Reflects := Reflects;
   end Set_Tag;

   function Tag_Of (Item : Widget'Class) return Integer is (Item.Tag);

   function Index_Of (Item : Widget'Class) return Natural is (Item.Index);

   procedure Set_Hook
     (Item : in out Widget'Class;
      Kind : Event_Kind;
      Run  : not null Hook_Runner;
      Self, Proc : System.Address) is
   begin
      Block (Cold (Item)).all.Hooks (Kind) := (Used => True, Run => Run, Self => Self, Proc => Proc);
   end Set_Hook;

   procedure Clear_Hook (Item : in out Widget'Class; Kind : Event_Kind) is
   begin
      if Item.Cold /= 0 then
         Block (Item.Cold).all.Hooks (Kind) := (others => <>);
      end if;
   end Clear_Hook;

   function To_Plain is new Ada.Unchecked_Conversion (System.Address, Plain_Handler);
   function To_Address is new Ada.Unchecked_Conversion (Plain_Handler, System.Address);

   procedure Run_Plain
     (Self, Proc : System.Address;
      Source     : in out Widget'Class;
      Event      : Widget_Event);

   procedure Run_Plain
     (Self, Proc : System.Address;
      Source     : in out Widget'Class;
      Event      : Widget_Event)
   is
      pragma Unreferenced (Self);
   begin
      To_Plain (Proc) (Source, Event);
   end Run_Plain;

   procedure Set_Handler
     (Item    : in out Widget'Class;
      Kind    : Event_Kind;
      Do_This : not null Plain_Handler) is
   begin
      Set_Hook (Item, Kind, Run_Plain'Access, System.Null_Address, To_Address (Do_This));
   end Set_Handler;

   procedure On_Click
     (Item    : in out Widget'Class;
      Do_This : not null Plain_Handler) is
   begin
      Set_Handler (Item, Click, Do_This);
   end On_Click;

   procedure Clear_Handler (Item : in out Widget'Class; Kind : Event_Kind) is
   begin
      Clear_Hook (Item, Kind);
   end Clear_Handler;

   function Has_Hook (Item : Widget'Class; Kind : Event_Kind) return Boolean is
     (Item.Cold /= 0 and then Block (Item.Cold).all.Hooks (Kind).Used);

   function Run_Hooks (Item : in out Widget'Class; Event : Widget_Event) return Boolean is
   begin
      if Item.Cold = 0 or else not Block (Item.Cold).all.Hooks (Event.Kind).Used then
         return False;
      end if;
      declare
         Each : constant Hook := Block (Item.Cold).all.Hooks (Event.Kind);
      begin
         Each.Run (Each.Self, Each.Proc, Item, Event);
      end;
      return True;
   end Run_Hooks;
   --  Whether any handler of the widget's own took the event.

   procedure Deliver (Item : in out Tree) is
   begin
      if Item.Delivering then
         return;
      end if;
      Item.Delivering := True;
      while Item.Queued > 0 loop
         declare
            Next : constant Queued_Event := Item.Queue (Item.Queue_First);
            From : Widget_Access;
         begin
            Item.Queue_First := Item.Queue_First mod Queue_Capacity + 1;
            Item.Queued := Item.Queued - 1;
            --  Taken out of the tree since it spoke: nobody to answer.
            From := Resolve (Item, Next.Source);
            if From = null then
               null;
            elsif Next.Posted.Run /= null then
               Next.Posted.Run (Next.Posted.Self, Next.Posted.Proc, From.all, Next.Code, Next.Value);
            elsif not Run_Hooks (From.all, Next.Event) and then Next.Target /= null then
               Handle_Event (Next.Target.all, From.all, Next.Event);
            end if;
         end;
      end loop;
      Item.Delivering := False;
   exception
      when others =>
         Item.Delivering := False;
         raise;
   end Deliver;

   function Made_Event
     (Kind   : Event_Kind;
      Tag    : Integer;
      Index  : Natural;
      Row    : Natural;
      Across, Down : Float;
      Action : Natural) return Widget_Event
   is
      Result : Widget_Event (Kind);
   begin
      Result.Tag := Tag;
      Result.Index := Index;
      case Kind is
         when Choose =>
            Result.Row := Row;
         when Act =>
            Result.Row := Row;
            Result.Action := Action;
         when Drag | Move | Resize =>
            Result.Across := Across;
            Result.Down := Down;
         when others =>
            null;
      end case;
      return Result;
   end Made_Event;

   procedure Notify
     (Item   : in out Widget'Class;
      Kind   : Event_Kind;
      Row    : Natural := 0;
      Across : Float := 0.0;
      Down   : Float := 0.0;
      Action : Natural := 0)
   is
      Home   : constant Tree_Access := Item.Owner;
   begin
      if Home = null then
         return;
      end if;
      declare
         Target : constant Listener_Access :=
           (if Item.Own /= null then Item.Own else Home.Hearer);
      begin
         if Target = null and then not Has_Hook (Item, Kind) then
            return;
         end if;
         if Home.Queued = Queue_Capacity and then not Home.Delivering then
            Deliver (Home.all);
         end if;
         pragma Assert (Home.Queued < Queue_Capacity, "more events than the tree can keep");
         Home.Queue ((Home.Queue_First + Home.Queued - 1) mod Queue_Capacity + 1) :=
           (Source => Id_Of (Item),
            Target => Target,
            Event  => Made_Event (Kind, Item.Tag, Item.Index, Row, Across, Down, Action),
            Posted => <>,
            Code   => 0,
            Value  => 0);
         Home.Queued := Home.Queued + 1;
      end;
   end Notify;

   procedure Post
     (Item  : in out Widget'Class;
      Using : Posted_Hook;
      Code  : Natural := 0;
      Value : Natural := 0)
   is
      Home : constant Tree_Access := Item.Owner;
   begin
      if Home = null or else Using.Run = null then
         return;
      end if;
      if Home.Queued = Queue_Capacity and then not Home.Delivering then
         Deliver (Home.all);
      end if;
      pragma Assert (Home.Queued < Queue_Capacity, "more events than the tree can keep");
      Home.Queue ((Home.Queue_First + Home.Queued - 1) mod Queue_Capacity + 1) :=
        (Source => Id_Of (Item),
         Target => null,
         Event  => Made_Event (Click, Item.Tag, Item.Index, 0, 0.0, 0.0, 0),
         Posted => Using,
         Code   => Code,
         Value  => Value);
      Home.Queued := Home.Queued + 1;
   end Post;

   procedure Take_Slot
     (Home : in out Tree; Item : in out Widget'Class; Slot : out Node_Index)
   is
      Table : Node_Table renames Home.Nodes.all;
   begin
      if Table.Free /= 0 then
         Slot := Table.Free;
         Table.Free := Table.Next (Slot);
      else
         pragma Assert (Table.Fresh < Node_Capacity,
                        "more widgets than the tree can hold");
         Table.Fresh := Table.Fresh + 1;
         Slot := Table.Fresh;
         Table.Use_Number (Slot) := 1;
      end if;
      Table.Used := Table.Used + 1;
      Table.Object (Slot) := Item'Unchecked_Access;
      Table.Parent (Slot) := 0;
      Table.First (Slot) := 0;
      Table.Last (Slot) := 0;
      Table.Next (Slot) := 0;
      Table.Children (Slot) := 0;
      Table.Spot (Slot).Left := 0.0;
      Table.Spot (Slot).Top := 0.0;
      Table.Spot (Slot).Wide := 0.0;
      Table.Spot (Slot).High := 0.0;
      Table.Paint_Box (Slot) := (others => 0);
      Table.Spot (Slot).Placed := False;
      Table.Hovered (Slot) := False;
      Table.Focused (Slot) := False;
      Table.Spot (Slot).Visible := True;
      Table.Known (Slot) := False;
      Home.Told_States (Slot) := Enabled;
      Table.Layout_Dirty (Slot) := True;
      Table.Paint_Dirty (Slot) := True;
      Table.Semantics_Dirty (Slot) := True;
      Item.Owner := Home'Unchecked_Access;
      Item.Slot := Slot;
   end Take_Slot;

   procedure Give_Back (Home : in out Tree; Slot : Node_Index) is
      Table : Node_Table renames Home.Nodes.all;
      Gone  : constant Widget_Access := Table.Object (Slot);
   begin
      if Gone /= null then
         Gone.Owner := null;
         Gone.Slot := 0;
      end if;
      Table.Object (Slot) := null;
      Table.Use_Number (Slot) := Table.Use_Number (Slot) + 1;
      Table.Yoga_Node (Slot) := No_Yoga;
      Table.Next (Slot) := Table.Free;
      Table.Free := Slot;
      Table.Used := Table.Used - 1;
   end Give_Back;

   procedure Give_Back_All (Home : in out Tree; Slot : Node_Index) is
      Child : Node_Index := Home.Nodes.First (Slot);
      Next  : Node_Index;
   begin
      while Child /= 0 loop
         Next := Home.Nodes.Next (Child);
         Give_Back_All (Home, Child);
         Child := Next;
      end loop;
      Give_Back (Home, Slot);
   end Give_Back_All;
   --  Slot, and all in it, as they were before they were added.

   procedure Set_Root (Item : in out Tree; Root : in out Widget'Class) is
      Slot : Node_Index;
   begin
      if Item.Nodes = null then
         Item.Nodes := new Node_Table;
         Item.Nodes.Free := 0;
         Item.Nodes.Fresh := 0;
         Item.Nodes.Used := 0;
         Yoga.Nodes.Set_Measure_Handler (Measure_Bridge'Access);
      end if;
      Take_Slot (Item, Root, Slot);
      Item.Nodes.Yoga_Node (Slot) := Yoga.Nodes.Root (Item.Yoga_Tree);
      Item.Root := Slot;
   end Set_Root;

   procedure Add (Parent : in out Widget'Class; Child : in out Widget'Class) is
      Home  : constant Tree_Access := Parent.Owner;
      Table : Node_Table renames Home.Nodes.all;
      Above : constant Node_Index := Parent.Slot;
      Slot  : Node_Index;
   begin
      Take_Slot (Home.all, Child, Slot);
      Table.Parent (Slot) := Above;
      Table.Yoga_Node (Slot) := Yoga.Nodes.New_Child (Table.Yoga_Node (Above));
      if Child.Measured then
         Start_Measuring (Child);
      end if;
      if Table.Last (Above) = 0 then
         Table.First (Above) := Slot;
      else
         Table.Next (Table.Last (Above)) := Slot;
      end if;
      Table.Last (Above) := Slot;
      Table.Children (Above) := Table.Children (Above) + 1;
      Table.Semantics_Dirty (Above) := True;
   end Add;

   procedure Add
     (Parent : in out Widget'Class; First, Second : in out Widget'Class) is
   begin
      Add (Parent, First);
      Add (Parent, Second);
   end Add;

   procedure Add
     (Parent : in out Widget'Class; First, Second, Third : in out Widget'Class) is
   begin
      Add (Parent, First);
      Add (Parent, Second);
      Add (Parent, Third);
   end Add;

   procedure Add
     (Parent : in out Widget'Class;
      First, Second, Third, Fourth : in out Widget'Class) is
   begin
      Add (Parent, First);
      Add (Parent, Second);
      Add (Parent, Third);
      Add (Parent, Fourth);
   end Add;

   procedure Add
     (Parent : in out Widget'Class;
      First, Second, Third, Fourth, Fifth : in out Widget'Class) is
   begin
      Add (Parent, First);
      Add (Parent, Second);
      Add (Parent, Third);
      Add (Parent, Fourth);
      Add (Parent, Fifth);
   end Add;

   procedure Add_Before
     (Parent : in out Widget'Class;
      Child  : in out Widget'Class;
      Before : Widget'Class)
   is
      Home  : constant Tree_Access := Parent.Owner;
      Table : Node_Table renames Home.Nodes.all;
      Above : constant Node_Index := Parent.Slot;
      Index : Natural := 0;
      Up    : Node_Index := Table.First (Above);
      Prior : Node_Index := 0;
      Slot  : Node_Index;
   begin
      while Up /= Before.Slot loop
         Prior := Up;
         Up := Table.Next (Up);
         Index := Index + 1;
      end loop;
      Take_Slot (Home.all, Child, Slot);
      Table.Parent (Slot) := Above;
      Table.Yoga_Node (Slot) :=
        Yoga.Nodes.New_Child_At (Table.Yoga_Node (Above), Index);
      if Child.Measured then
         Start_Measuring (Child);
      end if;
      Table.Next (Slot) := Up;
      if Prior = 0 then
         Table.First (Above) := Slot;
      else
         Table.Next (Prior) := Slot;
      end if;
      Table.Children (Above) := Table.Children (Above) + 1;
      Table.Semantics_Dirty (Above) := True;
   end Add_Before;

   --  Walking the tree: parents before their children, and children in
   --  order.

   function Following_Shown (Item : Tree; Slot : Node_Index) return Node_Index;
   --  As Following, but not into widgets that are hidden.

   function Following_Shown (Item : Tree; Slot : Node_Index) return Node_Index is
      Table    : Node_Table renames Item.Nodes.all;
      Climbing : Node_Index := Slot;
   begin
      if Table.First (Slot) /= 0 and then Table.Spot (Slot).Visible then
         return Table.First (Slot);
      end if;
      while Climbing /= 0 loop
         if Table.Next (Climbing) /= 0 then
            return Table.Next (Climbing);
         end if;
         Climbing := Table.Parent (Climbing);
      end loop;
      return 0;
   end Following_Shown;

   --  What a tree shares

   procedure Rescale (Item : in out Tree; Slot : Node_Index; By : Float);
   --  Put the sizes of the widget at Slot, and of those below it, in
   --  another density, as they were made in points of the one before.

   procedure Rescale (Item : in out Tree; Slot : Node_Index; By : Float) is
      Table : Node_Table renames Item.Nodes.all;
      Child : Node_Index := Table.First (Slot);
   begin
      Yoga.Nodes.Scale_Style (Table.Yoga_Node (Slot), By);
      Content_Changed (Table.Object (Slot).all);  --  what is measured, again
      while Child /= 0 loop
         Rescale (Item, Child, By);
         Child := Table.Next (Child);
      end loop;
   end Rescale;

   procedure Set_Density (Item : in out Tree; To : Float) is
      Was : constant Float := Item.Density;
   begin
      if To /= Item.Density then
         Item.Density := To;
         --  What was laid out in the density before is in its pixels: put
         --  it in these.
         if Item.Root /= 0 and then Was > 0.0 then
            Rescale (Item, Item.Root, To / Was);
         end if;
         Item.Replace_All := True;
         Item.Layout_Pending := True;
         Item.Lost := True;
      end if;
   end Set_Density;

   function Density (Item : Tree) return Float is (Item.Density);

   procedure Set_Settled (Item : in out Tree; To : Boolean) is
   begin
      if To /= Item.Settled then
         Item.Settled := To;
         if Item.Root /= 0 then
            Invalidate (Item.Nodes.Object (Item.Root).all);
         end if;
      end if;
   end Set_Settled;

   function Is_Settled (Item : Tree) return Boolean is (Item.Settled);

   procedure Set_Clipboard
     (Item : in out Tree; Board : in out Clipboards.Clipboard'Class) is
   begin
      Item.Board := Board'Unchecked_Access;
   end Set_Clipboard;

   procedure Set_Line_Texts
     (Item : in out Tree; Lines : aliased in out Line_Texts.Drawer) is
   begin
      Item.Lines := Lines'Unchecked_Access;
   end Set_Line_Texts;

   procedure Set_Icons
     (Item : in out Tree; Library : aliased in out Icons.Library) is
   begin
      Item.Pictures := Library'Unchecked_Access;
   end Set_Icons;

   function Icon_Library (Item : Widget'Class) return Icons_Access is
     (Item.Owner.Pictures);

   function Text_Lines (Item : Widget'Class) return Line_Texts_Access is
     (Item.Owner.Lines);

   --  Damage

   procedure Damage_Box (Item : in out Widget'Class; Part : Pixel_Box) is
   begin
      Item.Owner.Damaged := Union (Item.Owner.Damaged, Part);
   end Damage_Box;

   procedure Invalidate (Item : in out Widget'Class) is
   begin
      Item.Owner.Nodes.Paint_Dirty (Item.Slot) := True;
      Item.Owner.Nodes.Semantics_Dirty (Item.Slot) := True;
      --  A widget that has not been placed is damaged when it is.
      if Item.Owner.Nodes.Spot (Item.Slot).Placed then
         Damage_Box (Item, Box_Of (Item));
      end if;
   end Invalidate;

   procedure Invalidate (Item : in out Widget'Class; Part : Pixel_Box) is
   begin
      --  A part of it only, as a caret: not what it is to an assistive
      --  technology.
      Item.Owner.Nodes.Paint_Dirty (Item.Slot) := True;
      if Item.Owner.Nodes.Spot (Item.Slot).Placed then
         Damage_Box (Item, Intersection (Part, Box_Of (Item)));
      end if;
   end Invalidate;

   procedure Invalidate_All (Item : in out Tree) is
   begin
      Item.Lost := True;
   end Invalidate_All;

   procedure Request_Layout (Item : in out Widget'Class) is
   begin
      Item.Owner.Layout_Pending := True;
      Item.Owner.Nodes.Layout_Dirty (Item.Slot) := True;
   end Request_Layout;

   procedure Move_To
     (Item         : in out Widget'Class;
      Left, Top    : Float;
      Was_Left, Was_Top : in out Float;
      Changed      : in out Boolean) is
   begin
      if Left /= Was_Left or else Top /= Was_Top then
         Was_Left := Left;
         Was_Top := Top;
         Yoga.Nodes.Set_Position (Node (Item), Yoga.Left, Left);
         Yoga.Nodes.Set_Position (Node (Item), Yoga.Top, Top);
         Request_Layout (Item);
         Changed := True;
      end if;
   end Move_To;

   function Needs_Paint (Item : Tree) return Boolean is
     (Item.Lost or else Item.Layout_Pending
      or else not Is_Empty (Item.Damaged));

   function Damage (Item : Tree) return Pixel_Box is (Item.Damaged);

   --  Layout

   procedure Place
     (Item    : in out Tree;
      Placing : Node_Index;
      Across, Down : Float;
      Parent_Moved : Boolean);
   --  Place Placing, whose parent is at Across, Down, and those of its
   --  children that the layout may have changed, or that moved with it.

   procedure Place
     (Item    : in out Tree;
      Placing : Node_Index;
      Across, Down : Float;
      Parent_Moved : Boolean)
   is
      pragma Unreferenced (Parent_Moved);
      Table    : Node_Table renames Item.Nodes.all;
      Own_Left : constant Float :=
        Across + Yoga.Nodes.Left (Table.Yoga_Node (Placing));
      Own_Top  : constant Float :=
        Down + Yoga.Nodes.Top (Table.Yoga_Node (Placing));
      Wide     : constant Float := Yoga.Nodes.Width (Table.Yoga_Node (Placing));
      High     : constant Float := Yoga.Nodes.Height (Table.Yoga_Node (Placing));
      Child    : Node_Index := Table.First (Placing);
      Moved    : Boolean;
   begin
      Yoga.Nodes.Clear_New_Layout (Table.Yoga_Node (Placing));
      Table.Layout_Dirty (Placing) := False;
      Moved := Item.Replace_All or else not Table.Spot (Placing).Placed
        or else Own_Left /= Table.Spot (Placing).Left
        or else Own_Top /= Table.Spot (Placing).Top;
      if Moved
        or else Wide /= Table.Spot (Placing).Wide
        or else High /= Table.Spot (Placing).High
      then
         if Table.Spot (Placing).Placed then
            Item.Damaged := Union (Item.Damaged, Box_Of (Item, Placing));
         end if;
         Table.Spot (Placing).Placed := True;
         Table.Spot (Placing).Left := Own_Left;
         Table.Spot (Placing).Top := Own_Top;
         Table.Spot (Placing).Wide := Wide;
         Table.Spot (Placing).High := High;
         Table.Semantics_Dirty (Placing) := True;
         --  Its place is part of what an assistive technology is told.
         Item.Damaged := Union (Item.Damaged, Box_Of (Item, Placing));
         Placed (Table.Object (Placing).all, Own_Left, Own_Top, Wide, High);
      end if;
      while Child /= 0 loop
         --  What the layout has not touched, and has not moved with its
         --  parent, is where it was.
         if Moved or else Yoga.Nodes.Has_New_Layout (Table.Yoga_Node (Child)) then
            Place (Item, Child, Own_Left, Own_Top, Moved);
         end if;
         Child := Table.Next (Child);
      end loop;
   end Place;

   procedure Layout
     (Item   : in out Tree;
      Target : SDL3.Painters.Painter'Class)
   is
      Pixels_Wide, Pixels_High : Natural;
   begin
      SDL3.Painters.Output_Size (Target, Pixels_Wide, Pixels_High);
      Yoga.Nodes.Calculate_Layout
        (Item.Yoga_Tree, Float (Pixels_Wide), Float (Pixels_High));
      Place (Item, Item.Root, 0.0, 0.0, False);
      Item.Replace_All := False;
      Item.Layout_Pending := False;
   end Layout;

   --  Drawing

   procedure Layout
     (Item   : in out Tree;
      Target : SDL3.Windows.Renderers.Renderer) is
   begin
      Layout (Item, SDL3.Painters.To (Target));
   end Layout;

   procedure Paint_Widget
     (Home     : in out Tree;
      Painting : Node_Index;
      Target   : SDL3.Painters.Painter'Class;
      Colors   : Themes.Theme;
      Region   : Pixel_Box);
   --  Draw Painting and its children, if they are in Region, which is
   --  the clip.

   procedure Paint_Widget
     (Home     : in out Tree;
      Painting : Node_Index;
      Target   : SDL3.Painters.Painter'Class;
      Colors   : Themes.Theme;
      Region   : Pixel_Box)
   is
      Table : Node_Table renames Home.Nodes.all;
      Box   : constant Pixel_Box := Intersection (Box_Of (Home, Painting), Region);
   begin
      if Is_Empty (Box) or else not Table.Spot (Painting).Visible then
         return;
      end if;
      declare
         Outer  : constant Renderers.Clip := SDL3.Painters.Current_Clip (Target);
         Child  : Node_Index := Table.First (Painting);
         Drawer : constant Widget_Access := Table.Object (Painting);
      begin
         SDL3.Painters.Narrow_Clip
           (Target, Box.Left, Box.Top, Box.Width, Box.Height);
         Table.Paint_Box (Painting) := Box;
         Draw (Drawer.all, Target, Colors);
         Table.Paint_Dirty (Painting) := False;
         while Child /= 0 loop
            Paint_Widget (Home, Child, Target, Colors, Box);
            Child := Table.Next (Child);
         end loop;
         Table.Paint_Box (Painting) := Box;
         Draw_Over (Drawer.all, Target, Colors);
         SDL3.Painters.Restore_Clip (Target, Outer);
      end;
   end Paint_Widget;

   procedure Paint
     (Item     : in out Tree;
      Target   : SDL3.Painters.Painter'Class;
      Colors   : Themes.Theme;
      Retained : Boolean := False)
   is
      Pixels_Wide, Pixels_High : Natural;
   begin
      SDL3.Painters.Output_Size (Target, Pixels_Wide, Pixels_High);
      Layout (Item, Target);
      declare
         Everything : constant Pixel_Box := (0, 0, Pixels_Wide, Pixels_High);
         Whole      : constant Boolean :=
           not Retained or else Item.Lost
           or else Pixels_Wide /= Item.Painted_Width
           or else Pixels_High /= Item.Painted_Height;
         Region     : constant Pixel_Box :=
           (if Whole then Everything
            else Intersection (Item.Damaged, Everything));
         Outer      : constant Renderers.Clip :=
           SDL3.Painters.Current_Clip (Target);
      begin
         if not Is_Empty (Region) then
            SDL3.Painters.Narrow_Clip
              (Target, Region.Left, Region.Top, Region.Width, Region.Height);
            if Whole then
               SDL3.Painters.Clear (Target, Colors (Themes.Background));
            else
               SDL3.Painters.Fill_Rect
                 (Target, Colors (Themes.Background),
                  Float (Region.Left), Float (Region.Top),
                  Float (Region.Width), Float (Region.Height));
            end if;
            Paint_Widget (Item, Item.Root, Target, Colors, Region);
            SDL3.Painters.Restore_Clip (Target, Outer);
         end if;
      end;
      Item.Damaged := (others => 0);
      Item.Lost := False;
      Item.Painted_Width := Pixels_Wide;
      Item.Painted_Height := Pixels_High;
   end Paint;

   procedure Paint
     (Item     : in out Tree;
      Target   : SDL3.Windows.Renderers.Renderer;
      Colors   : Themes.Theme;
      Retained : Boolean := False) is
   begin
      Paint (Item, SDL3.Painters.To (Target), Colors, Retained);
   end Paint;

   --  Focus and the pointer

   procedure Set_Focus (Item : in out Tree; To : Node_Index);
   --  Take the focus from the widget that has it, and give it to To, if
   --  it is not 0.

   procedure Set_Focus (Item : in out Tree; To : Node_Index) is
      Was : constant Node_Index := Item.Focus;
   begin
      if To /= Was then
         Item.Focus := To;
         if Was /= 0 then
            Item.Nodes.Focused (Was) := False;
            Item.Nodes.Semantics_Dirty (Was) := True;
            Focus_Changed (Item.Nodes.Object (Was).all, False);
            --  Said only to a handler of its own, or every change would be.
            if Has_Hook (Item.Nodes.Object (Was).all, Blur) then
               Notify (Item.Nodes.Object (Was).all, Blur);
            end if;
         end if;
         if To /= 0 then
            Item.Nodes.Focused (To) := True;
            Item.Nodes.Semantics_Dirty (To) := True;
            Focus_Changed (Item.Nodes.Object (To).all, True);
         end if;
      end if;
   end Set_Focus;

   procedure Focus (Item : in out Widget'Class) is
   begin
      Set_Focus (Item.Owner.all, Item.Slot);
      Deliver (Item.Owner.all);
   end Focus;

   procedure Release_Focus (Item : in out Widget'Class) is
   begin
      if Item.Owner.Nodes.Focused (Item.Slot) then
         Set_Focus (Item.Owner.all, 0);
         Deliver (Item.Owner.all);
      end if;
   end Release_Focus;

   procedure Clear_Focus (Item : in out Tree) is
   begin
      Set_Focus (Item, 0);
      Deliver (Item);
   end Clear_Focus;

   function Focus_Of (Item : Tree) return Widget_Access is
     (Object (Item, Item.Focus));

   function Is_Taker (Item : Tree; Slot : Node_Index) return Boolean is
     (Item.Nodes.Spot (Slot).Visible and then Accepts_Focus (Item.Nodes.Object (Slot).all));
   --  Whether Slot is one the focus may go to.

   function Within (Item : Tree; Slot, Inside : Node_Index) return Boolean;
   --  Whether Slot is Inside or in it.

   procedure Focus_Next (Item : in out Tree; Backwards : Boolean := False) is
      Scoped  : constant Boolean := Is_Live (Item, Item.Scope);
      Walking : Node_Index := (if Scoped then Item.Scope.Slot else Item.Root);
      First   : Node_Index := 0;
      Last    : Node_Index := 0;
      Before  : Node_Index := 0;
      After   : Node_Index := 0;
      Passed  : Boolean := False;
      --  Whether the walk is past the widget that has the focus.
   begin
      if Item.Root = 0 then
         return;
      end if;
      while Walking /= 0 and then (not Scoped or else Within (Item, Walking, Item.Scope.Slot)) loop
         if Walking = Item.Focus then
            Passed := True;
         elsif Is_Taker (Item, Walking) then
            if First = 0 then
               First := Walking;
            end if;
            Last := Walking;
            if Passed then
               if After = 0 then
                  After := Walking;
               end if;
            else
               Before := Walking;
            end if;
         end if;
         Walking := Following_Shown (Item, Walking);
      end loop;
      if Backwards then
         Set_Focus (Item, (if Before /= 0 then Before else Last));
      else
         Set_Focus (Item, (if After /= 0 then After else First));
      end if;
      Deliver (Item);
   end Focus_Next;

   procedure Set_Focus_Scope (Item : in out Tree; To : in out Widget'Class) is
   begin
      Item.Scope := Id_Of (To);
   end Set_Focus_Scope;

   procedure Clear_Focus_Scope (Item : in out Tree) is
   begin
      Item.Scope := No_Node;
   end Clear_Focus_Scope;

   procedure Set_Tab_Navigation (Item : in out Tree; To : Boolean) is
   begin
      Item.Tab_Moves := To;
   end Set_Tab_Navigation;

   function Within (Item : Tree; Slot, Inside : Node_Index) return Boolean is
      Climbing : Node_Index := Slot;
   begin
      while Climbing /= 0 loop
         if Climbing = Inside then
            return True;
         end if;
         Climbing := Item.Nodes.Parent (Climbing);
      end loop;
      return False;
   end Within;

   procedure Set_Hover (Item : in out Tree; To : Node_Index);
   --  The pointer is over To, or nothing.

   procedure Set_Hover (Item : in out Tree; To : Node_Index) is
      Was      : constant Node_Index := Item.Hover;
      Climbing : Node_Index;
   begin
      if To = Was then
         return;
      end if;
      Item.Hover := To;
      --  Those the pointer has left, and then those it has come over: not
      --  those it moved between.
      Climbing := Was;
      while Climbing /= 0 loop
         if not Within (Item, To, Climbing) then
            Item.Nodes.Hovered (Climbing) := False;
            Hover_Changed (Item.Nodes.Object (Climbing).all, False);
         end if;
         Climbing := Item.Nodes.Parent (Climbing);
      end loop;
      Climbing := To;
      while Climbing /= 0 loop
         if not Item.Nodes.Hovered (Climbing) then
            Item.Nodes.Hovered (Climbing) := True;
            Hover_Changed (Item.Nodes.Object (Climbing).all, True);
         end if;
         Climbing := Item.Nodes.Parent (Climbing);
      end loop;
   end Set_Hover;

   --  Commands

   procedure Forget_Told_States (Item : in out Tree) is
   begin
      if Item.Nodes /= null then
         for Slot in 1 .. Item.Nodes.Fresh loop
            Item.Told_States (Slot) := Enabled;
         end loop;
      end if;
   end Forget_Told_States;

   procedure Set_Validator (Item : in out Tree; To : Command_Validator) is
   begin
      Item.Validator := To;
      Item.Judge := null;
      Forget_Told_States (Item);
   end Set_Validator;

   procedure Set_Validator (Item : in out Tree; To : not null Validator_Access) is
   begin
      Item.Validator := null;
      Item.Judge := To;
      Forget_Told_States (Item);
   end Set_Validator;

   function Command_State_Of (Item : Tree; Tag : Integer) return Command_State is
     (if Item.Judge /= null then Validate (Item.Judge.all, Tag)
      elsif Item.Validator /= null then Item.Validator (Tag)
      else Enabled);

   procedure Revalidate (Item : in out Tree) is
   begin
      if (Item.Validator = null and then Item.Judge = null) or else Item.Nodes = null then
         return;
      end if;
      for Slot in 1 .. Item.Nodes.Fresh loop
         declare
            Mine : constant Widget_Access := Item.Nodes.Object (Slot);
         begin
            if Mine /= null and then Mine.Tag /= No_Tag and then Mine.Reflects then
               declare
                  Now : constant Command_State := Command_State_Of (Item, Mine.Tag);
               begin
                  if Now /= Item.Told_States (Slot) then
                     Item.Told_States (Slot) := Now;
                     if Now = Not_Offered then
                        Mine.Hid_By_Command := True;
                        Set_Visible (Mine.all, False);
                     elsif Mine.Hid_By_Command then
                        Mine.Hid_By_Command := False;
                        Set_Visible (Mine.all, True);
                     end if;
                     Command_State_Changed (Mine.all, Now);
                  end if;
               end;
            end if;
         end;
      end loop;
   end Revalidate;

   procedure Revalidate (Item : in out Widget'Class) is
   begin
      Revalidate (Item.Owner.all);
   end Revalidate;

   procedure Handle_Command
     (Item : in out Widget; Tag : Integer; Done : out Boolean)
   is
      pragma Unreferenced (Item, Tag);
   begin
      Done := False;
   end Handle_Command;

   procedure Perform_Command
     (Item : in out Tree; Tag : Integer; Done : out Boolean)
   is
      Asking : Node_Index := (if Item.Focus /= 0 then Item.Focus else Item.Root);
   begin
      Done := False;
      while Asking /= 0 and then not Done loop
         Handle_Command (Item.Nodes.Object (Asking).all, Tag, Done);
         Asking := Item.Nodes.Parent (Asking);
      end loop;
      if not Done and then Item.Hearer /= null and then Item.Root /= 0 then
         if Item.Queued = Queue_Capacity and then not Item.Delivering then
            Deliver (Item);
         end if;
         pragma Assert (Item.Queued < Queue_Capacity, "more events than the tree can keep");
         Item.Queue ((Item.Queue_First + Item.Queued - 1) mod Queue_Capacity + 1) :=
           (Source => Id_Of_Slot (Item, Item.Root),
            Target => Item.Hearer,
            Event  => Made_Event (Click, Tag, 0, 0, 0.0, 0.0, 0),
            Posted => <>,
            Code   => 0,
            Value  => 0);
         Item.Queued := Item.Queued + 1;
         Done := True;
      end if;
   end Perform_Command;

   procedure Bind_Key
     (Item    : in out Tree;
      Key     : Pomarine.Events.Key_Code;
      Command : Boolean := False;
      Shift   : Boolean := False;
      Tag     : Integer) is
   begin
      for Each of Item.Keys (1 .. Item.Keys_Bound) loop
         if Each.Key = Key and then Each.Command = Command and then Each.Shift = Shift then
            Each.Tag := Tag;
            return;
         end if;
      end loop;
      pragma Assert (Item.Keys_Bound < Key_Binding_Capacity, "more keys bound than the tree can keep");
      Item.Keys_Bound := Item.Keys_Bound + 1;
      Item.Keys (Item.Keys_Bound) := (Key, Command, Shift, Tag);
   end Bind_Key;

   --  Showing, hiding and removing

   procedure Let_Go (Item : in out Tree; Of_Widget : Node_Index);
   --  Take what the tree gives to Of_Widget or what is in it, as the
   --  focus, the pointer and a press, away, as it goes.

   procedure Let_Go (Item : in out Tree; Of_Widget : Node_Index) is
   begin
      if Within (Item, Item.Focus, Of_Widget) then
         Set_Focus (Item, 0);
      end if;
      if Within (Item, Item.Hover, Of_Widget) then
         --  The pointer is over what the widget was in, if anything.
         Set_Hover (Item, Item.Nodes.Parent (Of_Widget));
      end if;
      if Within (Item, Item.Capture, Of_Widget) then
         Item.Capture := 0;
      end if;
      if Within (Item, Item.Wheel_Taker, Of_Widget) then
         Item.Wheel_Taker := 0;
      end if;
   end Let_Go;

   procedure Set_Visible (Item : in out Widget'Class; To : Boolean) is
      Table : Node_Table renames Item.Owner.Nodes.all;
   begin
      if To = Table.Spot (Item.Slot).Visible then
         return;
      end if;
      if not To then
         Let_Go (Item.Owner.all, Item.Slot);
         Invalidate (Item);
      end if;
      Table.Spot (Item.Slot).Visible := To;
      Table.Semantics_Dirty (Item.Slot) := True;
      if Table.Parent (Item.Slot) /= 0 then
         Table.Semantics_Dirty (Table.Parent (Item.Slot)) := True;
      end if;
      Yoga.Nodes.Set_Display
        (Table.Yoga_Node (Item.Slot), (if To then Yoga.Flex else Yoga.None));
      Request_Layout (Item);
   end Set_Visible;

   procedure Unlink (Home : in out Tree; Slot : Node_Index) is
      Table  : Node_Table renames Home.Nodes.all;
      Above  : constant Node_Index := Table.Parent (Slot);
      Before : Node_Index := Table.First (Above);
   begin
      if Before = Slot then
         Table.First (Above) := Table.Next (Slot);
         if Table.Last (Above) = Slot then
            Table.Last (Above) := 0;
         end if;
      else
         while Table.Next (Before) /= Slot loop
            Before := Table.Next (Before);
         end loop;
         Table.Next (Before) := Table.Next (Slot);
         if Table.Last (Above) = Slot then
            Table.Last (Above) := Before;
         end if;
      end if;
      Table.Children (Above) := Table.Children (Above) - 1;
      Table.Semantics_Dirty (Above) := True;
   end Unlink;
   --  Take Slot out of its parent's children.

   procedure Remove (Item : in out Widget'Class) is
      Owner : constant Tree_Access := Item.Owner;
      Slot  : constant Node_Index := Item.Slot;
      Above : constant Node_Index := Owner.Nodes.Parent (Slot);
   begin
      Let_Go (Owner.all, Slot);
      Invalidate (Item);
      Request_Layout (Item);
      Unlink (Owner.all, Slot);
      Yoga.Nodes.Delete
        (Owner.Nodes.Yoga_Node (Above), Owner.Nodes.Yoga_Node (Slot));
      Give_Back_All (Owner.all, Slot);
   end Remove;

   overriding procedure Finalize (Item : in out Widget) is
      Home : constant Tree_Access := Item.Owner;
   begin
      Give_Back_Cold (Item);
      if Home = null then
         return;
      end if;
      --  Nothing is said to it or the widgets it is in: they may be gone
      --  already, in part.
      declare
         Slot : constant Node_Index := Item.Slot;
         Above : constant Node_Index := Home.Nodes.Parent (Slot);
      begin
         if Within (Home.all, Home.Focus, Slot) then
            Home.Focus := 0;
         end if;
         if Within (Home.all, Home.Hover, Slot) then
            Home.Hover := Above;
         end if;
         if Within (Home.all, Home.Capture, Slot) then
            Home.Capture := 0;
         end if;
         if Within (Home.all, Home.Wheel_Taker, Slot) then
            Home.Wheel_Taker := 0;
         end if;
         if Above = 0 then
            Home.Root := 0;
         else
            Unlink (Home.all, Slot);
            Yoga.Nodes.Delete
              (Home.Nodes.Yoga_Node (Above), Home.Nodes.Yoga_Node (Slot));
            Home.Layout_Pending := True;
            Home.Lost := True;
         end if;
         Give_Back_All (Home.all, Slot);
      end;
   end Finalize;

   overriding procedure Finalize (Item : in out Tree) is
   begin
      if Item.Nodes /= null then
         for Slot in 1 .. Item.Nodes.Fresh loop
            if Item.Nodes.Object (Slot) /= null then
               Item.Nodes.Object (Slot).Owner := null;
               Item.Nodes.Object (Slot).Slot := 0;
            end if;
         end loop;
         Free_Table (Item.Nodes);
      end if;
   end Finalize;

   procedure Raise_To_Front (Item : in out Widget'Class) is
      Table  : Node_Table renames Item.Owner.Nodes.all;
      Raising : constant Node_Index := Item.Slot;
      Above   : constant Node_Index := Table.Parent (Raising);
      Before  : Node_Index := Table.First (Above);
   begin
      if Table.Last (Above) = Raising then
         return;
      end if;
      if Before = Raising then
         Table.First (Above) := Table.Next (Raising);
      else
         while Table.Next (Before) /= Raising loop
            Before := Table.Next (Before);
         end loop;
         Table.Next (Before) := Table.Next (Raising);
      end if;
      Table.Next (Table.Last (Above)) := Raising;
      Table.Last (Above) := Raising;
      Table.Next (Raising) := 0;
      Table.Semantics_Dirty (Above) := True;
      Invalidate (Item);
   end Raise_To_Front;

   function Hit_Slot (Item : Tree; X, Y : Float) return Node_Index is
      Table : Node_Table renames Item.Nodes.all;
      Found : Node_Index := 0;
      Level : Node_Index := Item.Root;
   begin
      --  Down through the last child that has the point, at each level.
      while Level /= 0 loop
         declare
            Box : Spot renames Table.Spot (Level);
         begin
            exit when not Box.Visible
              or else X < Box.Left or else X >= Box.Left + Box.Wide
              or else Y < Box.Top or else Y >= Box.Top + Box.High;
         end;
         Found := Level;
         declare
            Child : Node_Index := Table.First (Level);
         begin
            Level := 0;
            while Child /= 0 loop
               declare
                  Box : Spot renames Table.Spot (Child);
               begin
                  if Box.Visible
                    and then X >= Box.Left and then X < Box.Left + Box.Wide
                    and then Y >= Box.Top and then Y < Box.Top + Box.High
                  then
                     Level := Child;
                  end if;
               end;
               Child := Table.Next (Child);
            end loop;
         end;
      end loop;
      return Found;
   end Hit_Slot;

   function Hit (Item : Tree; X, Y : Float) return Widget_Access is
     (Object (Item, Hit_Slot (Item, X, Y)));

   --  Events

   procedure Bubble
     (Home    : Tree;
      From    : Node_Index;
      Event   : Pomarine.Events.Event;
      Taker   : out Node_Index);
   --  Offer Event to From, and then its parents, until one takes it.

   procedure Bubble
     (Home    : Tree;
      From    : Node_Index;
      Event   : Pomarine.Events.Event;
      Taker   : out Node_Index)
   is
      Offered : Node_Index := From;
      Handled : Boolean;
   begin
      Taker := 0;
      while Offered /= 0 loop
         Handle (Home.Nodes.Object (Offered).all, Event, Handled);
         if Handled then
            Taker := Offered;
            return;
         end if;
         Offered := Home.Nodes.Parent (Offered);
      end loop;
   end Bubble;

   function Accepting (Home : Tree; From : Node_Index) return Node_Index;
   --  From, or the nearest of its parents, that accepts the focus.

   function Accepting (Home : Tree; From : Node_Index) return Node_Index is
      Climbing : Node_Index := From;
   begin
      while Climbing /= 0
        and then not Focus_On_Click (Home.Nodes.Object (Climbing).all)
      loop
         Climbing := Home.Nodes.Parent (Climbing);
      end loop;
      return Climbing;
   end Accepting;

   Wheel_Stickiness : constant Pomarine.Events.Milliseconds := 300;
   --  How soon after a wheel turn the next still goes to the same widget.

   procedure Dispatch_Press
     (Item    : in out Tree;
      Event   : Pomarine.Events.Event;
      Over    : Node_Index;
      Handled : out Boolean);

   procedure Dispatch_Press
     (Item    : in out Tree;
      Event   : Pomarine.Events.Event;
      Over    : Node_Index;
      Handled : out Boolean)
   is
      Accepts : constant Node_Index := Accepting (Item, Over);
      Taker   : Node_Index;
   begin
      if Accepts /= 0 then
         Set_Focus (Item, Accepts);
      end if;
      Bubble (Item, Over, Event, Taker);
      Handled := Taker /= 0;
      if Taker /= 0 then
         Item.Capture := Taker;
         Item.Capture_Button := Event.Button;
      elsif Accepts = 0 and then Item.Focus /= 0 then
         --  A click elsewhere takes the focus away.
         Set_Focus (Item, 0);
         Handled := True;
      end if;
   end Dispatch_Press;

   procedure Set_Input_Source (Item : in out Tree; Keyboard : Boolean);
   --  The last input was by key, or by pointer: the focus ring is shown
   --  for the one and not the other.

   procedure Set_Input_Source (Item : in out Tree; Keyboard : Boolean) is
   begin
      if Item.Keyboard_Focus /= Keyboard then
         Item.Keyboard_Focus := Keyboard;
         if Item.Focus /= 0 then
            Invalidate (Item.Nodes.Object (Item.Focus).all);
         end if;
      end if;
   end Set_Input_Source;

   procedure Dispatch_Keys
     (Item    : in out Tree;
      Event   : Pomarine.Events.Event;
      Handled : out Boolean);

   procedure Dispatch_Keys
     (Item    : in out Tree;
      Event   : Pomarine.Events.Event;
      Handled : out Boolean)
   is
      Taker   : Node_Index;
      Offered : Node_Index;
   begin
      if Event.Kind = Pomarine.Events.Key_Down then
         Set_Input_Source (Item, Keyboard => True);
      end if;
      Bubble (Item, Item.Focus, Event, Taker);
      Handled := Taker /= 0;
      if not Handled and then Event.Kind = Pomarine.Events.Key_Down then
         Offered := Item.Root;
         while Offered /= 0 and then not Handled loop
            if Item.Nodes.Spot (Offered).Visible then
               Handle (Item.Nodes.Object (Offered).all, Event, Handled);
            end if;
            Offered := Following_Shown (Item, Offered);
         end loop;
      end if;
      --  Tab, when the tree is to move the focus by it.
      if not Handled and then Item.Tab_Moves and then Event.Kind = Pomarine.Events.Key_Down
        and then Event.Key = Pomarine.Events.Key_Tab and then not Event.Command
      then
         Focus_Next (Item, Backwards => Event.Shift);
         Handled := True;
      end if;
      --  Keys that none of the widgets took, that the application has
      --  bound to commands.
      if not Handled and then Event.Kind = Pomarine.Events.Key_Down then
         for Each of Item.Keys (1 .. Item.Keys_Bound) loop
            if Each.Key = Event.Key and then Each.Command = Event.Command
              and then Each.Shift = Event.Shift
            then
               Perform_Command (Item, Each.Tag, Handled);
               exit;
            end if;
         end loop;
      end if;
   end Dispatch_Keys;

   procedure Dispatch
     (Item    : in out Tree;
      Event   : Pomarine.Events.Event;
      Handled : out Boolean)
   is
      Over  : Node_Index;
      Taker : Node_Index;
   begin
      Handled := False;
      case Event.Kind is
         when Pomarine.Events.Mouse_Down =>
            Set_Input_Source (Item, Keyboard => False);
            Over := Hit_Slot (Item, Event.Mouse_X * Item.Density,
                              Event.Mouse_Y * Item.Density);
            Dispatch_Press (Item, Event, Over, Handled);

         when Pomarine.Events.Mouse_Move | Pomarine.Events.Mouse_Up =>
            Over := Hit_Slot (Item, Event.Mouse_X * Item.Density,
                              Event.Mouse_Y * Item.Density);
            Set_Hover (Item, Over);
            if Item.Capture /= 0 then
               Handle (Item.Nodes.Object (Item.Capture).all, Event, Handled);
               if Event.Kind = Pomarine.Events.Mouse_Up
                 and then Event.Button = Item.Capture_Button
               then
                  Item.Capture := 0;
               elsif Event.Kind = Pomarine.Events.Mouse_Move
                 and then Item.Capture_Button = 1
                 and then not Event.Left_Held
               then
                  Item.Capture := 0;  --  let go where it was not seen
               end if;
            else
               Bubble (Item, Over, Event, Taker);
               Handled := Taker /= 0;
            end if;

         when Pomarine.Events.Mouse_Wheel | Pomarine.Events.Pinch =>
            Over := Hit_Slot (Item, Event.Mouse_X * Item.Density,
                              Event.Mouse_Y * Item.Density);
            if Event.Kind = Pomarine.Events.Mouse_Wheel
              and then Item.Wheel_Taker /= 0
              and then Event.Time > 0
              and then Event.Time >= Item.Wheel_Time
              and then Event.Time - Item.Wheel_Time <= Wheel_Stickiness
            then
               --  Still turning what it was turning.
               Over := Item.Wheel_Taker;
            end if;
            Bubble (Item, Over, Event, Taker);
            Handled := Taker /= 0;
            if Event.Kind = Pomarine.Events.Mouse_Wheel then
               Item.Wheel_Taker := Taker;
               Item.Wheel_Time := Event.Time;
            end if;

         when Pomarine.Events.Key_Down | Pomarine.Events.Text_Input
            | Pomarine.Events.Text_Editing =>
            Dispatch_Keys (Item, Event, Handled);

         when Pomarine.Events.Quit | Pomarine.Events.Redraw
            | Pomarine.Events.Theme_Changed | Pomarine.Events.Other =>
            null;
      end case;
      Deliver (Item);
   end Dispatch;

   function Wanted_Cursor (Item : Tree) return SDL3.Cursors.Kind is
      use type SDL3.Cursors.Kind;
      Asking : Node_Index :=
        (if Item.Capture /= 0 then Item.Capture else Item.Hover);
   begin
      while Asking /= 0 loop
         if Cursor (Item.Nodes.Object (Asking).all) /= SDL3.Cursors.Default then
            return Cursor (Item.Nodes.Object (Asking).all);
         end if;
         Asking := (if Item.Capture /= 0 then 0 else Item.Nodes.Parent (Asking));
      end loop;
      return SDL3.Cursors.Default;
   end Wanted_Cursor;

   --  What widgets are to an assistive technology

   procedure Describe
     (Item  : Widget;
      Facts : in out Semantics.Description) is
   begin
      if Facts.Kind = Semantics.Unknown then
         Facts.Kind := Semantics.Group;
      end if;
   end Describe;

   procedure Perform
     (Item    : in out Widget;
      Request : Semantics.Request;
      Done    : out Boolean)
   is
      pragma Unreferenced (Item, Request);
   begin
      Done := False;
   end Perform;

   procedure Describe_Part
     (Item   : Widget;
      Part   : Positive;
      Facts  : in out Semantics.Description;
      Bounds : out Semantics.Rectangle)
   is
      pragma Unreferenced (Item, Part);
   begin
      Facts.Kind := Semantics.Group;
      Bounds := (others => 0.0);
   end Describe_Part;

   procedure Perform_Part
     (Item    : in out Widget;
      Part    : Positive;
      Request : Semantics.Request;
      Done    : out Boolean)
   is
      pragma Unreferenced (Item, Part, Request);
   begin
      Done := False;
   end Perform_Part;

   procedure Set_Accessible_Name (Item : in out Widget'Class; Text : String) is
   begin
      Semantics.Set (Block (Cold (Item)).all.Name, Text);
      if Item.Owner /= null then
         Item.Owner.Nodes.Semantics_Dirty (Item.Slot) := True;
      end if;
   end Set_Accessible_Name;

   procedure Set_Accessible_Help (Item : in out Widget'Class; Text : String) is
   begin
      Semantics.Set (Block (Cold (Item)).all.Help, Text);
      if Item.Owner /= null then
         Item.Owner.Nodes.Semantics_Dirty (Item.Slot) := True;
      end if;
   end Set_Accessible_Help;

   procedure Set_Accessible_Role
     (Item : in out Widget'Class; Role : Semantics.Role) is
   begin
      Item.Said_Role := Role;
      if Item.Owner /= null then
         Item.Owner.Nodes.Semantics_Dirty (Item.Slot) := True;
      end if;
   end Set_Accessible_Role;

   procedure Hide_From_Accessibility (Item : in out Widget'Class; To : Boolean := True) is
   begin
      if Item.Hidden_From_AT /= To then
         Item.Hidden_From_AT := To;
         if Item.Owner /= null and then Item.Owner.Nodes.Parent (Item.Slot) /= 0 then
            Item.Owner.Nodes.Semantics_Dirty (Item.Owner.Nodes.Parent (Item.Slot)) := True;
         end if;
      end if;
   end Hide_From_Accessibility;

   function Accessible_Name (Item : Widget'Class) return String is
     (if Item.Cold = 0 then "" else Semantics.To_String (Block (Item.Cold).all.Name));

   procedure Set_Title (Item : in out Tree; Text : String) is
   begin
      Semantics.Set (Item.Title, Text);
      if Item.Root /= 0 then
         Item.Nodes.Semantics_Dirty (Item.Root) := True;
      end if;
   end Set_Title;

   function Is_Told (Home : Tree; Slot : Node_Index) return Boolean is
     (Home.Nodes.Spot (Slot).Visible
      and then not Home.Nodes.Object (Slot).Hidden_From_AT);
   --  Whether an assistive technology is to hear of Slot: not if it, or
   --  what it is in, is hidden.

   procedure Forget (Home : in out Tree; Slot : Node_Index) is
      Child : Node_Index := Home.Nodes.First (Slot);
   begin
      Home.Nodes.Known (Slot) := False;
      while Child /= 0 loop
         Forget (Home, Child);
         Child := Home.Nodes.Next (Child);
      end loop;
   end Forget;
   --  Slot, and all in it, are no longer known to an assistive technology.

   procedure Tell
     (Home  : in out Tree;
      Slot  : Node_Index;
      Into  : in out Semantic_Sink'Class;
      Whole : Boolean);
   --  Tell of Slot if it has changed, and then of what is in it.

   procedure Tell
     (Home  : in out Tree;
      Slot  : Node_Index;
      Into  : in out Semantic_Sink'Class;
      Whole : Boolean)
   is
      Table  : Node_Table renames Home.Nodes.all;
      Mine   : constant Widget_Access := Table.Object (Slot);
      Shown  : Natural := 0;
      Child  : Node_Index := Table.First (Slot);
   begin
      --  Those it is to hear of, in order. The scratch is this level's
      --  alone: it is used up before the next is begun.
      while Child /= 0 loop
         if Is_Told (Home, Child) then
            Shown := Shown + 1;
            Table.Kids (Shown) := Id_Of_Slot (Home, Child);
         else
            Forget (Home, Child);
         end if;
         Child := Table.Next (Child);
      end loop;
      declare
         Parts : constant Natural := Part_Count (Mine.all);
      begin
         pragma Assert (Shown + Parts <= Node_Capacity);
         for Index in 1 .. Parts loop
            Shown := Shown + 1;
            Table.Kids (Shown) := Part_Id (Mine.all, Part_Number (Mine.all, Index));
         end loop;
      end;

      if Whole or else not Table.Known (Slot) or else Table.Semantics_Dirty (Slot) then
         declare
            Facts  : Semantics.Description;
            Box    : Semantics.Rectangle;
            Points : constant Float := Home.Density;
            Where  : Spot renames Table.Spot (Slot);
         begin
            Facts.Kind := Mine.Said_Role;
            Describe (Mine.all, Facts);
            if Slot = Home.Root and then Facts.Kind in
                 Semantics.Unknown | Semantics.Group
            then
               Facts.Kind := Semantics.Window;
            end if;
            if Mine.Cold /= 0 and then Semantics.Length (Block (Mine.Cold).all.Name) > 0 then
               Facts.Name := Block (Mine.Cold).all.Name;
            elsif Slot = Home.Root and then Semantics.Length (Home.Title) > 0 then
               Facts.Name := Home.Title;
            end if;
            if Mine.Cold /= 0 and then Semantics.Length (Block (Mine.Cold).all.Help) > 0 then
               Facts.Help := Block (Mine.Cold).all.Help;
            end if;
            if Table.Focused (Slot) then
               Facts.Focusable := True;
            end if;
            Box := (Left => Where.Left / Points, Top => Where.Top / Points,
                    Right => (Where.Left + Where.Wide) / Points,
                    Bottom => (Where.Top + Where.High) / Points);
            Describe_Node
              (Into, Id_Of_Slot (Home, Slot), Facts, Box, Table.Kids (1 .. Shown));
            for Index in 1 .. Part_Count (Mine.all) loop
               declare
                  Number : constant Positive := Part_Number (Mine.all, Index);
                  Inner  : Semantics.Description;
                  Inside : Semantics.Rectangle;
               begin
                  Describe_Part (Mine.all, Number, Inner, Inside);
                  Describe_Node
                    (Into, Part_Id (Mine.all, Number), Inner,
                     (Left => Inside.Left / Points, Top => Inside.Top / Points,
                      Right => Inside.Right / Points,
                      Bottom => Inside.Bottom / Points),
                     Node_Id_Array'(1 .. 0 => No_Node));
               end;
            end loop;
            Table.Known (Slot) := True;
            Table.Semantics_Dirty (Slot) := False;
         end;
      end if;

      Child := Table.First (Slot);
      while Child /= 0 loop
         if Is_Told (Home, Child) then
            Tell (Home, Child, Into, Whole);
         end if;
         Child := Table.Next (Child);
      end loop;
   end Tell;

   function Is_Reachable (Home : Tree; Slot : Node_Index) return Boolean is
      Climbing : Node_Index := Slot;
   begin
      while Climbing /= 0 loop
         if not Is_Told (Home, Climbing) then
            return False;
         end if;
         Climbing := Home.Nodes.Parent (Climbing);
      end loop;
      return True;
   end Is_Reachable;
   --  Whether an assistive technology can come to Slot: it and all it is in
   --  are to be told of.

   procedure Describe_Changes
     (Item : in out Tree;
      Into : in out Semantic_Sink'Class;
      Whole : Boolean := False)
   is
      Everything : constant Boolean := Whole or else Item.Whole_Next;
      Focused    : constant Node_Id :=
        (if Item.Focus /= 0 and then Is_Reachable (Item, Item.Focus)
         then Id_Of_Slot (Item, Item.Focus) else Root_Id (Item));
   begin
      if Everything then
         Forget (Item, Item.Root);
      end if;
      Begin_Update (Into, Root_Id (Item), Focused, Everything);
      Tell (Item, Item.Root, Into, Everything);
      End_Update (Into);
      Item.Whole_Next := False;
   end Describe_Changes;

   procedure Act
     (Item    : in out Tree;
      Id      : Node_Id;
      Request : Semantics.Request;
      Done    : out Boolean)
   is
      Target : constant Widget_Access := Resolve (Item, Id);
   begin
      Done := False;
      if Target = null or else not Is_Reachable (Item, Id.Slot) then
         return;
      end if;
      if Id.Part /= 0 then
         Perform_Part (Target.all, Id.Part, Request, Done);
         Deliver (Item);
         return;
      end if;
      case Request.Doing is
         when Semantics.Focus =>
            if Accepts_Focus (Target.all) then
               Set_Focus (Item, Id.Slot);
               Done := True;
            else
               Perform (Target.all, Request, Done);
            end if;
         when Semantics.Blur =>
            if Item.Nodes.Focused (Id.Slot) then
               Set_Focus (Item, 0);
            end if;
            Done := True;
         when others =>
            Perform (Target.all, Request, Done);
      end case;
      Deliver (Item);
   end Act;

   --  Animation

   function Eased (How : Easing; T : Float) return Float is
     (case How is
         when Linear      => T,
         when Ease_Out    => 1.0 - (1.0 - T) ** 3,
         when Ease_In_Out => T * T * (3.0 - 2.0 * T));
   --  How far along the way a number is, of the whole, T of the way
   --  through the time.

   function Reduced_Motion (Item : Tree) return Boolean is (Item.Reduce_Motion);

   procedure Set_Reduced_Motion (Item : in out Tree; To : Boolean) is
   begin
      Item.Reduce_Motion := To;
   end Set_Reduced_Motion;

   function Is_Animating (Item : Tree) return Boolean is (Item.Running > 0);

   procedure Animate
     (Item         : in out Widget'Class;
      From, To     : Float;
      Milliseconds : Natural;
      How          : Easing := Ease_Out;
      Apply        : not null Animation_Setter)
   is
      Home : constant Tree_Access := Item.Owner;
      Mine : constant Node_Id := Id_Of (Item);
      Free : Natural := 0;
   begin
      if Home.Reduce_Motion or else Milliseconds = 0 or else From = To then
         Stop_Animations (Item);
         Apply (Item, To);
         return;
      end if;
      for K in Home.Moving'Range loop
         if Home.Moving (K).Active then
            if Home.Moving (K).Who = Mine and then Home.Moving (K).Apply = Apply then
               Free := K;
               exit;
            end if;
         elsif Free = 0 then
            Free := K;
         end if;
      end loop;
      pragma Assert (Free /= 0, "more animations than the tree can run");
      if not Home.Moving (Free).Active then
         Home.Running := Home.Running + 1;
      end if;
      Home.Moving (Free) :=
        (Active => True, Who => Mine, From => From, To => To, Start => Home.Clock,
         Length => Milliseconds, How => How, Apply => Apply);
      Apply (Item, From);
   end Animate;

   procedure Stop_Animations (Item : in out Widget'Class) is
      Home : constant Tree_Access := Item.Owner;
      Mine : constant Node_Id := Id_Of (Item);
   begin
      if Home = null then
         return;
      end if;
      for Each of Home.Moving loop
         if Each.Active and then Each.Who = Mine then
            Each.Active := False;
            Home.Running := Home.Running - 1;
         end if;
      end loop;
   end Stop_Animations;

   procedure Step_Animations (Item : in out Tree; Now : Pomarine.Events.Milliseconds) is
   begin
      Item.Clock := Now;
      if Item.Running = 0 then
         return;
      end if;
      for Each of Item.Moving loop
         if Each.Active then
            declare
               Going : constant Widget_Access := Resolve (Item, Each.Who);
               Spent : constant Float :=
                 (if Now > Each.Start then Float (Now - Each.Start) else 0.0);
               T     : constant Float := Float'Min (1.0, Spent / Float (Each.Length));
            begin
               if Going = null then
                  Each.Active := False;
                  Item.Running := Item.Running - 1;
               else
                  --  The last is exact, not what the curve comes to.
                  Each.Apply
                    (Going.all,
                     (if T >= 1.0 then Each.To
                      else Each.From + (Each.To - Each.From) * Eased (Each.How, T)));
                  if T >= 1.0 then
                     Each.Active := False;
                     Item.Running := Item.Running - 1;
                  end if;
               end if;
            end;
         end if;
      end loop;
   end Step_Animations;

   --  Time

   procedure Update (Item : in out Tree; Now : Pomarine.Events.Milliseconds) is
      Updating : Node_Index := Item.Root;
   begin
      Step_Animations (Item, Now);
      Revalidate (Item);
      while Updating /= 0 loop
         if Item.Nodes.Spot (Updating).Visible then
            Update (Item.Nodes.Object (Updating).all, Now);
         end if;
         Updating := Following_Shown (Item, Updating);
      end loop;
      Deliver (Item);
   end Update;

   function Until_Update (Item : Tree) return Integer is
      Asking : Node_Index := Item.Root;
      Result : Integer := (if Item.Running > 0 then Frame_Milliseconds else -1);
   begin
      while Asking /= 0 loop
         if Item.Nodes.Spot (Asking).Visible then
            declare
               Wait : constant Integer :=
                 Until_Update (Item.Nodes.Object (Asking).all);
            begin
               if Wait >= 0 and then (Result < 0 or else Wait < Result) then
                  Result := Wait;
               end if;
            end;
         end if;
         Asking := Following_Shown (Item, Asking);
      end loop;
      return Result;
   end Until_Update;

end Pomarine.Widgets;
