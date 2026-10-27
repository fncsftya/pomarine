private package Pomarine.Text_Areas.Moving is

   function Step
     (Item : in out Text_Area;
      From : Position;
      By   : Motion) return Position
     with Pre => By not in Previous_Line | Next_Line;
   --  Where the caret goes from From.

   function Line_Position
     (Item   : in out Text_Area;
      Para   : Positive;
      Number : Positive;
      X      : Float) return Position;
   --  The position on line Number of paragraph Para, laid out, nearest X
   --  layout units across.

   function Vertical_Step
     (Item : in out Text_Area;
      By   : Motion) return Position
     with Pre => By in Previous_Line | Next_Line;
   --  Where the caret goes a line up or down, as near the goal as can
   --  be.

   function Point_At (Item : in out Text_Area; X, Y : Float)
      return Position;
   --  The position nearest pixel X, Y.

end Pomarine.Text_Areas.Moving;
