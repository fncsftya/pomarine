--  Fixed storage for a freehand stroke, in fractions of its picture or page.

package Pomarine.Mark_Paths is
   Max_Points : constant := 64;
   type Point is record
      X, Y : Float := 0.0;
   end record
   with Dynamic_Predicate => Point.X in 0.0 .. 1.0 and then Point.Y in 0.0 .. 1.0;
   type Point_Array is array (Positive range <>) of Point;
   type Path is record
      Count  : Natural range 0 .. Max_Points := 0;
      Points : Point_Array (1 .. Max_Points);
   end record;

   procedure Append (Item : in out Path; X, Y : Float)
   with Pre => X in 0.0 .. 1.0 and then Y in 0.0 .. 1.0, Post => Item.Count > 0;
   --  Simplify a full path before appending, keeping both ends and bounded storage.

   function Contains (Item : Path; X, Y, Wide, High, Radius : Float) return Boolean
   with Pre => Wide > 0.0 and then High > 0.0 and then Radius > 0.0;
   --  X and Y are pixels relative to the picture's origin.

end Pomarine.Mark_Paths;
