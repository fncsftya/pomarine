--  The body of Pomarine.Widgets keeps the table of nodes (ids, boxes, state), what a widget answers about itself, and
--  hands the rest to private children, each one a part of the tree's work (all in tree/):
--
--     Nodes          pixels, the seldom-used parts of widgets, where a node is in the table (what the others share)
--     Adding         widgets joining the tree         Lifecycle   taken out, shown, hidden, raised
--     Queueing       events said, queued, delivered   Commanding  commands and their keys
--     Focusing       focus, hover, tab order          Dispatching input to the widget under the pointer or focus
--     Drawing        damage, layout, painting         Accessibility what an assistive technology is told
--     Animations     values moving over time
with Ada.Unchecked_Conversion;
with Ada.Unchecked_Deallocation;
with Pomarine.Widgets.Animations;
with Pomarine.Widgets.Accessibility;
with Pomarine.Widgets.Nodes;
with Pomarine.Widgets.Focusing;
with Pomarine.Widgets.Queueing;
with Pomarine.Widgets.Commanding;
with Pomarine.Widgets.Drawing;
with Pomarine.Widgets.Dispatching;
with Pomarine.Widgets.Lifecycle;
with Pomarine.Widgets.Adding;
with Pomarine.Widgets.Tipping;
package body Pomarine.Widgets is

   use Pomarine.Widgets.Adding;

   use Pomarine.Widgets.Lifecycle;

   use Pomarine.Widgets.Commanding;
   use Pomarine.Widgets.Focusing;
   use Pomarine.Widgets.Nodes;

   use type Interfaces.Unsigned_64;
   use type Semantics.Role;

   --  The table

   Slot_Bits : constant := 21;
   Use_Bits  : constant := 19;
   --  Bits of a slot and of a use of it that a part's number keeps.

   procedure Free_Table is new Ada.Unchecked_Deallocation (Node_Table, Table_Access);

   function Is_Attached (Item : Widget'Class) return Boolean is
     (Item.Owner /= null);

   function Tree_Of (Item : Widget'Class) return not null access Tree is (Item.Owner);

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

   function Part_Of (Id : Node_Id; Part : Natural) return Node_Id is
     ((Id.Slot, Id.Use_Number, Part));

   function Part_Number_Of (Id : Node_Id) return Natural is (Id.Part);

   function Root_Widget (Item : Tree) return Widget_Access is
     (if Item.Root = 0 then null else Item.Nodes.Object (Item.Root));

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

   function Is_Showing (Item : Widget'Class) return Boolean is
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
   end Is_Showing;

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

   procedure Deliver (Item : in out Tree) is
   begin
      Queueing.Deliver_All (Item);
   end Deliver;

   procedure Notify
     (Item   : in out Widget'Class;
      Kind   : Event_Kind;
      Row    : Natural := 0;
      Across : Float := 0.0;
      Down   : Float := 0.0;
      Action : Natural := 0)
   is
   begin
      Queueing.Enqueue (Item, Kind, Row, Across, Down, Action);
   end Notify;

   procedure Post
     (Item  : in out Widget'Class;
      Using : Posted_Hook;
      Code  : Natural := 0;
      Value : Natural := 0)
   is
   begin
      Queueing.Enqueue_Posted (Item, Using, Code, Value);
   end Post;

   procedure Set_Root (Item : in out Tree; Root : in out Widget'Class) is
   begin
      Adding.Plant_Root (Item, Root);
   end Set_Root;

   procedure Add (Parent : in out Widget'Class; Child : in out Widget'Class) is
   begin
      Adding.Attach (Parent, Child);
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
      First, Second, Third, Fourth : in out Widget'Class)
   is
   begin
      Adding.Attach (Parent, First, Second, Third, Fourth);
   end Add;

   procedure Add
     (Parent : in out Widget'Class;
      First, Second, Third, Fourth, Fifth : in out Widget'Class)
   is
   begin
      Adding.Attach (Parent, First, Second, Third, Fourth, Fifth);
   end Add;

   procedure Add_Before
     (Parent : in out Widget'Class;
      Child  : in out Widget'Class;
      Before : Widget'Class)
   is
   begin
      Adding.Attach_Before (Parent, Child, Before);
   end Add_Before;

   --  Walking the tree: parents before their children, and children in
   --  order.

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

   procedure Invalidate (Item : in out Widget'Class) is
   begin
      Drawing.Damage_Widget (Item);
   end Invalidate;

   procedure Invalidate (Item : in out Widget'Class; Part : Pixel_Box) is
   begin
      Drawing.Damage_Widget (Item, Part);
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
      Changed      : in out Boolean)
   is
   begin
      Drawing.Place_At (Item, Left, Top, Was_Left, Was_Top, Changed);
   end Move_To;

   function Needs_Paint (Item : Tree) return Boolean is
     (Item.Lost or else Item.Layout_Pending
      or else not Is_Empty (Item.Damaged));

   function Damage (Item : Tree) return Pixel_Box is (Item.Damaged);

   --  Layout

   --  Place Placing, whose parent is at Across, Down, and those of its
   --  children that the layout may have changed, or that moved with it.

   procedure Layout
     (Item   : in out Tree;
      Target : SDL3.Painters.Painter'Class)
   is
   begin
      Drawing.Lay_Out (Item, Target);
   end Layout;

   --  Drawing

   procedure Layout
     (Item   : in out Tree;
      Target : SDL3.Windows.Renderers.Renderer) is
   begin
      Layout (Item, SDL3.Painters.To (Target));
   end Layout;

   --  Draw Painting and its children, if they are in Region, which is
   --  the clip.

   procedure Paint
     (Item     : in out Tree;
      Target   : SDL3.Painters.Painter'Class;
      Colors   : Themes.Theme;
      Retained : Boolean := False)
   is
   begin
      Drawing.Paint_All (Item, Target, Colors, Retained);
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

   --  Take the focus from the widget that has it, and give it to To, if
   --  it is not 0.

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

   --  Whether Slot is Inside or in it.

   procedure Focus_Next (Item : in out Tree; Backwards : Boolean := False) is
   begin
      Focusing.Next_Focus (Item, Backwards);
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

   --  The pointer is over To, or nothing.

   --  Commands

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

   function Command_State_Of (Item : Tree; Tag : Integer; Index : Natural := 0) return Command_State is
     (if Item.Judge /= null then Validate (Item.Judge.all, Tag, Index)
      elsif Item.Validator /= null then Item.Validator (Tag)
      else Enabled);

   procedure Revalidate (Item : in out Tree) is
   begin
      Commanding.Tell_All (Item);
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
   begin
      Commanding.Perform (Item, Tag, Done);
   end Perform_Command;

   procedure Bind_Key
     (Item    : in out Tree;
      Key     : Pomarine.Events.Key_Code;
      Command : Boolean := False;
      Shift   : Boolean := False;
      Tag     : Integer)
   is
   begin
      Commanding.Bind (Item, Key, Command, Shift, Tag);
   end Bind_Key;

   --  Showing, hiding and removing

   --  Take what the tree gives to Of_Widget or what is in it, as the
   --  focus, the pointer and a press, away, as it goes.

   procedure Set_Visible (Item : in out Widget'Class; To : Boolean) is
   begin
      Lifecycle.Show_Or_Hide (Item, To);
   end Set_Visible;

   procedure Remove (Item : in out Widget'Class) is
   begin
      Lifecycle.Take_Out (Item);
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
            --  Its children's nodes are Yoga's root's children still: take them away, or the
            --  next root has them.
            declare
               Child : Node_Index := Home.Nodes.First (Slot);
            begin
               while Child /= 0 loop
                  Yoga.Nodes.Delete (Home.Nodes.Yoga_Node (Slot), Home.Nodes.Yoga_Node (Child));
                  Child := Home.Nodes.Next (Child);
               end loop;
            end;
            Home.Layout_Pending := True;
            Home.Lost := True;
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
   begin
      Lifecycle.Bring_Forward (Item);
   end Raise_To_Front;

   function Hit (Item : Tree; X, Y : Float) return Widget_Access is
     (Object (Item, Dispatching.Hit_Slot (Item, X, Y)));

   --  Events

   --  Offer Event to From, and then its parents, until one takes it.

   --  From, or the nearest of its parents, that accepts the focus.

   --  The last input was by key, or by pointer: the focus ring is shown
   --  for the one and not the other.

   procedure Dispatch
     (Item    : in out Tree;
      Event   : Pomarine.Events.Event;
      Handled : out Boolean)
   is
   begin
      Dispatching.Dispatch_Event (Item, Event, Handled);
   end Dispatch;

   function Wanted_Cursor (Item : Tree) return SDL3.Cursors.Kind is
     (Dispatching.Cursor_Wanted (Item));

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

   procedure Set_Tooltip (Item : in out Widget'Class; Text : String) is
   begin
      if Text /= "" or else Item.Cold /= 0 then
         Semantics.Set (Block (Cold (Item)).all.Tip, Text);
      end if;
   end Set_Tooltip;

   function Tooltip_Of (Item : Widget'Class) return String is
     (if Item.Cold = 0 then "" else Semantics.To_String (Block (Item.Cold).all.Tip));

   procedure Enable_Tooltips
     (Item     : in out Tree;
      Tip      : in out Widget'Class;
      Present  : not null Tip_Presenter;
      Delay_MS : Natural := 600) is
   begin
      Item.Tip_Id := Id_Of (Tip);
      Item.Tip_Present := Present;
      Item.Tip_Delay := Delay_MS;
      Item.Tip_Over := No_Node;
      Item.Tip_Shown := False;
   end Enable_Tooltips;

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

   --  Tell of Slot if it has changed, and then of what is in it.

   procedure Describe_Changes
     (Item : in out Tree;
      Into : in out Semantic_Sink'Class;
      Whole : Boolean := False)
   is
   begin
      Accessibility.Tell_Changes (Item, Into, Whole);
   end Describe_Changes;

   procedure Act
     (Item    : in out Tree;
      Id      : Node_Id;
      Request : Semantics.Request;
      Done    : out Boolean)
   is
   begin
      Accessibility.Perform_On (Item, Id, Request, Done);
   end Act;

   --  Animation

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
   begin
      Animations.Start (Item, From, To, Milliseconds, How, Apply);
   end Animate;

   procedure Stop_Animations (Item : in out Widget'Class) is
   begin
      Animations.Stop (Item);
   end Stop_Animations;

   --  Time

   procedure Update (Item : in out Tree; Now : Pomarine.Events.Milliseconds) is
      Updating : Node_Index := Item.Root;
   begin
      Animations.Step_Animations (Item, Now);
      Item.Clock := Now;
      Tipping.Step (Item, Now);
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
      declare
         Tipped : constant Integer := Tipping.Wait (Item);
      begin
         if Tipped >= 0 and then (Result < 0 or else Tipped < Result) then
            Result := Tipped;
         end if;
      end;
      return Result;
   end Until_Update;

end Pomarine.Widgets;
