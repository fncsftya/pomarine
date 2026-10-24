--  Styling a widget's box, in points.
--
--  A widget's box is set by Yoga's flexbox, through its node. This is a way
--  to say what that is in one call, with only what differs from before
--  named, and in points: the tree knows the density of its pixels, so an
--  application does not multiply by it. A call changes only what it names.
--
--     Set_Layout (Side, Width => 206.0, Flow => Column, Padding => (others => 11.0), Gap => 8.0);
--     Set_Layout (Button, Height => 28.0, Margin => (Top => 4.0, others => <>));
--
--  It is for building and for when the density or the content changes, not
--  for every frame. What it does not cover (a node's percentages, say) is
--  done with Node, then Request_Layout.
package Pomarine.Widgets.Layouts is

   Unset : constant Float := Float'First;
   --  A size or edge that a call leaves as it is.

   Hairline : constant Float := -1.0E30;
   --  As a size or an edge: one outline's width (see Pomarine.Boxes.Edge),
   --  in whole pixels, as of a rule.

   Shadow_Room : constant Float := -2.0E30;
   --  As a size or an edge: the offset of a shadow (see Pomarine.Boxes.Offset),
   --  in whole pixels.

   type Sides is record
      Left, Top, Right, Bottom : Float := Unset;
   end record;
   --  Edges, each in points: for padding and margin, and for the places
   --  of a widget put by its edges.
   --     (others => 8.0)                        all four
   --     (Left | Right => 8.0, others => <>)    two, leaving the others

   type Unit_Kind is (Points, Device_Pixels);
   --  What the sizes and edges of a call are in. Points are of the window,
   --  and the tree multiplies them by its density; Device_Pixels are the
   --  target's own, as what is measured from a laid-out box, or made whole
   --  by Pomarine.Boxes. The sizes Hairline and Shadow_Room are pixels
   --  whichever.

   type Flow_Kind is (As_Is, Column, Row);
   --  Whether its children go down it, or across it.

   type Align_Kind is (As_Is, Start, Center, Finish, Stretch);
   --  How children, or a child, sit across the flow.

   type Spread_Kind is (As_Is, Start, Center, Finish, Between);
   --  How children are spread along the flow.

   type Place_Kind is (As_Is, Flowing, Absolute);
   --  Flowing takes its place among its siblings; Absolute takes no room
   --  there, and is put by its edges (Position) from its parent's.

   type Style is record
      Width      : Float := Unset;
      Height     : Float := Unset;
      Grow       : Float := Unset;
      Shrink     : Float := Unset;
      Padding    : Sides := (others => <>);
      Outlined   : Boolean := False;
      Shadowed   : Boolean := False;
      Margin     : Sides := (others => <>);
      Gap        : Float := Unset;
      Flow       : Flow_Kind := As_Is;
      Align      : Align_Kind := As_Is;
      Align_Self : Align_Kind := As_Is;
      Spread     : Spread_Kind := As_Is;
      Wrap       : Boolean := False;
      Place      : Place_Kind := As_Is;
      Position   : Sides := (others => <>);
      Unit       : Unit_Kind := Points;
   end record;
   --  What a call of Set_Layout says, as a value, to be given with a widget
   --  when it is added (see Add), kept, or made once and used for many. Only
   --  what is named is changed; the others are left as they are.
   --     (Width => 120.0, Height => 32.0, others => <>)

   procedure Set_Layout (Item : in out Widget'Class; Using : Style)
     with Pre => Is_Attached (Item);
   --  As the call below, with the style as a value.

   procedure Add (Parent : in out Widget'Class; Child : in out Widget'Class; Using : Style)
     with Pre => Is_Attached (Parent) and then not Is_Attached (Child) and then Child_Count (Child) = 0,
          Post => Is_Attached (Child);
   --  Add Child to Parent (see Pomarine.Widgets.Add) and style its box, in
   --  one line:
   --     Layouts.Add (Footer, Summary, (Grow => 1.0, Height => 24.0, others => <>));

   procedure Add_Before
     (Parent : in out Widget'Class;
      Child  : in out Widget'Class;
      Before : Widget'Class;
      Using  : Style)
     with Pre  => Is_Attached (Parent) and then not Is_Attached (Child) and then Child_Count (Child) = 0
                  and then Parent_Of (Before) /= null,
          Post => Is_Attached (Child);
   --  As Add, but just before Before, one of Parent's children (see
   --  Pomarine.Widgets.Add_Before).

   procedure Set_Layout
     (Item     : in out Widget'Class;
      Width    : Float := Unset;
      Height   : Float := Unset;
      Grow     : Float := Unset;
      Shrink   : Float := Unset;
      Padding  : Sides := (others => <>);
      Outlined : Boolean := False;
      Shadowed : Boolean := False;
      Margin   : Sides := (others => <>);
      Gap      : Float := Unset;
      Flow     : Flow_Kind := As_Is;
      Align    : Align_Kind := As_Is;
      Align_Self : Align_Kind := As_Is;
      Spread   : Spread_Kind := As_Is;
      Wrap     : Boolean := False;
      Place    : Place_Kind := As_Is;
      Position : Sides := (others => <>);
      Unit     : Unit_Kind := Points)
     with Pre => Is_Attached (Item);
   --  Width and Height are in points. Outlined and Shadowed make room in
   --  the padding for what a panel or grip draws inside its box: its
   --  outline all round, and a shadow (see Pomarine.Boxes) at its right and
   --  foot, in whole pixels; they are added to Padding, which is in points. Grow and Shrink are the shares of
   --  the room left over, or short, among its siblings. Gap is between its
   --  children. Align is of its children, and Align_Self of it among its
   --  siblings. Wrap lets its children go on to another line (it cannot be
   --  turned off here). Unit is of Width, Height, Padding, Margin, Gap and
   --  Position, all those of the call. Requests a layout.

end Pomarine.Widgets.Layouts;
