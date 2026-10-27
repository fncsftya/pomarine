with Pomarine.Events;
with Pomarine.Semantics;
with SDL3.Cursors;
with SDL3.Painters;

--  A bar between two boxes of a row (or a column) that the person drags to give one more room and the other less: the
--  box before it is made as wide (or as high) as the pointer's distance from its start, within the limits (Set_Limits),
--  and the one after it, which has Grow, takes the rest. With the focus (Set_Focusable) the arrow keys move it by
--  Key_Step points. It says Change each time its box is made another size; the size is Position.
--
--     Layouts.Add (Page, Sidebar, (Width => 200.0, Shrink => 0.0, others => <>));
--     Splitters.Add (Page, Divider);
--     Layouts.Add (Page, Content, (Grow => 1.0, others => <>));
--
--  A Splitter is across its parent's flow if that is a row (it is a bar that divides left from right) and along it
--  if it is a column.

package Pomarine.Widgets.Splitters is

   Thickness : constant Float := 6.0;
   --  In points: the width of the bar of a row, the height of one of a column.

   Key_Step : constant Float := 16.0;
   --  In points.

   type Splitter is new Widget with private;

   procedure Add (Parent : in out Widget'Class; Item : in out Splitter; Along : Boolean := False)
   with
     Pre  => Is_Attached (Parent) and then not Is_Attached (Item) and then Child_Count (Item) = 0,
     Post => Is_Attached (Item);
   --  Add Item to Parent after the box it divides from the next. Along: it is for a column (the bar is across
   --  it, and drags up and down); a row's is the other.

   procedure Set_Limits (Item : in out Splitter; Least, Most : Float)
   with Pre => Least >= 0.0 and then Most >= Least;
   --  The least and the most, in points, that the box before it may be made; 80 and 100000 to begin with.

   function Position (Item : Splitter) return Float;
   --  In points: how wide (or high) the box before it is, as it was last laid out.

   procedure Set_Position (Item : in out Splitter; To : Float)
   with Pre => Is_Attached (Item) and then To >= 0.0;
   --  Make the box before it To points, within the limits, saying nothing.

   procedure Set_Focusable (Item : in out Splitter; To : Boolean);

   overriding
   function Is_Focusable (Item : Splitter) return Boolean;

   overriding
   function Focuses_On_Click (Item : Splitter) return Boolean
   is (False);

   overriding
   procedure Handle (Item : in out Splitter; Event : Pomarine.Events.Event; Handled : out Boolean);

   overriding
   procedure Draw (Item : in out Splitter; Target : SDL3.Painters.Painter'Class; Colors : Themes.Theme);

   overriding
   procedure Draw_Over (Item : in out Splitter; Target : SDL3.Painters.Painter'Class; Colors : Themes.Theme);

   overriding
   procedure Hover_Changed (Item : in out Splitter; Hovered : Boolean);

   overriding
   procedure Focus_Changed (Item : in out Splitter; Focused : Boolean);

   overriding
   function Cursor (Item : Splitter) return SDL3.Cursors.Kind;

   overriding
   procedure Describe (Item : Splitter; Facts : in out Semantics.Description);

   overriding
   procedure Perform (Item : in out Splitter; Request : Semantics.Request; Done : out Boolean);

private

   type Splitter is new Widget with record
      Down_Bar  : Boolean := False;
      --  Along: across a column, dragging up and down.
      Least     : Float := 80.0;
      Most      : Float := 100_000.0;
      Held      : Boolean := False;
      Grab      : Float := 0.0;
      --  While held: how far into the bar, in pixels, the pointer took it.
      Focusable : Boolean := False;
   end record;

end Pomarine.Widgets.Splitters;
