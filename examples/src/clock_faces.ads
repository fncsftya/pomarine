with Pomarine.Events;
with Pomarine.Semantics;
with Pomarine.Themes;
with Pomarine.Widgets;
with SDL3.Painters;

--  An analogue clock, drawn by hand: a widget of the application's own, which
--  paints its face, ticks, numerals and hands with the painter's lines and
--  discs, in the theme's colours, so that it follows light and dark. It
--  shows the local time, and asks the tree to wake it often enough for the
--  second hand to sweep.

package Clock_Faces is

   type Face is new Pomarine.Widgets.Widget with private;

   function Hours (Item : Face) return Natural;
   function Minutes (Item : Face) return Natural;
   function Seconds (Item : Face) return Natural;
   --  The time it shows, as of the last Update.

   procedure Set_Time (Item : in out Face; Hour, Minute, Second : Natural; Fraction : Float := 0.0)
   with Pre => Hour < 24 and then Minute < 60 and then Second < 60 and then Fraction in 0.0 .. 1.0;
   --  Show this time, a fraction of a second after it, in place of the
   --  clock's: for a test. Update puts the clock's back.

   overriding
   procedure Draw (Item : in out Face; Target : SDL3.Painters.Painter'Class; Colors : Pomarine.Themes.Theme);

   overriding
   procedure Update (Item : in out Face; Now : Pomarine.Events.Milliseconds);

   overriding
   function Until_Update (Item : Face) return Integer;

   overriding
   procedure Describe (Item : Face; Facts : in out Pomarine.Semantics.Description);

private

   type Face is new Pomarine.Widgets.Widget with record
      Hour, Minute, Second : Natural := 0;
      Fraction             : Float := 0.0;
      --  Of the second, so that the hands move smoothly.
   end record;

end Clock_Faces;
