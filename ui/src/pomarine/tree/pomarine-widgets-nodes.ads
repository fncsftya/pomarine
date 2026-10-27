--  What the sections of Pomarine.Widgets (animations, accessibility, and the rest) share: pixels from
--  floats, the seldom-used parts of widgets, and where a node is in the tree's table.

private package Pomarine.Widgets.Nodes is

   --  Boxes

   Far : constant := 2**28;
   --  No pixel is further than this from the origin, so that sums and
   --  differences of two of them stay in Integer.

   function To_Pixel (Value : Float) return Integer
   with Post => To_Pixel'Result in -Far .. Far;
   --  Value as a pixel, kept within Far of the origin: a layout that has
   --  gone wrong (not a number, infinite, or beyond any screen) must not
   --  stop the application from drawing.

   function Around (Across, Down, Wide, High : Float) return Pixel_Box
   with
     Post =>
       Around'Result.Left in -Far .. Far
       and then Around'Result.Top in -Far .. Far
       and then Around'Result.Width in -2 * Far .. 2 * Far
       and then Around'Result.Height in -2 * Far .. 2 * Far
       and then (if Wide >= 0.0 and then High >= 0.0 then Around'Result.Width >= 0 and then Around'Result.Height >= 0);
   --  The pixels that any of the box touches. A position or size that is
   --  not a number counts as zero, and one beyond Far as Far.

   --  The seldom-used parts of widgets, kept apart from them: the names the
   --  application gave, and its handlers. Most widgets have none, and the
   --  rest do not use them while they are drawn and walked over, so they
   --  are not in the way of those, which are most of what is done.

   type Cold_Block is record
      Name  : Semantics.Text;
      Help  : Semantics.Text;
      Tip   : Semantics.Text;
      Hooks : Hook_Array;
      Link  : Natural;
      --  While it is given back: the next that is.
   end record;
   pragma Suppress_Initialization (Cold_Block);

   function Block (Index : Positive) return not null access Cold_Block;

   function Cold (Item : in out Widget'Class) return Natural;
   --  Where Item's seldom-used parts are, made if it has none.

   procedure Give_Back_Cold (Item : in out Widget'Class);

   --  The table

   function Object (Item : Tree; Slot : Node_Index) return Widget_Access;
   --  The widget in Slot, or null for none.

   function Box_Of (Item : Tree; Slot : Node_Index) return Pixel_Box;

   function Box_Of (Item : Widget'Class) return Pixel_Box;

   function Union (A, B : Pixel_Box) return Pixel_Box;
   --  The smallest box with both in it.

   function Intersection (A, B : Pixel_Box) return Pixel_Box;
   --  What is in both.

   function Id_Of_Slot (Item : Tree; Slot : Node_Index) return Node_Id;

   function Has_Hook (Item : Widget'Class; Kind : Event_Kind) return Boolean;

   function Following_Shown (Item : Tree; Slot : Node_Index) return Node_Index;
   --  The next widget in the walk of the tree (parents before their children, and children in order), but not
   --  into widgets that are hidden.

end Pomarine.Widgets.Nodes;
