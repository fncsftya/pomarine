with Pomarine.Semantics;
with SDL3.Painters;
with SDL3.Cursors;
with Pomarine_Ui_Config;
with SDL3.Events;
with Pomarine.Icons;

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
--  Pomarine.Widgets.Listener) as a Click, and keeps for Take_Click. It does not take the
--  focus, unless it is made to (Set_Focusable), so that clicking it does
--  not take it from what is being typed into; with the focus, it has a
--  ring in the theme's focus colour, and Return or Space clicks it.
package Pomarine.Widgets.Buttons is

   Label_Capacity : constant := Pomarine_Ui_Config.Button_Label;
   --  Characters of label.

   type Button is new Widget with private;

   type Kind is (Normal, Primary, Danger, Quiet, AI, Warning);
   --  Warning uses amber for something that needs attention.
   --  Normal has the theme's face, grey, for most things; Primary is in
   --  the theme's primary colour, green, for the main action; Danger in
   --  its danger colour, red, for what cannot be undone. Quiet has no
   --  face, only its icon and label, in a light ink, for a dark bar. AI is
   --  purple, for what a language model will do.

   procedure Set_Kind (Item : in out Button; To : Kind);

   function Kind_Of (Item : Button) return Kind;

   procedure Set_Label (Item : in out Button; Text : String)
     with Pre => Text'Length <= Label_Capacity;
   --  Show Text, in the debug font of SDL3.Windows.Renderers, scaled to
   --  the density, in the middle.

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

   procedure Set_Dropdown (Item : in out Button; To : Boolean);
   --  Show a caret at its right, in a part of its own, a line between it
   --  and the label: as of a button that opens a menu.

   function Is_Dropdown (Item : Button) return Boolean;

   procedure Set_Split (Item : in out Button; To : Boolean);
   --  Of a dropdown, make its caret a button of its own: the two parts are
   --  under the pointer, pressed and clicked each on its own. Both say
   --  Click; Caret_Clicked tells which it was.

   function Is_Split (Item : Button) return Boolean;

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

   procedure Take_Click (Item : in out Button; Clicked : out Boolean);
   --  Say whether it has been clicked since this was last called, and
   --  forget it.

   function Is_Pressed (Item : Button) return Boolean;
   --  Whether the button is down, and over it.

   overriding procedure Handle
     (Item    : in out Button;
      Event   : SDL3.Events.Event;
      Handled : out Boolean);

   overriding procedure Draw
     (Item   : in out Button;
      Target : SDL3.Painters.Painter'Class;
      Colors : Themes.Theme);

   overriding procedure Hover_Changed
     (Item : in out Button; Hovered : Boolean);

   overriding function Cursor (Item : Button) return SDL3.Cursors.Kind;

   overriding function Accepts_Focus (Item : Button) return Boolean;

   overriding function Focus_On_Click (Item : Button) return Boolean is (False);
   --  Tab reaches it (if it is focusable), but a click does not move the focus.

   overriding procedure Focus_Changed
     (Item : in out Button; Focused : Boolean);

   overriding procedure Describe
     (Item  : Button;
      Facts : in out Semantics.Description);
   overriding procedure Perform
     (Item    : in out Button;
      Request : Semantics.Request;
      Done    : out Boolean);

   overriding procedure Command_State_Changed
     (Item : in out Button; State : Command_State);

private

   type Button is new Widget with record
      Text    : String (1 .. Label_Capacity) := [others => ' '];
      Length  : Natural range 0 .. Label_Capacity := 0;
      Style   : Kind := Normal;
      Picture : Boolean := False;
      Which   : Pomarine.Icons.Icon := Pomarine.Icons.Icon'First;
      Icon_Points : Float := 0.0;  --  0.0: the usual size
      Swatched : Boolean := False;
      Swatch   : Themes.Slot := Themes.Primary;
      Captioned : Boolean := False;
      Badge     : Natural := 0;
      Selected  : Boolean := False;
      Dropdown  : Boolean := False;
      Enabled   : Boolean := True;
      Focusable : Boolean := False;
      Down    : Boolean := False;  --  pressed, and not yet let go
      Clicked : Boolean := False;
      By_Command : Boolean := False;  --  selected as a command in force
      Split      : Boolean := False;  --  the caret of a dropdown is a button of its own
      Over_Caret : Boolean := False;  --  the pointer is over it
      Down_Caret : Boolean := False;  --  the press was on it
      Last_Caret : Boolean := False;  --  the last click was on it
   end record;

end Pomarine.Widgets.Buttons;
