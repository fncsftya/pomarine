with Pomarine.Marks.Drawing;

package body Pomarine.Mark_Paths is

   procedure Append (Item : in out Path; X, Y : Float) is
   begin
      if Item.Count > 0 and then Item.Points (Item.Count) = Point'(X, Y) then
         return;
      end if;
      if Item.Count = Max_Points then
         declare
            Remove : Positive := 2;
            Least : Float := Float'Last;
         begin
            --  Discard the interior point closest to its neighbours' segment.
            --  This retains corners and both ends without allocating more storage.
            for Index in 2 .. Max_Points - 1 loop
               declare
                  A : Point renames Item.Points (Index - 1);
                  B : Point renames Item.Points (Index + 1);
                  P : Point renames Item.Points (Index);
                  DX : constant Float := B.X - A.X;
                  DY : constant Float := B.Y - A.Y;
                  Length : constant Float := DX * DX + DY * DY;
                  T : constant Float :=
                    (if Length = 0.0 then 0.0 else
                     Float'Max (0.0, Float'Min (1.0, ((P.X - A.X) * DX + (P.Y - A.Y) * DY) / Length)));
                  Error : constant Float := (P.X - A.X - T * DX) ** 2 + (P.Y - A.Y - T * DY) ** 2;
               begin
                  if Error < Least then
                     Least := Error;
                     Remove := Index;
                  end if;
               end;
            end loop;
            Item.Points (Remove .. Max_Points - 1) := Item.Points (Remove + 1 .. Max_Points);
            Item.Count := Item.Count - 1;
         end;
      end if;
      Item.Count := Item.Count + 1;
      Item.Points (Item.Count) := (X, Y);
   end Append;

   function Contains (Item : Path; X, Y, Wide, High, Radius : Float) return Boolean is
   begin
      for Index in 2 .. Item.Count loop
         declare
            A : Point renames Item.Points (Index - 1);
            B : Point renames Item.Points (Index);
            DX : constant Float := (B.X - A.X) * Wide;
            DY : constant Float := (B.Y - A.Y) * High;
            Length : constant Float := DX * DX + DY * DY;
            T : constant Float :=
              (if Length = 0.0 then 0.0 else
               Float'Max (0.0, Float'Min (1.0, ((X - A.X * Wide) * DX + (Y - A.Y * High) * DY) / Length)));
         begin
            if (X - A.X * Wide - T * DX) ** 2 + (Y - A.Y * High - T * DY) ** 2 <= Radius ** 2 then
               return True;
            end if;
         end;
      end loop;
      return False;
   end Contains;

   procedure Draw
     (Item : Path; Target : SDL3.Painters.Painter'Class;
      Color : SDL3.Painters.Color; Blend : SDL3.Painters.Blends;
      Left, Top, Wide, High, Radius : Float)
   is
   begin
      Marks.Drawing.Draw
        ([(Trace => Item, others => <>)], 1, Target, Color, Blend, Left, Top, Wide, High, Radius);
   end Draw;
end Pomarine.Mark_Paths;
