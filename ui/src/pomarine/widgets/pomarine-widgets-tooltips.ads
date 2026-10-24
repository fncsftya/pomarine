with Pomarine.Semantics;
with SDL3.Painters;
with Ada.Strings.Unbounded;

--  A tooltip: a short name for what is under the pointer, white on the
--  dark bars' colour, in the middle of its box. The application shows it
--  (below the thing, not over it, so that the pointer is not taken from
--  that) and hides it; Natural_Width says how wide to make it. It takes
--  no events.
package Pomarine.Widgets.Tooltips is

   type Tooltip is new Widget with private;

   procedure Set_Text (Item : in out Tooltip; Value : String);

   function Text (Item : Tooltip) return String;

   function Natural_Width (Item : Tooltip) return Float
     with Pre => Is_Attached (Item);
   --  In points: of the text, and its padding.

   Height : constant Float := 22.0;
   --  In points, to make it.

   overriding procedure Draw
     (Item   : in out Tooltip;
      Target : SDL3.Painters.Painter'Class;
      Colors : Themes.Theme);

   overriding procedure Describe
     (Item  : Tooltip;
      Facts : in out Semantics.Description);

private

   type Tooltip is new Widget with record
      Content : Ada.Strings.Unbounded.Unbounded_String;
   end record;

end Pomarine.Widgets.Tooltips;
