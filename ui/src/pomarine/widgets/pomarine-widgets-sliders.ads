with Pomarine.Semantics;
with SDL3.Painters;
with SDL3.Cursors;
with Pomarine.Events;

--  A slider to drag: a track with a knob on it, whose place along the
--  track is a value from 0.0, at the left, to 1.0, at the right. The
--  track is a groove in what it is on; the knob is a flat control on it,
--  which has the colour of one pressed while it is held.
--
--  A press of the left button on it moves the knob to the pointer, and
--  starts a drag, which lasts until the button is let go, wherever the
--  pointer goes. The application takes the change, as it takes a
--  button's click.
package Pomarine.Widgets.Sliders is

   type Slider is new Widget with private;

   procedure Set_Value (Item : in out Slider; To : Float)
     with Pre  => To in 0.0 .. 1.0,
          Post => Is_Dragging (Item) or else Value (Item) = To;
   --  Put the knob there, as the application's model has it. It does not
   --  count as a change to take, and is ignored while the knob is held, which
   --  the pointer moves.

   function Value (Item : Slider) return Float
     with Post => Value'Result in 0.0 .. 1.0;

   procedure Take_Change (Item : in out Slider; Changed : out Boolean);
   --  Say whether the knob has been moved by the pointer since this was
   --  last called, and forget it.

   function Is_Dragging (Item : Slider) return Boolean;
   --  Whether the button is down from a press on it.

   overriding procedure Handle
     (Item    : in out Slider;
      Event   : Pomarine.Events.Event;
      Handled : out Boolean);

   overriding procedure Draw
     (Item   : in out Slider;
      Target : SDL3.Painters.Painter'Class;
      Colors : Themes.Theme);

   overriding procedure Hover_Changed
     (Item : in out Slider; Hovered : Boolean);

   overriding function Cursor (Item : Slider) return SDL3.Cursors.Kind;

   overriding procedure Describe
     (Item  : Slider;
      Facts : in out Semantics.Description);
   overriding procedure Perform
     (Item    : in out Slider;
      Request : Semantics.Request;
      Done    : out Boolean);

   procedure Set_Focusable (Item : in out Slider; To : Boolean);
   --  Let it take the focus, by a click or from the application, and then
   --  be operated from the keyboard, with a ring to show it has it. Not so
   --  to begin with, so that clicking it does not take the focus from what
   --  is being typed into.

   overriding function Accepts_Focus (Item : Slider) return Boolean;

   overriding procedure Focus_Changed
     (Item : in out Slider; Focused : Boolean);

   overriding procedure Draw_Over
     (Item   : in out Slider;
      Target : SDL3.Painters.Painter'Class;
      Colors : Themes.Theme);

private

   type Slider is new Widget with record
      Fraction : Float := 0.0;
      Held     : Boolean := False;
      Moved    : Boolean := False;
      Focusable : Boolean := False;
   end record;

end Pomarine.Widgets.Sliders;
