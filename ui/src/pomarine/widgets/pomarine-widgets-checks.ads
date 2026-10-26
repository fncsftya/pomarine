with Pomarine.Semantics;
with SDL3.Painters;
with Ada.Strings.Unbounded;
with SDL3.Cursors;
with Pomarine.Events;

--  A box to tick, or one of a set to choose among (a radio): a small white
--  square, outlined, with a label after it, and a square of
--  a colour between them if it is given one. A ticked box has a tick in
--  it; a chosen radio, a dark square. There are no round corners, so a
--  radio is square too.
--
--  A click on it (the box, or its label) is a change for the application
--  to take, as it takes a button's click: a box is ticked or not, the
--  other way; a radio is chosen, if it was not. What the application
--  makes of it, it says back with Set_Checked, as for the others of a set
--  of radios. Turned off (Set_Enabled), it is faint and takes nothing.
package Pomarine.Widgets.Checks is

   type Kind is (Box, Radio);

   type Check is new Widget with private;

   procedure Set_Kind (Item : in out Check; To : Kind);

   function Kind_Of (Item : Check) return Kind;

   procedure Set_Label (Item : in out Check; Text : String);

   function Label (Item : Check) return String;

   procedure Set_Checked (Item : in out Check; To : Boolean)
     with Post => Is_Checked (Item) = To;
   --  As the application's model has it. It is not a change to take.

   function Is_Checked (Item : Check) return Boolean;

   procedure Set_Swatch (Item : in out Check; To : Themes.Slot);
   --  Show a square of the colour between the box and the label.

   procedure Set_Enabled (Item : in out Check; To : Boolean);

   function Is_Enabled (Item : Check) return Boolean;

   Box_Size : constant Float := 14.0;
   --  In points, a side of the box.

   overriding procedure Handle
     (Item    : in out Check;
      Event   : Pomarine.Events.Event;
      Handled : out Boolean);

   overriding procedure Draw
     (Item   : in out Check;
      Target : SDL3.Painters.Painter'Class;
      Colors : Themes.Theme);

   overriding procedure Hover_Changed
     (Item : in out Check; Hovered : Boolean);

   overriding function Cursor (Item : Check) return SDL3.Cursors.Kind;

   overriding procedure Describe
     (Item  : Check;
      Facts : in out Semantics.Description);
   overriding procedure Perform
     (Item    : in out Check;
      Request : Semantics.Request;
      Done    : out Boolean);

   overriding procedure Command_State_Changed
     (Item : in out Check; State : Command_State);

   procedure Set_Focusable (Item : in out Check; To : Boolean);
   --  Let it take the focus, by a click or from the application, and then
   --  be operated from the keyboard, with a ring to show it has it. Not so
   --  to begin with, so that clicking it does not take the focus from what
   --  is being typed into.

   overriding function Is_Focusable (Item : Check) return Boolean;

   overriding function Focuses_On_Click (Item : Check) return Boolean is (False);
   --  Tab reaches it (if it is focusable), but a click does not move the focus.

   overriding procedure Focus_Changed
     (Item : in out Check; Focused : Boolean);

   overriding procedure Draw_Over
     (Item   : in out Check;
      Target : SDL3.Painters.Painter'Class;
      Colors : Themes.Theme);

private

   type Check is new Widget with record
      Form     : Kind := Box;
      Text : Ada.Strings.Unbounded.Unbounded_String;
      Checked  : Boolean := False;
      Swatched : Boolean := False;
      Swatch   : Themes.Slot := Themes.Primary;
      Enabled  : Boolean := True;
      Down     : Boolean := False;

      By_Command : Boolean := False;
      Focusable : Boolean := False;
   end record;

end Pomarine.Widgets.Checks;
