with Pomarine.Semantics;
with SDL3.Painters;
with SDL3.Events;
with Pomarine.Scrollbars;

--  A box that shows part of what is taller than it is, to scroll with the
--  wheel (or a trackpad's two fingers): its one child, which it clips to
--  its box, and which the layout sizes to fit what is in it, as a column
--  of rows. While the pointer is over it, a bar along its right edge shows
--  how far down it is, and can be dragged.
--
--  It moves the child by the child's position, so the child's own style
--  must leave that to it.
package Pomarine.Widgets.Scrollers is

   Points_Per_Notch : constant Float := 24.0;
   --  How far a notch of the wheel scrolls.

   type Scroller is new Widget with private;

   procedure Set_Across (Item : in out Scroller; Across : Boolean);
   --  Make it scroll a row, wider than the box, along its bottom edge
   --  (the offset is then how far the child has moved left), rather than
   --  a column. A vertical wheel moves it too.

   function Offset (Item : Scroller) return Float;
   --  How far the child has been moved up, in points: 0 when its top is
   --  at the top of the box.

   procedure Scroll_To (Item : in out Scroller; To : Float)
     with Pre => Is_Attached (Item) and then Child_Count (Item) = 1;
   --  Show the child from To points down, no further than shows its end,
   --  as of the last layout, and no less than its start.

   procedure Scroll_Smoothly (Item : in out Scroller; To : Float; Milliseconds : Natural := 180)
     with Pre => Is_Attached (Item) and then Child_Count (Item) = 1;
   --  As Scroll_To, over Milliseconds, as an animation of the tree's (see
   --  Pomarine.Widgets.Animate): at once if the system asks for less
   --  movement.

   overriding procedure Draw_Over
     (Item   : in out Scroller;
      Target : SDL3.Painters.Painter'Class;
      Colors : Themes.Theme);
   --  Its scroll bar, over the child.

   overriding procedure Hover_Changed
     (Item : in out Scroller; Hovered : Boolean);

   overriding procedure Handle
     (Item    : in out Scroller;
      Event   : SDL3.Events.Event;
      Handled : out Boolean);

   overriding procedure Describe
     (Item  : Scroller;
      Facts : in out Semantics.Description);
   overriding procedure Perform
     (Item    : in out Scroller;
      Request : Semantics.Request;
      Done    : out Boolean);

private

   type Scroller is new Widget with record
      Moved : Float := 0.0;
      Across : Boolean := False;
      Bar   : Scrollbars.Bar;
   end record;

end Pomarine.Widgets.Scrollers;
