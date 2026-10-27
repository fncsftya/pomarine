with Ada.Unchecked_Conversion;

package body Pomarine.Widgets.Adding is

   No_Yoga : Yoga.Nodes.Node;
   --  A node that is none.

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

   procedure Start_Measuring (Item : in out Widget'Class) is
   begin
      Yoga.Nodes.Set_Measured (Node (Item), Item'Address);
   end Start_Measuring;

   procedure Take_Slot (Home : in out Tree; Item : in out Widget'Class; Slot : out Node_Index) is
      Table : Node_Table renames Home.Nodes.all;
   begin
      if Table.Free /= 0 then
         Slot := Table.Free;
         Table.Free := Table.Next (Slot);
      else
         pragma Assert (Table.Fresh < Node_Capacity, "more widgets than the tree can hold");
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
      Home.Retell (Slot) := Item.Was_Told;
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

   procedure Plant_Root (Item : in out Tree; Root : in out Widget'Class) is
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
   end Plant_Root;

   procedure Attach (Parent : in out Widget'Class; Child : in out Widget'Class) is
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
   end Attach;

   procedure Attach (Parent : in out Widget'Class; First, Second, Third, Fourth : in out Widget'Class) is
   begin
      Add (Parent, First);
      Add (Parent, Second);
      Add (Parent, Third);
      Add (Parent, Fourth);
   end Attach;

   procedure Attach (Parent : in out Widget'Class; First, Second, Third, Fourth, Fifth : in out Widget'Class) is
   begin
      Add (Parent, First);
      Add (Parent, Second);
      Add (Parent, Third);
      Add (Parent, Fourth);
      Add (Parent, Fifth);
   end Attach;

   procedure Attach_Before (Parent : in out Widget'Class; Child : in out Widget'Class; Before : Widget'Class) is
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
      Table.Yoga_Node (Slot) := Yoga.Nodes.New_Child_At (Table.Yoga_Node (Above), Index);
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
   end Attach_Before;

end Pomarine.Widgets.Adding;
