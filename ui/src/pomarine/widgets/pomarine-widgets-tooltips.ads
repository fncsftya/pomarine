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

   procedure Install (Home : in out Tree; Tip : in out Tooltip; Delay_MS : Natural := 600)
   with Pre => Has_Root (Home) and then not Is_Attached (Tip), Post => Is_Attached (Tip);
   --  Have Home show Tip by itself: added to its root, hidden, and put beside any widget that has a tooltip
   --  (Widgets.Set_Tooltip) once the pointer has rested on it for Delay_MS milliseconds, below it or over it where
   --  there is room, and let go of when the pointer moves on, or a key, a press or a wheel turn comes.

   overriding
   procedure Draw (Item : in out Tooltip; Target : SDL3.Painters.Painter'Class; Colors : Themes.Theme);

   overriding
   procedure Describe (Item : Tooltip; Facts : in out Semantics.Description);

private

   type Tooltip is new Widget with record
      Content : Ada.Strings.Unbounded.Unbounded_String;
   end record;

end Pomarine.Widgets.Tooltips;
