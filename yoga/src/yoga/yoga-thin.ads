with Interfaces.C;
with System;

--  Minimal thin C binding to Yoga. Internal: use Yoga.Nodes.
private package Yoga.Thin is

   use Interfaces.C;

   subtype Node_Ref is System.Address;

   type YG_Direction is (Inherit, LTR, RTL) with Convention => C;
   type YG_Flex_Direction is
     (Column, Column_Reverse, Row, Row_Reverse) with Convention => C;
   type YG_Justify is
     (Flex_Start, Center, Flex_End, Space_Between, Space_Around,
      Space_Evenly) with Convention => C;
   type YG_Align is
     (Auto, Flex_Start, Center, Flex_End, Stretch, Baseline, Space_Between,
      Space_Around, Space_Evenly) with Convention => C;
   type YG_Wrap is (No_Wrap, Wrap, Wrap_Reverse) with Convention => C;
   type YG_Edge is
     (Left, Top, Right, Bottom, Start, YG_End, Horizontal, Vertical,
      All_Edges)
     with Convention => C;
   type YG_Gutter is (Column, Row, All_Gutters) with Convention => C;
   type YG_Position is (Static, Relative, Absolute) with Convention => C;
   type YG_Display is (Flex, None, Contents) with Convention => C;

   function Node_New return Node_Ref
     with Import, Convention => C, External_Name => "YGNodeNew";

   procedure Node_Free_Recursive (Node : Node_Ref)
     with Import, Convention => C, External_Name => "YGNodeFreeRecursive";

   function Node_Child_Count (Node : Node_Ref) return size_t
     with Import, Convention => C, External_Name => "YGNodeGetChildCount";

   procedure Node_Remove_Child (Node : Node_Ref; Child : Node_Ref)
     with Import, Convention => C, External_Name => "YGNodeRemoveChild";

   procedure Node_Insert_Child
     (Node : Node_Ref; Child : Node_Ref; Index : size_t)
     with Import, Convention => C, External_Name => "YGNodeInsertChild";

   procedure Node_Calculate_Layout
     (Node             : Node_Ref;
      Available_Width  : C_float;
      Available_Height : C_float;
      Owner_Direction  : YG_Direction)
     with Import, Convention => C, External_Name => "YGNodeCalculateLayout";

   procedure Set_Flex_Direction (Node : Node_Ref; V : YG_Flex_Direction)
     with Import, Convention => C,
          External_Name => "YGNodeStyleSetFlexDirection";
   procedure Set_Justify_Content (Node : Node_Ref; V : YG_Justify)
     with Import, Convention => C,
          External_Name => "YGNodeStyleSetJustifyContent";
   procedure Set_Align_Items (Node : Node_Ref; V : YG_Align)
     with Import, Convention => C, External_Name => "YGNodeStyleSetAlignItems";
   procedure Set_Align_Self (Node : Node_Ref; V : YG_Align)
     with Import, Convention => C, External_Name => "YGNodeStyleSetAlignSelf";
   procedure Set_Flex_Wrap (Node : Node_Ref; V : YG_Wrap)
     with Import, Convention => C, External_Name => "YGNodeStyleSetFlexWrap";
   procedure Set_Position_Type (Node : Node_Ref; V : YG_Position)
     with Import, Convention => C,
          External_Name => "YGNodeStyleSetPositionType";
   procedure Set_Position (Node : Node_Ref; Side : YG_Edge; V : C_float)
     with Import, Convention => C, External_Name => "YGNodeStyleSetPosition";
   procedure Set_Display (Node : Node_Ref; V : YG_Display)
     with Import, Convention => C, External_Name => "YGNodeStyleSetDisplay";
   procedure Set_Flex_Grow (Node : Node_Ref; V : C_float)
     with Import, Convention => C, External_Name => "YGNodeStyleSetFlexGrow";
   procedure Set_Flex_Shrink (Node : Node_Ref; V : C_float)
     with Import, Convention => C,
          External_Name => "YGNodeStyleSetFlexShrink";
   procedure Set_Width (Node : Node_Ref; V : C_float)
     with Import, Convention => C, External_Name => "YGNodeStyleSetWidth";
   procedure Set_Height (Node : Node_Ref; V : C_float)
     with Import, Convention => C, External_Name => "YGNodeStyleSetHeight";
   procedure Set_Margin (Node : Node_Ref; Side : YG_Edge; V : C_float)
     with Import, Convention => C, External_Name => "YGNodeStyleSetMargin";
   procedure Set_Padding (Node : Node_Ref; Side : YG_Edge; V : C_float)
     with Import, Convention => C, External_Name => "YGNodeStyleSetPadding";
   procedure Set_Gap (Node : Node_Ref; Which : YG_Gutter; V : C_float)
     with Import, Convention => C, External_Name => "YGNodeStyleSetGap";

   type YG_Value is record
      Value : C_float;
      Unit  : int;  --  0 undefined, 1 point, 2 percent, 3 auto
   end record
     with Convention => C;

   function Get_Width (Node : Node_Ref) return YG_Value
     with Import, Convention => C, External_Name => "YGNodeStyleGetWidth";
   function Get_Height (Node : Node_Ref) return YG_Value
     with Import, Convention => C, External_Name => "YGNodeStyleGetHeight";
   function Get_Position (Node : Node_Ref; Side : YG_Edge) return YG_Value
     with Import, Convention => C, External_Name => "YGNodeStyleGetPosition";
   function Get_Margin (Node : Node_Ref; Side : YG_Edge) return YG_Value
     with Import, Convention => C, External_Name => "YGNodeStyleGetMargin";
   function Get_Padding (Node : Node_Ref; Side : YG_Edge) return YG_Value
     with Import, Convention => C, External_Name => "YGNodeStyleGetPadding";
   function Get_Gap (Node : Node_Ref; Which : YG_Gutter) return C_float
     with Import, Convention => C, External_Name => "YGNodeStyleGetGap";

   type YG_Measure_Mode is (Undefined, Exactly, At_Most) with Convention => C;

   type YG_Size is record
      Width, Height : C_float;
   end record
     with Convention => C;

   type Measure_Func is access function
     (Node        : Node_Ref;
      Width       : C_float;
      Width_Mode  : YG_Measure_Mode;
      Height      : C_float;
      Height_Mode : YG_Measure_Mode) return YG_Size
     with Convention => C;

   procedure Set_Measure_Func (Node : Node_Ref; Func : Measure_Func)
     with Import, Convention => C, External_Name => "YGNodeSetMeasureFunc";
   procedure Set_Context (Node : Node_Ref; Context : System.Address)
     with Import, Convention => C, External_Name => "YGNodeSetContext";
   function Get_Context (Node : Node_Ref) return System.Address
     with Import, Convention => C, External_Name => "YGNodeGetContext";
   procedure Mark_Dirty (Node : Node_Ref)
     with Import, Convention => C, External_Name => "YGNodeMarkDirty";
   function Get_Has_New_Layout (Node : Node_Ref) return Interfaces.C.C_bool
     with Import, Convention => C, External_Name => "YGNodeGetHasNewLayout";
   procedure Set_Has_New_Layout (Node : Node_Ref; V : Interfaces.C.C_bool)
     with Import, Convention => C, External_Name => "YGNodeSetHasNewLayout";

   function Layout_Left (Node : Node_Ref) return C_float
     with Import, Convention => C, External_Name => "YGNodeLayoutGetLeft";
   function Layout_Top (Node : Node_Ref) return C_float
     with Import, Convention => C, External_Name => "YGNodeLayoutGetTop";
   function Layout_Width (Node : Node_Ref) return C_float
     with Import, Convention => C, External_Name => "YGNodeLayoutGetWidth";
   function Layout_Height (Node : Node_Ref) return C_float
     with Import, Convention => C, External_Name => "YGNodeLayoutGetHeight";

end Yoga.Thin;
