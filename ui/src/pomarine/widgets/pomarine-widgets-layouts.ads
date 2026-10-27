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
--  A size is a Length, a share of the room left a Weight: a plain number is
--  taken as one (Width => 206.0), and what is not a number is named, so that
--  what stands for "leave it" or "one outline's width" cannot be mixed up with
--  a size (Unset, Hairline, Shadow_Room, In_Pixels (X), In_Points (X) for a variable).
--
--     Set_Layout (Side, Width => In_Points (Wide), Margin => (Top => Hairline, others => <>));
--     Row (Bar, Gap => 4.0, Padding => (others => 8.0));    --  Flow => Row, and the rest
--
--  It is for building and for when the density or the content changes, not
--  for every frame. What it does not cover (a node's percentages, say) is
--  done with Node, then Request_Layout.

package Pomarine.Widgets.Layouts is

   type Length is private with Real_Literal => Length_Of_Literal;
   --  A size or an edge, which is one of: a number of points (a literal
   --  such as 8.0 is, or In_Points (Wide)); a number of device pixels
   --  (In_Pixels); Unset, which a call leaves as it is; Hairline, one
   --  outline's width (see Pomarine.Boxes.Edge), in whole pixels, as of a
   --  rule; Shadow_Room, the offset of a shadow (see Pomarine.Boxes.Offset),
   --  in whole pixels.

   type Weight is private with Real_Literal => Weight_Of_Literal;
   --  A share of the room left over (Grow) or short (Shrink) among
   --  siblings: a number, or Unchanged.

   function Length_Of_Literal (Text : String) return Length;
   function Weight_Of_Literal (Text : String) return Weight;
   --  What a real literal is.

   function Length_Of (Amount : Float) return Length;
   --  A number that is worked out, in the Unit of the call, as a plain
   --  literal is: points, unless the call says Device_Pixels.

   function In_Points (Amount : Float) return Length;
   --  Of the window, as the tree's density makes of it pixels, whatever the
   --  Unit of the call: for a size that is worked out (In_Points (Wide * 2.0)).

   function In_Pixels (Amount : Float) return Length;
   --  The target's own, whatever the Unit of the call: for what is measured
   --  from a laid-out box, or made whole by Pomarine.Boxes.

   function Weight_Of (Amount : Float) return Weight;

   function "-" (Item : Length) return Length;
   --  The other way: of a size in points or pixels.

   Unset : constant Length;
   --  A size or an edge that a call leaves as it is.

   Hairline : constant Length;
   --  One outline's width, in whole pixels.

   Shadow_Room : constant Length;
   --  The offset of a shadow, in whole pixels.

   Unchanged : constant Weight;
   --  A share that a call leaves as it is.

   function Is_Set (Item : Length) return Boolean;
   --  Whether it is not Unset.

   type Sides is record
      Left, Top, Right, Bottom : Length := Unset;
   end record;
   --  Edges, each in points: for padding and margin, and for the places
   --  of a widget put by its edges.
   --     (others => 8.0)                        all four
   --     (Left | Right => 8.0, others => <>)    two, leaving the others

   type Toggle_Kind is (As_Is, On, Off);
   --  Something a call turns on, turns off, or leaves as it is.

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
      Width      : Length := Unset;
      Height     : Length := Unset;
      Grow       : Weight := Unchanged;
      Shrink     : Weight := Unchanged;
      Padding    : Sides := (others => <>);
      Outlined   : Toggle_Kind := As_Is;
      Shadowed   : Toggle_Kind := As_Is;
      Margin     : Sides := (others => <>);
      Gap        : Length := Unset;
      Flow       : Flow_Kind := As_Is;
      Align      : Align_Kind := As_Is;
      Align_Self : Align_Kind := As_Is;
      Spread     : Spread_Kind := As_Is;
      Wrap       : Toggle_Kind := As_Is;
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
   with
     Pre  => Is_Attached (Parent) and then not Is_Attached (Child) and then Child_Count (Child) = 0,
     Post => Is_Attached (Child);
   --  Add Child to Parent (see Pomarine.Widgets.Add) and style its box, in
   --  one line:
   --     Layouts.Add (Footer, Summary, (Grow => 1.0, Height => 24.0, others => <>));

   procedure Add_Before
     (Parent : in out Widget'Class; Child : in out Widget'Class; Before : Widget'Class; Using : Style)
   with
     Pre  =>
       Is_Attached (Parent)
       and then not Is_Attached (Child)
       and then Child_Count (Child) = 0
       and then Parent_Of (Before) /= null,
     Post => Is_Attached (Child);
   --  As Add, but just before Before, one of Parent's children (see
   --  Pomarine.Widgets.Add_Before).

   procedure Set_Layout
     (Item       : in out Widget'Class;
      Width      : Length := Unset;
      Height     : Length := Unset;
      Grow       : Weight := Unchanged;
      Shrink     : Weight := Unchanged;
      Padding    : Sides := (others => <>);
      Outlined   : Toggle_Kind := As_Is;
      Shadowed   : Toggle_Kind := As_Is;
      Margin     : Sides := (others => <>);
      Gap        : Length := Unset;
      Flow       : Flow_Kind := As_Is;
      Align      : Align_Kind := As_Is;
      Align_Self : Align_Kind := As_Is;
      Spread     : Spread_Kind := As_Is;
      Wrap       : Toggle_Kind := As_Is;
      Place      : Place_Kind := As_Is;
      Position   : Sides := (others => <>);
      Unit       : Unit_Kind := Points)
   with Pre => Is_Attached (Item);
   --  Width and Height are in points. Outlined and Shadowed make room in
   --  the padding for what a panel or grip draws inside its box: its
   --  outline all round, and a shadow (see Pomarine.Boxes) at its right and
   --  foot, in whole pixels; they are added to Padding, which is in points. Grow and Shrink are the shares of
   --  the room left over, or short, among its siblings. Gap is between its
   --  children. Align is of its children, and Align_Self of it among its
   --  siblings. Wrap (On or Off) lets its children go on to another line, or
   --  not. Outlined and Shadowed (On or Off) have the room made, or not: Off, the
   --  padding is what the call says (none, if it says none), with no room in it.
   --  Unit is of the numbers given as plain literals in Width, Height,
   --  Padding, Margin, Gap and Position, all those of the call; In_Points and
   --  In_Pixels say theirs. Requests a layout.

   function Row
     (Width   : Length := Unset;
      Height  : Length := Unset;
      Grow    : Weight := Unchanged;
      Shrink  : Weight := Unchanged;
      Padding : Sides := (others => <>);
      Margin  : Sides := (others => <>);
      Gap     : Length := Unset;
      Align   : Align_Kind := As_Is;
      Spread  : Spread_Kind := As_Is;
      Wrap    : Toggle_Kind := As_Is) return Style;
   --  A style that has its children go across (Flow => Row), and what else is said.

   function Column
     (Width   : Length := Unset;
      Height  : Length := Unset;
      Grow    : Weight := Unchanged;
      Shrink  : Weight := Unchanged;
      Padding : Sides := (others => <>);
      Margin  : Sides := (others => <>);
      Gap     : Length := Unset;
      Align   : Align_Kind := As_Is;
      Spread  : Spread_Kind := As_Is;
      Wrap    : Toggle_Kind := As_Is) return Style;
   --  The same, down (Flow => Column).
   --     Layouts.Add (Page, Bar, Layouts.Row (Height => 32.0, Gap => 4.0));

   procedure Row
     (Item    : in out Widget'Class;
      Width   : Length := Unset;
      Height  : Length := Unset;
      Grow    : Weight := Unchanged;
      Shrink  : Weight := Unchanged;
      Padding : Sides := (others => <>);
      Margin  : Sides := (others => <>);
      Gap     : Length := Unset;
      Align   : Align_Kind := As_Is;
      Spread  : Spread_Kind := As_Is;
      Wrap    : Toggle_Kind := As_Is)
   with Pre => Is_Attached (Item);
   --  Set_Layout of Item with Row's style: Row (Bar, Gap => 4.0).

   procedure Column
     (Item    : in out Widget'Class;
      Width   : Length := Unset;
      Height  : Length := Unset;
      Grow    : Weight := Unchanged;
      Shrink  : Weight := Unchanged;
      Padding : Sides := (others => <>);
      Margin  : Sides := (others => <>);
      Gap     : Length := Unset;
      Align   : Align_Kind := As_Is;
      Spread  : Spread_Kind := As_Is;
      Wrap    : Toggle_Kind := As_Is)
   with Pre => Is_Attached (Item);
   --  The same, down.

private

   type Length_Kind is (Unspecified, Unit_Relative, Point_Based, Pixel_Based, One_Outline, One_Shadow);

   type Length is record
      Kind   : Length_Kind := Unspecified;
      Amount : Float := 0.0;
   end record;

   type Weight is record
      Given  : Boolean := False;
      Amount : Float := 0.0;
   end record;

   Unset       : constant Length := (Kind => Unspecified, Amount => 0.0);
   Hairline    : constant Length := (Kind => One_Outline, Amount => 0.0);
   Shadow_Room : constant Length := (Kind => One_Shadow, Amount => 0.0);
   Unchanged   : constant Weight := (Given => False, Amount => 0.0);

end Pomarine.Widgets.Layouts;
