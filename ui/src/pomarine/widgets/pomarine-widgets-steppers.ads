with Ada.Strings.Unbounded;
with Pomarine.Events;
with Pomarine.Semantics;
with SDL3.Cursors;
with SDL3.Painters;

--  A whole number to step: its value in a white box with a minus and a plus at the right. A click on one, or Down and
--  Up (or Page Down and Page Up, ten steps) when it has the focus (Set_Focusable), takes a Step from the value, kept
--  within its range; it says Change when the person changes it, and nothing when the application does (Set_Value).
--  Held at its limits, the button for the way past them is off.
--
--     Steppers.Add (Panel, Copies, Min => 1, Max => 99, Start => 1);

package Pomarine.Widgets.Steppers is

   type Stepper is new Widget with private;

   procedure Add
     (Parent : in out Widget'Class;
      Item   : in out Stepper;
      Min    : Integer := 0;
      Max    : Integer := 100;
      Start  : Integer := 0)
   with
     Pre  =>
       Is_Attached (Parent)
       and then not Is_Attached (Item)
       and then Child_Count (Item) = 0
       and then Min <= Max
       and then Start in Min .. Max,
     Post => Is_Attached (Item);
   --  Add Item to Parent, 120 points wide and 32 high.

   procedure Set_Range (Item : in out Stepper; Min, Max : Integer)
   with Pre => Min <= Max, Post => Value (Item) in Min .. Max;
   --  The value is brought within it, saying nothing.

   function Minimum (Item : Stepper) return Integer;

   function Maximum (Item : Stepper) return Integer;

   procedure Set_Step (Item : in out Stepper; By : Positive);
   --  What a click adds or takes away; 1 to begin with.

   function Step (Item : Stepper) return Positive;

   procedure Set_Value (Item : in out Stepper; To : Integer)
   with Pre => To in Minimum (Item) .. Maximum (Item), Post => Value (Item) = To;

   function Value (Item : Stepper) return Integer
   with Post => Value'Result in Minimum (Item) .. Maximum (Item);

   procedure Set_Suffix (Item : in out Stepper; Text : String);
   --  Shown after the number: " pt", " %".

   procedure Set_Enabled (Item : in out Stepper; To : Boolean);

   function Is_Enabled (Item : Stepper) return Boolean;

   procedure Set_Focusable (Item : in out Stepper; To : Boolean);

   overriding
   function Is_Focusable (Item : Stepper) return Boolean;

   overriding
   function Focuses_On_Click (Item : Stepper) return Boolean
   is (False);

   overriding
   procedure Handle (Item : in out Stepper; Event : Pomarine.Events.Event; Handled : out Boolean);

   overriding
   procedure Draw (Item : in out Stepper; Target : SDL3.Painters.Painter'Class; Colors : Themes.Theme);

   overriding
   procedure Draw_Over (Item : in out Stepper; Target : SDL3.Painters.Painter'Class; Colors : Themes.Theme);

   overriding
   procedure Hover_Changed (Item : in out Stepper; Hovered : Boolean);

   overriding
   procedure Focus_Changed (Item : in out Stepper; Focused : Boolean);

   overriding
   function Cursor (Item : Stepper) return SDL3.Cursors.Kind;

   overriding
   procedure Describe (Item : Stepper; Facts : in out Semantics.Description);

   overriding
   procedure Perform (Item : in out Stepper; Request : Semantics.Request; Done : out Boolean);

private

   type Which_Button is (None, Minus, Plus);

   type Stepper is new Widget with record
      Low, High : Integer := 0;
      Current   : Integer := 0;
      By        : Positive := 1;
      Suffix    : Ada.Strings.Unbounded.Unbounded_String;
      Pressed   : Which_Button := None;
      Enabled   : Boolean := True;
      Focusable : Boolean := False;
   end record;

end Pomarine.Widgets.Steppers;
