with Pomarine.Semantics;
with SDL3.Painters;
with Pomarine_Ui_Config;
with SDL3.Cursors;
with Pomarine.Events;

--  A switch, on or off, with a label after it: a track, grey when off, in
--  the theme's primary colour when on, and a knob in it, at the left when
--  off and the right when on.
--
--  A click on it turns it over, a change for the application to take, as
--  it takes a button's click. Turned off (Set_Enabled), it is faint and
--  takes nothing.
package Pomarine.Widgets.Switches is

   Label_Capacity : constant := Pomarine_Ui_Config.Label_Capacity;
   --  Bytes of label.

   type Switch is new Widget with private;

   procedure Set_Label (Item : in out Switch; Text : String)
     with Pre => Text'Length <= Label_Capacity;

   function Label (Item : Switch) return String;

   procedure Set_On (Item : in out Switch; To : Boolean)
     with Post => Is_On (Item) = To;
   --  As the application's model has it. It is not a change to take.

   function Is_On (Item : Switch) return Boolean;

   procedure Set_Enabled (Item : in out Switch; To : Boolean);

   function Is_Enabled (Item : Switch) return Boolean;

   procedure Take_Change (Item : in out Switch; Changed : out Boolean);
   --  Say whether it has been turned over by a click since this was last
   --  called, and forget it.

   Track_Width  : constant Float := 32.0;
   Track_Height : constant Float := 16.0;
   --  In points.

   overriding procedure Handle
     (Item    : in out Switch;
      Event   : Pomarine.Events.Event;
      Handled : out Boolean);

   overriding procedure Draw
     (Item   : in out Switch;
      Target : SDL3.Painters.Painter'Class;
      Colors : Themes.Theme);

   overriding procedure Hover_Changed
     (Item : in out Switch; Hovered : Boolean);

   overriding function Cursor (Item : Switch) return SDL3.Cursors.Kind;

   overriding procedure Describe
     (Item  : Switch;
      Facts : in out Semantics.Description);
   overriding procedure Perform
     (Item    : in out Switch;
      Request : Semantics.Request;
      Done    : out Boolean);

   overriding procedure Command_State_Changed
     (Item : in out Switch; State : Command_State);

   procedure Set_Focusable (Item : in out Switch; To : Boolean);
   --  Let it take the focus, by a click or from the application, and then
   --  be operated from the keyboard, with a ring to show it has it. Not so
   --  to begin with, so that clicking it does not take the focus from what
   --  is being typed into.

   overriding function Accepts_Focus (Item : Switch) return Boolean;

   overriding function Focus_On_Click (Item : Switch) return Boolean is (False);
   --  Tab reaches it (if it is focusable), but a click does not move the focus.

   overriding procedure Focus_Changed
     (Item : in out Switch; Focused : Boolean);

   overriding procedure Draw_Over
     (Item   : in out Switch;
      Target : SDL3.Painters.Painter'Class;
      Colors : Themes.Theme);

private

   type Switch is new Widget with record
      Text    : String (1 .. Label_Capacity) := [others => ' '];
      Length  : Natural range 0 .. Label_Capacity := 0;
      On      : Boolean := False;
      Enabled : Boolean := True;
      Down    : Boolean := False;
      Changed : Boolean := False;
      By_Command : Boolean := False;
      Focusable : Boolean := False;
   end record;

end Pomarine.Widgets.Switches;
