with Interfaces.C;
with Yoga.Thin;

package body Yoga.Nodes is

   use type System.Address;
   use type Interfaces.C.C_float;

   function C (Value : Float) return Interfaces.C.C_float
   is (Interfaces.C.C_float (Value));

   --  Measuring

   Handler_In_Use : Measure_Handler;

   function To_Mode (Item : Thin.YG_Measure_Mode) return Measure_Mode
   is (case Item is
         when Thin.Undefined => Undefined,
         when Thin.Exactly   => Exactly,
         when Thin.At_Most   => At_Most);

   function Measure_Trampoline
     (Leaf      : Thin.Node_Ref;
      Room_Wide : Interfaces.C.C_float;
      Wide_Mode : Thin.YG_Measure_Mode;
      Room_High : Interfaces.C.C_float;
      High_Mode : Thin.YG_Measure_Mode) return Thin.YG_Size
   with Convention => C;

   function Measure_Trampoline
     (Leaf      : Thin.Node_Ref;
      Room_Wide : Interfaces.C.C_float;
      Wide_Mode : Thin.YG_Measure_Mode;
      Room_High : Interfaces.C.C_float;
      High_Mode : Thin.YG_Measure_Mode) return Thin.YG_Size
   is
      Result : constant Measured_Size :=
        Handler_In_Use
          (Thin.Get_Context (Leaf), Float (Room_Wide), To_Mode (Wide_Mode), Float (Room_High), To_Mode (High_Mode));
   begin
      return (Width => Interfaces.C.C_float (Result.Width), Height => Interfaces.C.C_float (Result.Height));
   end Measure_Trampoline;

   procedure Set_Measure_Handler (Handler : Measure_Handler) is
   begin
      Handler_In_Use := Handler;
   end Set_Measure_Handler;

   procedure Set_Measured (Item : Node; Context : System.Address) is
   begin
      Thin.Set_Context (Item.Handle, Context);
      Thin.Set_Measure_Func (Item.Handle, Measure_Trampoline'Access);
   end Set_Measured;

   procedure Mark_Dirty (Item : Node) is
   begin
      Thin.Mark_Dirty (Item.Handle);
   end Mark_Dirty;

   function Has_New_Layout (Item : Node) return Boolean
   is (Boolean (Thin.Get_Has_New_Layout (Item.Handle)));

   procedure Clear_New_Layout (Item : Node) is
   begin
      Thin.Set_Has_New_Layout (Item.Handle, Interfaces.C.C_bool (False));
   end Clear_New_Layout;

   overriding
   procedure Initialize (Item : in out Tree) is
   begin
      Item.Root_Node.Handle := Thin.Node_New;
   end Initialize;

   overriding
   procedure Finalize (Item : in out Tree) is
   begin
      if Item.Root_Node.Handle /= System.Null_Address then
         Thin.Node_Free_Recursive (Item.Root_Node.Handle);
         Item.Root_Node.Handle := System.Null_Address;
      end if;
   end Finalize;

   function Root (Item : Tree) return Node
   is (Item.Root_Node);

   function New_Child (Parent : Node) return Node is
      Child : constant Thin.Node_Ref := Thin.Node_New;
   begin
      Thin.Node_Insert_Child (Parent.Handle, Child, Thin.Node_Child_Count (Parent.Handle));
      return (Handle => Child);
   end New_Child;

   function New_Child_At (Parent : Node; Index : Natural) return Node is
      Child : constant Thin.Node_Ref := Thin.Node_New;
   begin
      Thin.Node_Insert_Child (Parent.Handle, Child, Interfaces.C.size_t (Index));
      return (Handle => Child);
   end New_Child_At;

   procedure Delete (Parent : Node; Child : Node) is
   begin
      Thin.Node_Remove_Child (Parent.Handle, Child.Handle);
      Thin.Node_Free_Recursive (Child.Handle);
   end Delete;

   procedure Set_Position_Type (Item : Node; Value : Position_Mode) is
   begin
      Thin.Set_Position_Type (Item.Handle, Thin.YG_Position'Val (Position_Mode'Pos (Value)));
   end Set_Position_Type;

   procedure Set_Position (Item : Node; Side : Edge; Value : Float) is
   begin
      Thin.Set_Position (Item.Handle, Thin.YG_Edge'Val (Edge'Pos (Side)), C (Value));
   end Set_Position;

   procedure Set_Display (Item : Node; Value : Display_Mode) is
   begin
      Thin.Set_Display (Item.Handle, Thin.YG_Display'Val (Display_Mode'Pos (Value)));
   end Set_Display;

   procedure Set_Flex_Direction (Item : Node; Value : Flex_Direction) is
   begin
      Thin.Set_Flex_Direction (Item.Handle, Thin.YG_Flex_Direction'Val (Flex_Direction'Pos (Value)));
   end Set_Flex_Direction;

   procedure Set_Justify_Content (Item : Node; Value : Justify) is
   begin
      Thin.Set_Justify_Content (Item.Handle, Thin.YG_Justify'Val (Justify'Pos (Value)));
   end Set_Justify_Content;

   procedure Set_Align_Items (Item : Node; Value : Align) is
   begin
      Thin.Set_Align_Items (Item.Handle, Thin.YG_Align'Val (Align'Pos (Value)));
   end Set_Align_Items;

   procedure Set_Align_Self (Item : Node; Value : Align) is
   begin
      Thin.Set_Align_Self (Item.Handle, Thin.YG_Align'Val (Align'Pos (Value)));
   end Set_Align_Self;

   procedure Set_Wrap (Item : Node; Value : Wrap_Mode) is
   begin
      Thin.Set_Flex_Wrap (Item.Handle, Thin.YG_Wrap'Val (Wrap_Mode'Pos (Value)));
   end Set_Wrap;

   procedure Set_Flex_Grow (Item : Node; Value : Float) is
   begin
      Thin.Set_Flex_Grow (Item.Handle, C (Value));
   end Set_Flex_Grow;

   procedure Set_Flex_Shrink (Item : Node; Value : Float) is
   begin
      Thin.Set_Flex_Shrink (Item.Handle, C (Value));
   end Set_Flex_Shrink;

   procedure Set_Width (Item : Node; Value : Float) is
   begin
      Thin.Set_Width (Item.Handle, C (Value));
   end Set_Width;

   procedure Set_Height (Item : Node; Value : Float) is
   begin
      Thin.Set_Height (Item.Handle, C (Value));
   end Set_Height;

   procedure Set_Margin (Item : Node; Side : Edge; Value : Float) is
   begin
      Thin.Set_Margin (Item.Handle, Thin.YG_Edge'Val (Edge'Pos (Side)), C (Value));
   end Set_Margin;

   procedure Set_Padding (Item : Node; Side : Edge; Value : Float) is
   begin
      Thin.Set_Padding (Item.Handle, Thin.YG_Edge'Val (Edge'Pos (Side)), C (Value));
   end Set_Padding;

   procedure Set_Gap (Item : Node; Which : Gutter; Value : Float) is
   begin
      Thin.Set_Gap (Item.Handle, Thin.YG_Gutter'Val (Gutter'Pos (Which)), C (Value));
   end Set_Gap;

   procedure Scale_Style (Item : Node; By : Float) is
      use type Interfaces.C.int;
      Point : constant := 1;
      Sides : constant array (1 .. 4) of Thin.YG_Edge := [Thin.Left, Thin.Top, Thin.Right, Thin.Bottom];
      Value : Thin.YG_Value;
      pragma Suppress (Validity_Check);  --  a gap not set is NaN
   begin
      Value := Thin.Get_Width (Item.Handle);
      if Value.Unit = Point then
         Thin.Set_Width (Item.Handle, Value.Value * C (By));
      end if;
      Value := Thin.Get_Height (Item.Handle);
      if Value.Unit = Point then
         Thin.Set_Height (Item.Handle, Value.Value * C (By));
      end if;
      for Side of Sides loop
         Value := Thin.Get_Position (Item.Handle, Side);
         if Value.Unit = Point then
            Thin.Set_Position (Item.Handle, Side, Value.Value * C (By));
         end if;
         Value := Thin.Get_Margin (Item.Handle, Side);
         if Value.Unit = Point then
            Thin.Set_Margin (Item.Handle, Side, Value.Value * C (By));
         end if;
         Value := Thin.Get_Padding (Item.Handle, Side);
         if Value.Unit = Point then
            Thin.Set_Padding (Item.Handle, Side, Value.Value * C (By));
         end if;
      end loop;
      for Which in Thin.YG_Gutter range Thin.Column .. Thin.Row loop
         declare
            Gap : constant Interfaces.C.C_float := Thin.Get_Gap (Item.Handle, Which);
         begin
            --  Not set, it is NaN, which is not equal to itself.
            if Gap = Gap then
               Thin.Set_Gap (Item.Handle, Which, Gap * C (By));
            end if;
         end;
      end loop;
   end Scale_Style;

   procedure Calculate_Layout (Item : Tree; Available_Width : Float; Available_Height : Float) is
   begin
      Thin.Node_Calculate_Layout (Item.Root_Node.Handle, C (Available_Width), C (Available_Height), Thin.LTR);
   end Calculate_Layout;

   function Left (Item : Node) return Float
   is (Float (Thin.Layout_Left (Item.Handle)));
   function Top (Item : Node) return Float
   is (Float (Thin.Layout_Top (Item.Handle)));
   function Width (Item : Node) return Float
   is (Float (Thin.Layout_Width (Item.Handle)));
   function Height (Item : Node) return Float
   is (Float (Thin.Layout_Height (Item.Handle)));

end Yoga.Nodes;
