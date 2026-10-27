with Ada.Containers.Vectors;
with Ada.Numerics.Elementary_Functions;

package body Pomarine.Marks.Drawing is
   use Ada.Numerics.Elementary_Functions;

   procedure Draw
     (Items                         : Mark_Array;
      Page                          : Positive;
      Target                        : SDL3.Painters.Painter'Class;
      Color                         : SDL3.Painters.Color;
      Blend                         : SDL3.Painters.Blends;
      Left, Top, Wide, High, Radius : Float)
   is
      type Interval is record
         Low, Upper : Float;
      end record;
      package Intervals is new Ada.Containers.Vectors (Positive, Interval);
      Spans                       : Intervals.Vector;
      Used                        : Natural := 0;
      Output_Width, Output_Height : Natural;

      function Before (A, B : Interval) return Boolean
      is (A.Low < B.Low);

      procedure Add (Low, Upper : Float) is
      begin
         pragma Assert (Low <= Upper);
         Spans.Append (Interval'(Low, Upper));
         Used := Used + 1;
      end Add;
      package Sorting is new Intervals.Generic_Sorting ("<" => Before);
   begin
      Target.Output_Size (Output_Width, Output_Height);
      if Output_Width = 0 or else Output_Height = 0 then
         return;
      end if;
      for Row in
        Integer'Max (0, Integer (Float'Floor (Top - Radius)))
        .. Integer'Min (Output_Height - 1, Integer (Float'Ceiling (Top + High + Radius)))
      loop
         declare
            Y : constant Float := Float (Row) + 0.5 - Top;
         begin
            Used := 0;
            Spans.Clear;
            for Each of Items loop
               if Each.Page = Page then
                  declare
                     Item : Mark_Paths.Path renames Each.Trace;
                  begin
                     if Item.Count = 0 then
                        if Y >= Each.Y * High - Radius and then Y < Each.Y * High + Radius then
                           Add (Each.Left * Wide, Each.Right * Wide);
                        end if;
                     elsif (for all P of Item.Points (1 .. Item.Count) => P.Y = Item.Points (1).Y) then
                        if Y >= Item.Points (1).Y * High - Radius and then Y < Item.Points (1).Y * High + Radius then
                           declare
                              Low   : Float := Item.Points (1).X;
                              Upper : Float := Low;
                           begin
                              for P of Item.Points (1 .. Item.Count) loop
                                 Low := Float'Min (Low, P.X);
                                 Upper := Float'Max (Upper, P.X);
                              end loop;
                              Add (Low * Wide, Upper * Wide);
                           end;
                        end if;
                     else
                        for P of Item.Points (1 .. Item.Count) loop
                           if abs (Y - P.Y * High) < Radius then
                              declare
                                 Reach : constant Float := Sqrt (Radius**2 - (Y - P.Y * High)**2);
                              begin
                                 Add (P.X * Wide - Reach, P.X * Wide + Reach);
                              end;
                           end if;
                        end loop;
                        for Index in 2 .. Item.Count loop
                           declare
                              A      : Mark_Paths.Point renames Item.Points (Index - 1);
                              B      : Mark_Paths.Point renames Item.Points (Index);
                              DX     : constant Float := (B.X - A.X) * Wide;
                              DY     : constant Float := (B.Y - A.Y) * High;
                              Length : constant Float := Sqrt (DX * DX + DY * DY);
                           begin
                              if Length > 0.0 then
                                 declare
                                    NX    : constant Float := -DY / Length * Radius;
                                    NY    : constant Float := DX / Length * Radius;
                                    type Vertex is record
                                       X, Y : Float;
                                    end record;
                                    Quad  : constant array (1 .. 4) of Vertex :=
                                      [(A.X * Wide + NX, A.Y * High + NY),
                                       (B.X * Wide + NX, B.Y * High + NY),
                                       (B.X * Wide - NX, B.Y * High - NY),
                                       (A.X * Wide - NX, A.Y * High - NY)];
                                    Low   : Float := Float'Last;
                                    Upper : Float := Float'First;
                                 begin
                                    for Edge in Quad'Range loop
                                       declare
                                          C : Vertex renames Quad (Edge);
                                          D : Vertex renames Quad (if Edge = 4 then 1 else Edge + 1);
                                       begin
                                          if C.Y /= D.Y
                                            and then Y >= Float'Min (C.Y, D.Y)
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
                     end if;
                  end;
               end if;
            end loop;
            Sorting.Sort (Spans);
            if Used > 0 then
               declare
                  Low   : Float := Spans (1).Low;
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
end Pomarine.Marks.Drawing;
