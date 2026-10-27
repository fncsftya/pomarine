with Pomarine.Line_Texts;
with Pomarine.Semantics;
with SDL3.Painters;
with SDL3.Cursors;
with Ada.Strings.Unbounded;
with Pomarine.Events;
with Pomarine.Icons;
with Pomarine.Widgets.Layouts;

--  A button to click, with a short label.
--
--  It is a face, outlined and bevelled (see Pomarine.Boxes.Draw_Control), in the
--  colours its Kind has in the theme (see Pomarine.Themes.Tone): at rest,
--  under the pointer, and pressed. A toggle that is on (Set_Selected) stays
--  in the theme's accent. Turned off (Set_Enabled), it is faint, and takes
--  no events.
--
--  It is pressed by the left button over it, and clicked by that button
--  let go over it, which it says to the tree's listener (see
--  Pomarine.Widgets.Listener) as a Click. Tab reaches it, and with the
--  focus it has a ring in the theme's focus colour, and Return or Space
--  clicks it. A click does not move the focus to it, so that it does not
--  take it from what is being typed into. One that Tab should skip, such
--  as a toolbar button beside an editor, is made so (Set_Focusable).

package Pomarine.Widgets.Buttons is

   type Button is new Widget with private;

   type Kind is (Normal, Primary, Danger, Quiet, Warning);
   --  Warning uses amber for something that needs attention.
   --  Normal has the theme's face, grey, for most things; Primary is in
   --  the theme's primary colour, green, for the main action; Danger in
   --  its danger colour, red, for what cannot be undone. Quiet has no
   --  face, only its icon and label, in a light ink, for a dark bar.

   type Shape_Kind is (Plain, Dropdown, Split_Dropdown);
   --  Plain is a button. A Dropdown has a caret at its right, in a part of
   --  its own, a line between it and the label: as of a button that opens
   --  a menu. A Split_Dropdown has the caret a button of its own: the two
   --  parts are under the pointer, pressed and clicked each on its own.
   --  Both say Click; Caret_Clicked tells which it was.

   type Settings is private;
   --  What a button is, as against what it is now (Set_Selected,
   --  Set_Enabled, Set_Badge and Set_Swatch): its label and look, made
   --  with Looks, and given to Configure or to Add.

   function Looks
     (Caption     : String := "";
      Of_Kind     : Kind := Normal;
      Icon        : Pomarine.Icons.Optional := Pomarine.Icons.No_Icon;
      Icon_Points : Float := 0.0;
      Captioned   : Boolean := False;
      Shape       : Shape_Kind := Plain;
      Focusable   : Boolean := True;
      Label_Style : Line_Texts.Style := Line_Texts.Strong;
      Underlined  : Boolean := False;
      Struck      : Boolean := False) return Settings
   with Pre => Icon_Points >= 0.0;
   --  What is not named is what a new button has. Icon_Points is in points,
   --  0.0 the usual. Captioned shows the label after the icon.
   --     Looks ("Save", Primary)
   --     Looks ("Edit", Icon => Icons.Shown (Edit), Captioned => True)

   procedure Configure (Item : in out Button; Using : Settings);
   --  Make it as Using says, all of it: what Using does not name goes back
   --  to what a new button has. Whether it is selected, enabled, badged or
   --  swatched is left as it was. Damages nothing if it is as it was.

   procedure Add
     (Parent : in out Widget'Class; Item : in out Button; Using : Settings; Box : Layouts.Style := (others => <>))
   with Pre => Is_Attached (Parent) and then not Is_Attached (Item), Post => Is_Attached (Item);
   --  Add Item to Parent, as it looks and where it sits, in one line:
   --     Buttons.Add
   --       (Footer, Save, Buttons.Looks ("Save", Buttons.Primary), (Width => 70.0, Height => 32.0, others => <>));

   procedure Set_Kind (Item : in out Button; To : Kind);

   function Kind_Of (Item : Button) return Kind;

   procedure Set_Label (Item : in out Button; Text : String);
   --  Show Text, in the debug font of SDL3.Windows.Renderers, scaled to
   --  the density, in the middle.

   procedure Set_Label_Style (Item : in out Button; Using : Line_Texts.Style; Underlined, Struck : Boolean := False);
   --  Choose the label font and optional decorations.

   procedure Set_Icon (Item : in out Button; To : Pomarine.Icons.Icon);
   --  Show the icon, in the middle, in place of the label, if the tree has
   --  icons and the icon can be drawn; the label otherwise.

   procedure Set_Icon_Size (Item : in out Button; Points : Float)
   with Pre => Points > 0.0;
   --  Draw the icon Points a side, not the usual size.

   function Has_Icon (Item : Button) return Boolean;

   procedure Set_Swatch (Item : in out Button; To : Themes.Slot);
   --  Show a square of the colour, in the middle, as the button's icon.

   procedure Set_Badge (Item : in out Button; Count : Natural);
   --  Show Count in a dark square after the label, as how many there are
   --  of what it opens; none if 0.

   procedure Set_Captioned (Item : in out Button; To : Boolean);
   --  With an icon, show the label after it, in place of the icon alone.

   procedure Set_Selected (Item : in out Button; To : Boolean);
   --  Show it as pressed in, in the accent, as a toggle that is on, or
   --  the chosen one of a row of tabs; it still takes clicks. A dropdown
   --  so is open: pressed in, in its own face, its caret turned up.

   function Is_Selected (Item : Button) return Boolean;

   procedure Set_Shape (Item : in out Button; To : Shape_Kind);

   function Shape_Of (Item : Button) return Shape_Kind;

   procedure Set_Dropdown (Item : in out Button; To : Boolean)
   with Post => Is_Dropdown (Item) = To;
   --  Set_Shape (Dropdown) or (Plain). It makes a split dropdown plain.

   function Is_Dropdown (Item : Button) return Boolean;
   --  Whether it has a caret, split or not.

   function Caret_Clicked (Item : Button) return Boolean;
   --  Whether the last click, by the pointer, was on the caret of a split
   --  dropdown, not the rest of it.

   procedure Set_Enabled (Item : in out Button; To : Boolean);
   --  Turn it on, or off: off, it is flat and faint, cannot be pressed
   --  or clicked, and does not take the focus. It is on to begin with.

   function Is_Enabled (Item : Button) return Boolean;

   procedure Set_Focusable (Item : in out Button; To : Boolean);
   --  Let it take the focus, by a click or from the application.

   function Label (Item : Button) return String;

   function Is_Pressed (Item : Button) return Boolean;
   --  Whether the button is down, and over it.

   overriding
   procedure Handle (Item : in out Button; Event : Pomarine.Events.Event; Handled : out Boolean);

   overriding
   procedure Draw (Item : in out Button; Target : SDL3.Painters.Painter'Class; Colors : Themes.Theme);

   overriding
   procedure Hover_Changed (Item : in out Button; Hovered : Boolean);

   overriding
   function Cursor (Item : Button) return SDL3.Cursors.Kind;

   overriding
   function Is_Focusable (Item : Button) return Boolean;

   overriding
   function Focuses_On_Click (Item : Button) return Boolean
   is (False);
   --  Tab reaches it (if it is focusable), but a click does not move the focus.

   overriding
   procedure Focus_Changed (Item : in out Button; Focused : Boolean);

   overriding
   procedure Describe (Item : Button; Facts : in out Semantics.Description);
   overriding
   procedure Perform (Item : in out Button; Request : Semantics.Request; Done : out Boolean);

   overriding
   procedure Command_State_Changed (Item : in out Button; State : Command_State);

private

   type Settings is record
      Text        : Ada.Strings.Unbounded.Unbounded_String;
      Style       : Kind := Normal;
      Label_Style : Line_Texts.Style := Line_Texts.Strong;
      Underlined  : Boolean := False;
      Struck      : Boolean := False;
      Icon        : Pomarine.Icons.Optional := Pomarine.Icons.No_Icon;
      Icon_Points : Float := 0.0;
      Captioned   : Boolean := False;
      Shape       : Shape_Kind := Plain;
      Focusable   : Boolean := True;
   end record;

   type Button is new Widget with record
      Text        : Ada.Strings.Unbounded.Unbounded_String;
      Style       : Kind := Normal;
      Label_Style : Line_Texts.Style := Line_Texts.Strong;
      Underlined  : Boolean := False;
      Struck      : Boolean := False;
      Picture     : Boolean := False;
      Which       : Pomarine.Icons.Icon := Pomarine.Icons.Icon'First;
      Icon_Points : Float := 0.0;  --  0.0: the usual size
      Swatched    : Boolean := False;
      Swatch      : Themes.Slot := Themes.Primary;
      Captioned   : Boolean := False;
      Badge       : Natural := 0;
      Selected    : Boolean := False;
      Shape       : Shape_Kind := Plain;
      Enabled     : Boolean := True;
      Focusable   : Boolean := True;
      Down        : Boolean := False;  --  pressed, and not yet let go
      By_Command  : Boolean := False;  --  selected as a command in force
      Over_Caret  : Boolean := False;  --  the pointer is over it
      Down_Caret  : Boolean := False;  --  the press was on it
      Last_Caret  : Boolean := False;  --  the last click was on it
   end record;

end Pomarine.Widgets.Buttons;
