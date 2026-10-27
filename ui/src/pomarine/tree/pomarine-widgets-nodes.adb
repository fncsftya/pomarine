package body Pomarine.Widgets.Nodes is

   function To_Pixel (Value : Float) return Integer
   is (if Value /= Value
       then 0
       elsif Value <= -Float (Far)
       then -Far
       elsif Value >= Float (Far)
       then Far
       else Integer (Value));

   function Around (Across, Down, Wide, High : Float) return Pixel_Box is
      function Number (Value : Float) return Float
      is (if Value /= Value then 0.0 else Value);

      First : constant Integer := To_Pixel (Float'Floor (Number (Across)));
      Above : constant Integer := To_Pixel (Float'Floor (Number (Down)));
      Last  : constant Integer := To_Pixel (Float'Ceiling (Number (Across) + Number (Wide)));
      Below : constant Integer := To_Pixel (Float'Ceiling (Number (Down) + Number (High)));
   begin
      return (First, Above, Last - First, Below - Above);
   end Around;
   Chunk_Size : constant := 256;
   type Cold_Chunk is array (1 .. Chunk_Size) of aliased Cold_Block;
   type Cold_Chunk_Access is access Cold_Chunk;
   Chunks     : array (1 .. Node_Capacity / Chunk_Size + 1) of Cold_Chunk_Access := [others => null];
   Cold_Free  : Natural := 0;
   Cold_Fresh : Natural := 0;
   --  Made a chunk at a time, as they are wanted, and never moved, so that
   --  what runs a widget's handlers may make more. A block the application
   --  gave back is used again before one never used.

   function Block (Index : Positive) return not null access Cold_Block
   is (Chunks ((Index - 1) / Chunk_Size + 1) ((Index - 1) mod Chunk_Size + 1)'Access);

   function Cold (Item : in out Widget'Class) return Natural is
      Index : Natural;
   begin
      if Item.Cold = 0 then
         if Cold_Free /= 0 then
            Index := Cold_Free;
            Cold_Free := Block (Index).Link;
         else
            pragma Assert (Cold_Fresh < Node_Capacity, "more widgets with names or handlers than there is room for");
            Cold_Fresh := Cold_Fresh + 1;
            Index := Cold_Fresh;
            if Chunks ((Index - 1) / Chunk_Size + 1) = null then
               Chunks ((Index - 1) / Chunk_Size + 1) := new Cold_Chunk;
            end if;
         end if;
         Block (Index).all :=
           (Name  => Semantics.Empty_Text,
            Help  => Semantics.Empty_Text,
            Tip   => Semantics.Empty_Text,
            Hooks => [others => <>],
            Link  => 0);
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
   function Object (Item : Tree; Slot : Node_Index) return Widget_Access
   is (if Slot = 0 then null else Item.Nodes.Object (Slot));

   function Box_Of (Item : Tree; Slot : Node_Index) return Pixel_Box
   is (Around
         (Item.Nodes.Spot (Slot).Left,
          Item.Nodes.Spot (Slot).Top,
          Item.Nodes.Spot (Slot).Wide,
          Item.Nodes.Spot (Slot).High));

   function Box_Of (Item : Widget'Class) return Pixel_Box
   is (Box_Of (Item.Owner.all, Item.Slot));

   function Union (A, B : Pixel_Box) return Pixel_Box is
   begin
      if Is_Empty (A) then
         return B;
      elsif Is_Empty (B) then
         return A;
      end if;
      declare
         First : constant Integer := Integer'Min (A.Left, B.Left);
         Above : constant Integer := Integer'Min (A.Top, B.Top);
         Last  : constant Integer := Integer'Max (A.Left + A.Width, B.Left + B.Width);
         Below : constant Integer := Integer'Max (A.Top + A.Height, B.Top + B.Height);
      begin
         return (First, Above, Last - First, Below - Above);
      end;
   end Union;

   function Intersection (A, B : Pixel_Box) return Pixel_Box is
      First : constant Integer := Integer'Max (A.Left, B.Left);
      Above : constant Integer := Integer'Max (A.Top, B.Top);
      Last  : constant Integer := Integer'Min (A.Left + A.Width, B.Left + B.Width);
      Below : constant Integer := Integer'Min (A.Top + A.Height, B.Top + B.Height);
   begin
      return (First, Above, Integer'Max (0, Last - First), Integer'Max (0, Below - Above));
   end Intersection;

   function Id_Of_Slot (Item : Tree; Slot : Node_Index) return Node_Id
   is (if Slot = 0 then No_Node else (Slot, Item.Nodes.Use_Number (Slot), 0));

   function Has_Hook (Item : Widget'Class; Kind : Event_Kind) return Boolean
   is (Item.Cold /= 0 and then Block (Item.Cold).all.Hooks (Kind).Used);

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

end Pomarine.Widgets.Nodes;
