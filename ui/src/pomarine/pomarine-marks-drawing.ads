with SDL3.Painters;

package Pomarine.Marks.Drawing is
   procedure Draw
     (Items                         : Mark_Array;
      Page                          : Positive;
      Target                        : SDL3.Painters.Painter'Class;
      Color                         : SDL3.Painters.Color;
      Blend                         : SDL3.Painters.Blends;
      Left, Top, Wide, High, Radius : Float)
   with Pre => Wide > 0.0 and then High > 0.0 and then Radius > 0.0;
   --  Paint the union of all marks on a page, including the current gesture.
end Pomarine.Marks.Drawing;
