with Ada.Numerics.Elementary_Functions;

package body Pomarine.Mark_Paths is
   use Ada.Numerics.Elementary_Functions;

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
      type Interval is record
         Low, Upper : Float;
      end record;
      Spans : array (1 .. Max_Points * 3) of Interval;
      Used : Natural := 0;
      Output_Width, Output_Height : Natural;
      Low_Y : Float := High;
      High_Y : Float := 0.0;

      procedure Add (Low, Upper : Float) is
         At_Index : Positive := Used + 1;
      begin
         pragma Assert (Used < Spans'Length);
         while At_Index > 1 and then Spans (At_Index - 1).Low > Low loop
            Spans (At_Index) := Spans (At_Index - 1);
            At_Index := At_Index - 1;
         end loop;
         Spans (At_Index) := (Low, Upper);
         Used := Used + 1;
      end Add;
   begin
      if Item.Count < 2 then
         return;
      end if;
      --  Keep the original flat band for a horizontal swipe, and avoid
      --  rasterizing a straight line row by row.
      if (for all Index in 2 .. Item.Count => Item.Points (Index).Y = Item.Points (1).Y) then
         declare
            Low : Float := Item.Points (1).X;
            Upper : Float := Low;
         begin
            for P of Item.Points (2 .. Item.Count) loop
               Low := Float'Min (Low, P.X);
               Upper := Float'Max (Upper, P.X);
            end loop;
            Target.Fill_Rect
              (Color, Blend, Left + Low * Wide, Top + Item.Points (1).Y * High - Radius,
               (Upper - Low) * Wide, Radius * 2.0);
         end;
         return;
      end if;
      Target.Output_Size (Output_Width, Output_Height);
      if Output_Width = 0 or else Output_Height = 0 then
         return;
      end if;
      for P of Item.Points (1 .. Item.Count) loop
         Low_Y := Float'Min (Low_Y, P.Y * High - Radius);
         High_Y := Float'Max (High_Y, P.Y * High + Radius);
      end loop;
      for Row in Integer'Max (0, Integer (Float'Floor (Top + Low_Y)))
        .. Integer'Min (Output_Height - 1, Integer (Float'Ceiling (Top + High_Y)))
      loop
         declare
            Y : constant Float := Float (Row) + 0.5 - Top;
         begin
            Used := 0;
            for P of Item.Points (1 .. Item.Count) loop
               if abs (Y - P.Y * High) < Radius then
                  declare
                     Reach : constant Float := Sqrt (Radius ** 2 - (Y - P.Y * High) ** 2);
                  begin
                     Add (P.X * Wide - Reach, P.X * Wide + Reach);
                  end;
               end if;
            end loop;
            for Index in 2 .. Item.Count loop
               declare
                  A : Point renames Item.Points (Index - 1);
                  B : Point renames Item.Points (Index);
                  DX : constant Float := (B.X - A.X) * Wide;
                  DY : constant Float := (B.Y - A.Y) * High;
                  Length : constant Float := Sqrt (DX * DX + DY * DY);
               begin
                  if Length > 0.0 then
                     declare
                        NX : constant Float := -DY / Length * Radius;
                        NY : constant Float := DX / Length * Radius;
                        type Vertex is record
                           X, Y : Float;
                        end record;
                        Quad : constant array (1 .. 4) of Vertex :=
                          [(A.X * Wide + NX, A.Y * High + NY), (B.X * Wide + NX, B.Y * High + NY),
                           (B.X * Wide - NX, B.Y * High - NY), (A.X * Wide - NX, A.Y * High - NY)];
                        Low : Float := Float'Last;
                        Upper : Float := Float'First;
                     begin
                        for Edge in Quad'Range loop
                           declare
                              C : Vertex renames Quad (Edge);
                              D : Vertex renames Quad (if Edge = 4 then 1 else Edge + 1);
                           begin
                              if C.Y /= D.Y and then Y >= Float'Min (C.Y, D.Y)
                                and then Y < Float'Max (C.Y, D.Y)
                              then
                                 declare
                                    X : constant Float := C.X + (Y - C.Y) / (D.Y - C.Y) * (D.X - C.X);
                                 begin
                                    Low := Float'Min (Low, X);
                                    Upper := Float'Max (Upper, X);
                                 end;
                              end if;
                           end;
                        end loop;
                        if Low <= Upper then
                           Add (Low, Upper);
                        end if;
                     end;
                  end if;
               end;
            end loop;
            if Used > 0 then
               declare
                  Low : Float := Spans (1).Low;
                  Upper : Float := Spans (1).Upper;
               begin
                  for Index in 2 .. Used + 1 loop
                     if Index <= Used and then Spans (Index).Low <= Upper then
                        Upper := Float'Max (Upper, Spans (Index).Upper);
                     else
                        Target.Fill_Rect (Color, Blend, Left + Low, Float (Row), Upper - Low, 1.0);
                        if Index <= Used then
                           Low := Spans (Index).Low;
                           Upper := Spans (Index).Upper;
                        end if;
                     end if;
                  end loop;
               end;
            end if;
         end;
      end loop;
   end Draw;
end Pomarine.Mark_Paths;
