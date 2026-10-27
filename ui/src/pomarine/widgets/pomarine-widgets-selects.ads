with Pomarine.Semantics;
with SDL3.Painters;
with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with Pomarine.Widgets.Menus;
with SDL3.Cursors;
with Pomarine.Events;

--  A field to choose a value in, from a menu: white, outlined, as a field
--  to type in, with the value at the left and, at the right, a button
--  that is a flat control, a caret on it, as a dropdown's. Open
--  (Set_Open), the button has the colour of one pressed and the caret is
--  turned up.
--
--  Given choices (Add_Choice) it opens its own menu of them when it is clicked, as wide as it is, under it or over it
--  where there is room, and lets go of it when one is chosen, Escape is pressed, or a press is anywhere else (see
--  Pomarine.Widgets.Overlays). The one chosen becomes its value, and it says Change. Without choices, a click on it is
--  for the application to take, as a button's, and to show a menu of the values for (see Pomarine.Widgets.Menus); it
--  says the one chosen with Set_Value. Turned off (Set_Enabled), it is tinted and
--  faint, and takes nothing.

package Pomarine.Widgets.Selects is

   type Select_Field is new Widget with private;

   procedure Set_Value (Item : in out Select_Field; Text : String);

   function Value (Item : Select_Field) return String;

   procedure Add_Choice (Item : in out Select_Field; Text : String);
   --  One more for its menu, after the others.

   procedure Clear_Choices (Item : in out Select_Field);

   function Choice_Count (Item : Select_Field) return Natural;

   function Choice (Item : Select_Field; Index : Positive) return String
   with Pre => Index <= Choice_Count (Item);

   procedure Choose (Item : in out Select_Field; Index : Positive)
   with Pre => Index <= Choice_Count (Item), Post => Chosen (Item) = Index;
   --  Make a choice its value, as the person would, but saying nothing.

   function Chosen (Item : Select_Field) return Natural;
   --  Which choice is the value now (the first that is it); 0 if none is.

   procedure Set_Faced (Item : in out Select_Field; To : Boolean);
   --  Draw the value in the font it names, as of a select of fonts.

   procedure Set_Open (Item : in out Select_Field; To : Boolean);
   --  Show it as open, its menu shown, or not.

   function Is_Open (Item : Select_Field) return Boolean;

   procedure Set_Enabled (Item : in out Select_Field; To : Boolean);

   function Is_Enabled (Item : Select_Field) return Boolean;

   overriding
   procedure Handle (Item : in out Select_Field; Event : Pomarine.Events.Event; Handled : out Boolean);

   overriding
   procedure Draw (Item : in out Select_Field; Target : SDL3.Painters.Painter'Class; Colors : Themes.Theme);

   overriding
   procedure Hover_Changed (Item : in out Select_Field; Hovered : Boolean);

   overriding
   function Cursor (Item : Select_Field) return SDL3.Cursors.Kind;

   overriding
   procedure Describe (Item : Select_Field; Facts : in out Semantics.Description);
   overriding
   procedure Perform (Item : in out Select_Field; Request : Semantics.Request; Done : out Boolean);

   overriding
   procedure Command_State_Changed (Item : in out Select_Field; State : Command_State);

private

   package Choice_Vectors is new
     Ada.Containers.Vectors (Positive, Ada.Strings.Unbounded.Unbounded_String, Ada.Strings.Unbounded."=");

   type Select_Field is new Widget with record
      Text    : Ada.Strings.Unbounded.Unbounded_String;
      Choices : Choice_Vectors.Vector;
      Menu    : Menus.Menu;
      --  Its menu, added to the root of the tree when it is first opened.
      Open    : Boolean := False;
      Enabled : Boolean := True;
      Down    : Boolean := False;

      Faced : Boolean := False;
   end record;

end Pomarine.Widgets.Selects;
