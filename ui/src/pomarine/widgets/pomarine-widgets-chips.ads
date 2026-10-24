with Pomarine.Semantics;
with SDL3.Painters;
with Ada.Strings.Unbounded;
with Pomarine.Events;

--  A chip: a small white box, outlined, that names a thing (a square of
--  its colour, if it is given one, and its name) and has a small button
--  at its right, standing up, a cross on it, to take the thing away. A
--  click on the cross is the application's to take, as a button's.
package Pomarine.Widgets.Chips is

   type Chip is new Widget with private;

   procedure Set_Label (Item : in out Chip; Text : String);

   function Label (Item : Chip) return String;

   procedure Set_Swatch (Item : in out Chip; To : Themes.Slot);
   --  Show a square of the colour before the label.

   overriding procedure Handle
     (Item    : in out Chip;
      Event   : Pomarine.Events.Event;
      Handled : out Boolean);

   overriding procedure Draw
     (Item   : in out Chip;
      Target : SDL3.Painters.Painter'Class;
      Colors : Themes.Theme);

   overriding procedure Hover_Changed
     (Item : in out Chip; Hovered : Boolean);

   overriding procedure Describe
     (Item  : Chip;
      Facts : in out Semantics.Description);

   overriding function Part_Count (Item : Chip) return Natural is (1);

   overriding procedure Describe_Part
     (Item   : Chip;
      Part   : Positive;
      Facts  : in out Semantics.Description;
      Bounds : out Semantics.Rectangle);

   overriding procedure Perform_Part
     (Item    : in out Chip;
      Part    : Positive;
      Request : Semantics.Request;
      Done    : out Boolean);

private

   type Chip is new Widget with record
      Text : Ada.Strings.Unbounded.Unbounded_String;
      Swatched : Boolean := False;
      Swatch   : Themes.Slot := Themes.Primary;
      Down     : Boolean := False;  --  pressed on the cross
      Over     : Boolean := False;  --  the pointer is over the cross

   end record;

end Pomarine.Widgets.Chips;
