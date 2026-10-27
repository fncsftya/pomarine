with Pomarine.Themes;
with Pomarine.Scrollbars;
with SDL3.Painters;

--  How a text area looks.
private package Pomarine.Text_Areas.Drawing is

   function Bar_Metrics (Item : Text_Area) return Scrollbars.Metrics;

   procedure Render
     (Item      : in out Text_Area;
      Target    : SDL3.Painters.Painter'Class;
      Colors    : Themes.Theme;
      Settled   : Boolean := True;
      Rows_From : Float := Float'First;
      Rows_To   : Float := Float'Last)
     with Pre => Is_Attached (Item);

end Pomarine.Text_Areas.Drawing;
