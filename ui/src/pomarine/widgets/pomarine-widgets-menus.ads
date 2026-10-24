with Ada.Containers.Vectors;
with Pomarine.Semantics;
with SDL3.Painters;
with SDL3.Cursors;
with SDL3.Events;
with Pomarine.Icons;

--  A menu, as of a dropdown or a context menu: a column of rows on a white
--  box, outlined, casting a solid shadow. A row is a heading, the small
--  faint name of what follows; an action to click, with an icon before it
--  if it is given one; a box to tick, with a square of a colour if it is
--  given one; a line between rows; or a note, faint, as of there being
--  nothing to choose. An action or a box can be plain, or in the theme's
--  primary or danger colour, as of what it does.
--
--  The row under the pointer, of those that can be clicked, is shaded.
--  A click on one is the application's to take (Take_Choice), as a
--  button's; it says back how the rows are to be, as by ticking one.
--
--  It is as tall as its rows (and sets its own node's height, so), and as
--  wide as the application makes it. The application shows it, over what
--  is there, and hides it.
package Pomarine.Widgets.Menus is

   Text_Capacity : constant := 256;
   --  Bytes of the text of a row: room for complete replacement text; drawing ellipsizes long rows.

   type Row_Kind is (Heading, Action, Check, Separator, Note);

   type Tone is (Plain, Primary, Danger);

   type Menu is new Widget with private;

   procedure Clear (Item : in out Menu)
     with Post => Row_Count (Item) = 0;

   procedure Add
     (Item    : in out Menu;
      Kind    : Row_Kind;
      Text    : String := "";
      Shade   : Tone := Plain;
      Checked : Boolean := False)
     with Pre  => Text'Length <= Text_Capacity,
          Post => Row_Count (Item) = Row_Count (Item)'Old + 1;
   --  Add a row after the others.

   function Row_Count (Item : Menu) return Natural;

   procedure Set_Faced (Item : in out Menu; To : Boolean);
   --  Draw the text of each action and box in the font it names, as of a
   --  menu of fonts.

   function Is_Faced (Item : Menu) return Boolean;

   procedure Set_Icon (Item : in out Menu; Row : Positive; To : Pomarine.Icons.Icon)
     with Pre => Row <= Row_Count (Item);

   procedure Set_Swatch
     (Item : in out Menu; Row : Positive; To : Themes.Slot)
     with Pre => Row <= Row_Count (Item);

   procedure Set_Checked (Item : in out Menu; Row : Positive; To : Boolean)
     with Pre => Row <= Row_Count (Item);

   procedure Set_Enabled (Item : in out Menu; Row : Positive; To : Boolean)
     with Pre => Row <= Row_Count (Item);
   --  Turn off an action or a box, to be shown faint and not taken when
   --  clicked, or on again; they are on to begin with.

   function Is_Enabled (Item : Menu; Row : Positive) return Boolean
     with Pre => Row <= Row_Count (Item);

   function Kind_Of (Item : Menu; Row : Positive) return Row_Kind
     with Pre => Row <= Row_Count (Item);

   function Text_Of (Item : Menu; Row : Positive) return String
     with Pre => Row <= Row_Count (Item);

   function Is_Checked (Item : Menu; Row : Positive) return Boolean
     with Pre => Row <= Row_Count (Item);

   function Height_For (Item : Menu) return Float;
   --  In points: of its rows, its padding and outline, and its shadow;
   --  what it would be if it were not held to a Max_Height.

   procedure Set_Max_Height (Item : in out Menu; Points : Float)
     with Pre => Points >= 0.0;
   --  Hold the menu to no more than Points of height (0.0 for no limit):
   --  if its rows are more, it is as tall as that, and they are scrolled
   --  by the wheel, with a thin bar at its right.

   function Shown_Height (Item : Menu) return Float;
   --  In points: Height_For, or the Max_Height if that is less.

   procedure Reveal (Item : in out Menu; Row : Positive)
     with Pre => Row <= Row_Count (Item);
   --  Scroll to have the row in view, if it is not.

   function Is_Scrollable (Item : Menu) return Boolean;
   --  Whether there are more rows than it shows.

   function Hovered_Row (Item : Menu) return Natural;
   --  The row that can be clicked under the pointer; 0 if none.

   procedure Take_Choice (Item : in out Menu; Chosen : out Natural);
   --  The row clicked since this was last called, 0 if none, and forget
   --  it.

   overriding procedure Handle
     (Item    : in out Menu;
      Event   : SDL3.Events.Event;
      Handled : out Boolean);

   overriding procedure Draw
     (Item   : in out Menu;
      Target : SDL3.Painters.Painter'Class;
      Colors : Themes.Theme);

   overriding procedure Hover_Changed
     (Item : in out Menu; Hovered : Boolean);

   overriding function Cursor (Item : Menu) return SDL3.Cursors.Kind;

   overriding procedure Describe
     (Item  : Menu;
      Facts : in out Semantics.Description);

   overriding function Part_Count (Item : Menu) return Natural;

   overriding procedure Describe_Part
     (Item   : Menu;
      Part   : Positive;
      Facts  : in out Semantics.Description;
      Bounds : out Semantics.Rectangle);

   overriding procedure Perform_Part
     (Item    : in out Menu;
      Part    : Positive;
      Request : Semantics.Request;
      Done    : out Boolean);

private

   type Line is record
      Kind     : Row_Kind := Note;
      Text     : String (1 .. Text_Capacity) := [others => ' '];
      Length   : Natural range 0 .. Text_Capacity := 0;
      Shade    : Tone := Plain;
      Checked  : Boolean := False;
      Enabled  : Boolean := True;
      Iconed   : Boolean := False;
      Which    : Pomarine.Icons.Icon := Pomarine.Icons.Icon'First;
      Swatched : Boolean := False;
      Swatch   : Themes.Slot := Themes.Primary;
   end record;

   package Line_Vectors is new Ada.Containers.Vectors (Positive, Line);

   type Menu is new Widget with record
      Rows    : Line_Vectors.Vector;
      Used    : Natural := 0;
      --  How many of Rows are there.
      Over    : Natural := 0;
      --  The row that can be clicked under the pointer.
      Pressed : Natural := 0;
      Chosen  : Natural := 0;
      Max_High : Float := 0.0;
      --  The most height, in points; 0.0 for none.
      Scrolled : Float := 0.0;
      --  How far the rows are scrolled up, in pixels.
      Faced    : Boolean := False;
   end record;

end Pomarine.Widgets.Menus;
