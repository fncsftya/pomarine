with Pomarine.Semantics;
with SDL3.Painters;
with Ada.Strings.Unbounded;
with Pomarine.Events;

--  A toast: a short message that something has been done, on a white box,
--  outlined, casting a solid shadow, with a bar of the theme's primary
--  colour down its left, and, if it is given one, a small button at its
--  right to do something of it (as Undo). A click on the button is the
--  application's to take, as a button's. The application shows it, and
--  hides it when it has been shown long enough.
package Pomarine.Widgets.Toasts is

   type Toast is new Widget with private;

   procedure Set_Message (Item : in out Toast; Text : String);

   function Message (Item : Toast) return String;

   procedure Set_Action (Item : in out Toast; Label : String);
   --  The label of the button; none ("") to have no button.

   function Action (Item : Toast) return String;

   procedure Take_Action (Item : in out Toast; Clicked : out Boolean);
   --  Say whether the button has been clicked since this was last called,
   --  and forget it.

   Height : constant Float := 36.0;
   --  In points, to make it, with its shadow.

   overriding procedure Handle
     (Item    : in out Toast;
      Event   : Pomarine.Events.Event;
      Handled : out Boolean);

   overriding procedure Draw
     (Item   : in out Toast;
      Target : SDL3.Painters.Painter'Class;
      Colors : Themes.Theme);

   overriding procedure Hover_Changed
     (Item : in out Toast; Hovered : Boolean);

   overriding procedure Describe
     (Item  : Toast;
      Facts : in out Semantics.Description);

   overriding function Part_Count (Item : Toast) return Natural;

   overriding procedure Describe_Part
     (Item   : Toast;
      Part   : Positive;
      Facts  : in out Semantics.Description;
      Bounds : out Semantics.Rectangle);

   overriding procedure Perform_Part
     (Item    : in out Toast;
      Part    : Positive;
      Request : Semantics.Request;
      Done    : out Boolean);

private

   type Toast is new Widget with record
      Text : Ada.Strings.Unbounded.Unbounded_String;
      Label   : Ada.Strings.Unbounded.Unbounded_String;
      Over    : Boolean := False;  --  the pointer is over the button
      Down    : Boolean := False;  --  pressed on the button
      Clicked : Boolean := False;
   end record;

end Pomarine.Widgets.Toasts;
