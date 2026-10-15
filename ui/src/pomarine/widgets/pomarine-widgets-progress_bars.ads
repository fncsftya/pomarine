with Pomarine.Semantics;
with SDL3.Painters;

--  A bar that fills from the left as a job goes on: a track, and over it
--  the part done, from 0.0 to 1.0. It takes no events; the application
--  tells it how far on the job is.
package Pomarine.Widgets.Progress_Bars is

   type Progress_Bar is new Widget with private;

   procedure Set_Value (Item : in out Progress_Bar; To : Float)
     with Pre  => To in 0.0 .. 1.0,
          Post => Value (Item) = To;
   --  Fill that much of the bar.

   function Value (Item : Progress_Bar) return Float
     with Post => Value'Result in 0.0 .. 1.0;

   overriding procedure Draw
     (Item   : in out Progress_Bar;
      Target : SDL3.Painters.Painter'Class;
      Colors : Themes.Theme);

   overriding procedure Describe
     (Item  : Progress_Bar;
      Facts : in out Semantics.Description);

private

   type Progress_Bar is new Widget with record
      Fraction : Float := 0.0;
   end record;

end Pomarine.Widgets.Progress_Bars;
