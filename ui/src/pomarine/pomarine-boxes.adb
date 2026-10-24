package body Pomarine.Boxes is

   use all type SDL3.Painters.Painter;

   Dash : constant Float := 4.0;
   Gap  : constant Float := 3.0;
   --  In points, of a dashed outline.

   --  The corners, in whole pixels, each as the coverage of its pixels

   subtype Alpha is Natural range 0 .. 255;

   Max_Radius : constant := 16;
   --  Of a corner, in pixels: a larger one is drawn with this.

   Samples : constant := 8;
   --  Along a side of a pixel, to find how much of it a corner covers.

   type Corner_Table is array (0 .. Max_Radius - 1, 0 .. Max_Radius - 1) of Alpha;

   Tables : array (1 .. Max_Radius) of Corner_Table;
   Ready  : array (1 .. Max_Radius) of Boolean := [others => False];
   --  Made when first wanted. Only the thread that draws uses them.

   procedure Make (Radius : Positive) is
      Whole : constant Float := Float (Radius);
   begin
      for Row in 0 .. Radius - 1 loop
         for Col in 0 .. Radius - 1 loop
            declare
               In_Circle : Natural := 0;
            begin
               for Down in 0 .. Samples - 1 loop
                  for Across in 0 .. Samples - 1 loop
                     declare
                        X : constant Float := Float (Col) + (Float (Across) + 0.5) / Float (Samples);
                        Y : constant Float := Float (Row) + (Float (Down) + 0.5) / Float (Samples);
                     begin
                        if (X - Whole) ** 2 + (Y - Whole) ** 2 <= Whole * Whole then
                           In_Circle := In_Circle + 1;
                        end if;
                     end;
                  end loop;
               end loop;
               Tables (Radius) (Row, Col) := In_Circle * 255 / (Samples * Samples);
            end;
         end loop;
      end loop;
      Ready (Radius) := True;
   end Make;

   function Cover (Radius, Row, Col : Natural) return Alpha is
   begin
      if Row >= Radius or else Col >= Radius then
         return 255;
      end if;
      if not Ready (Radius) then
         Make (Radius);
      end if;
      return Tables (Radius) (Row, Col);
   end Cover;
   --  How much of the pixel at Row and Col of a corner of Radius (from 0
   --  at the point of the box) is in the circle: 255 if all of it.

   function Cut (Radius, Row : Natural) return Natural is
   begin
      for Col in 0 .. Radius - 1 loop
         if Cover (Radius, Row, Col) = 255 then
            return Col;
         end if;
      end loop;
      return Radius;
   end Cut;
   --  How many pixels at the side of the Row (0 at the edge) a corner of
   --  Radius does not wholly cover.

   type Radii is record
      Top_Left, Top_Right, Bottom_Right, Bottom_Left : Natural := 0;
   end record;

   function Radii_Of
     (Radius : Float; Width, Height : Float; Round : Corner_Flags) return Radii
   is
      Most  : constant Float := Float'Floor (Float'Min (Width, Height) / 2.0);
      Whole : constant Natural :=
        Natural (Float'Max (0.0, Float'Min (Float'Min (Float'Floor (Radius), Most), Float (Max_Radius))));
   begin
      return
        (Top_Left     => (if Round.Top_Left then Whole else 0),
         Top_Right    => (if Round.Top_Right then Whole else 0),
         Bottom_Right => (if Round.Bottom_Right then Whole else 0),
         Bottom_Left  => (if Round.Bottom_Left then Whole else 0));
   end Radii_Of;

   function Less (Radius, By : Natural) return Natural is
     (if Radius > By then Radius - By else 0);

   function Row_Top (Top, Height : Float; Row, Rows : Natural) return Float is
     (if Row < Rows / 2 then Top + Float (Row) else Top + Height - Float (Rows - Row));
   --  Where a row of the box is: the top rows from its top, the others
   --  from its foot, so a box not a whole number of pixels high is as
   --  high as it is.

   function Side_Alpha (Above, Below : Natural; Row, Rows, Col : Integer) return Alpha is
     (if Row < 0 or else Row >= Rows or else Col < 0 then 0
      elsif Row < Above then Cover (Above, Row, Col)
      elsif Rows - 1 - Row < Below then Cover (Below, Rows - 1 - Row, Col)
      else 255);
   --  Of the pixel at Col from a side, in a Row of a box of Rows, whose
   --  corners at that side are Above and Below.

   function Side_Radius (Above, Below : Natural; Row, Rows : Integer) return Natural is
     (if Row < 0 or else Row >= Rows then 0
      elsif Row < Above then Above
      elsif Rows - 1 - Row < Below then Below
      else 0);

   Max_Spans : constant := 160;

   type Columns is array (1 .. Max_Spans) of Integer;
   type Alphas is array (1 .. Max_Spans) of Alpha;

   type Span_List is record
      Count : Natural := 0;
      Start : Columns := [others => 0];  --  the column
      Wide  : Columns := [others => 0];
      Light : Alphas := [others => 0];
      Shade : Alphas := [others => 255];  --  of a bevel: how much of the light colour
   end record;
   --  The runs of a row that are not clear: where and how much of the ink.

   function Same (Left, Right : Span_List) return Boolean is
     (Left.Count = Right.Count
      and then (for all I in 1 .. Left.Count =>
                  Left.Start (I) = Right.Start (I) and then Left.Wide (I) = Right.Wide (I)
                  and then Left.Light (I) = Right.Light (I) and then Left.Shade (I) = Right.Shade (I)));

   Far : constant := 2 ** 28;
   --  A box is no more than this many pixels across: a larger one (or one
   --  that is not a number) is drawn as if it were this, which is more than
   --  any target shows, and its middle is one block however many rows.

   function Whole_Pixels (Size : Float) return Natural
   with Post => Whole_Pixels'Result <= Far;
   --  The pixels that a Size covers whole, from none to Far.

   function Whole_Pixels (Size : Float) return Natural is
     (if Size /= Size or else Size < 1.0 then 0
      elsif Size >= Float (Far) then Far
      else Natural (Float'Floor (Size)));

   procedure Paint
     (Target  : SDL3.Painters.Painter'Class;
      Ink     : Themes.Color;
      Left, Top, Width, Height : Float;
      Thick   : Natural;
      Rd      : Radii;
      Over : Rings; Corners_Only, Under_Ring : Boolean;
      Dark : Themes.Color := (0, 0, 0, 255);
      Soft : Natural := 0)
   is
      --  The box if Thick is 0, else a ring Thick wide in it: the box
      --  less a box Thick in from its sides, with its corners Thick less
      --  round. Every pixel is inked as much as the shape covers it, so
      --  that the edge is smooth, as wide at a corner as at a side. A ring
      --  over a fill takes it into account, so that the fill does not show
      --  at the rim: what is left of the pixel is the fill, none of what is
      --  behind it.
      Wide    : constant Natural := Whole_Pixels (Width);
      Rows    : constant Natural := Whole_Pixels (Height);
      Inner   : constant Radii :=
        (Less (Rd.Top_Left, Thick), Less (Rd.Top_Right, Thick),
         Less (Rd.Bottom_Right, Thick), Less (Rd.Bottom_Left, Thick));
      In_Wide : constant Integer := Wide - 2 * Thick;
      In_Rows : constant Integer := Rows - 2 * Thick;
      Above   : constant Natural :=
        Natural'Max (Natural'Max (Rd.Top_Left, Rd.Top_Right),
                     (if Thick = 0 then 0
                      else Thick + Natural'Max (Inner.Top_Left, Inner.Top_Right)));
      Below   : constant Natural :=
        Natural'Max (Natural'Max (Rd.Bottom_Left, Rd.Bottom_Right),
                     (if Thick = 0 then 0
                      else Thick + Natural'Max (Inner.Bottom_Left, Inner.Bottom_Right)));

      Pending       : Boolean := False;
      Kept, Now     : Span_List;
      Place, Count  : Float := 0.0;
      --  Where the row held is, and how high.

      function X_Of (Col : Integer) return Float is
        (if Col < Wide / 2 then Left + Float (Col) else Left + Width - Float (Wide - Col));

      function In_Corner (Col, Row : Integer) return Boolean is
        ((Col < Rd.Top_Left and then Row < Rd.Top_Left)
         or else (Col >= Wide - Rd.Top_Right and then Row < Rd.Top_Right)
         or else (Col >= Wide - Rd.Bottom_Right and then Rows - 1 - Row < Rd.Bottom_Right)
         or else (Col < Rd.Bottom_Left and then Rows - 1 - Row < Rd.Bottom_Left));

      function Outer (Col, Row : Integer) return Alpha is
        (Natural'Min
           (Side_Alpha (Rd.Top_Left, Rd.Bottom_Left, Row, Rows, Col),
            Side_Alpha (Rd.Top_Right, Rd.Bottom_Right, Row, Rows, Wide - 1 - Col)));

      function Inside (Col, Row : Integer) return Alpha is
        (if Col < Thick or else Col >= Wide - Thick then 0
         else Natural'Min
           (Side_Alpha (Inner.Top_Left, Inner.Bottom_Left, Row - Thick, In_Rows, Col - Thick),
            Side_Alpha (Inner.Top_Right, Inner.Bottom_Right, Row - Thick, In_Rows,
                        In_Wide - 1 - (Col - Thick)))
           * Boolean'Pos (In_Wide > 0));

      function Light (Col, Row : Integer) return Alpha is
         Out_Cover : constant Alpha := Outer (Col, Row);
         Ring : Natural;
      begin
         if Corners_Only and then not In_Corner (Col, Row) then
            return 0;
         elsif Thick = 0 then
            return Out_Cover;
         elsif Under_Ring then
            --  The fill, the ring's: whole inside it, and none of the rim.
            return (if Out_Cover = 255 then 255 else Natural'Min (Out_Cover, Inside (Col, Row)));
         end if;
         Ring := Out_Cover - Natural'Min (Out_Cover, Inside (Col, Row));
         case Over is
            when Alone =>
               return Ring;
            when Over_Content =>
               return (if Out_Cover = 255 then Ring else 0);
         end case;
      end Light;

      function Shade (Col, Row : Integer) return Alpha is
         Near_Light : constant Integer := Integer'Min (Row, Col);
         Near_Dark  : constant Integer := Integer'Min (Rows - 1 - Row, Wide - 1 - Col);
         Mid        : constant Float :=
           0.5 + Float (Near_Dark - Near_Light) / (2.0 * Float'Max (2.0, Float (Soft)));
      begin
         return Alpha (Float'Rounding (255.0 * Float'Max (0.0, Float'Min (1.0, Mid))));
      end Shade;
      --  Of a bevel: light where it is nearer the top and the left, dark
      --  where it is nearer the foot and the right, and between at the
      --  corners where they meet, a step at a time.

      procedure Add (Into : in out Span_List; Col, Cols : Natural; Value : Alpha; Row : Integer) is
         Tone : constant Alpha := (if Soft = 0 or else Value = 0 then 255 else Shade (Col, Row));
      begin
         if Cols = 0 or else Value = 0 then
            return;
         end if;
         if Into.Count > 0 and then Into.Light (Into.Count) = Value
           and then Into.Shade (Into.Count) = Tone
           and then Into.Start (Into.Count) + Into.Wide (Into.Count) = Col
         then
            Into.Wide (Into.Count) := Into.Wide (Into.Count) + Cols;
            return;
         end if;
         pragma Assert (Into.Count < Max_Spans);
         Into.Count := Into.Count + 1;
         Into.Start (Into.Count) := Col;
         Into.Wide (Into.Count) := Cols;
         Into.Light (Into.Count) := Value;
         Into.Shade (Into.Count) := Tone;
      end Add;

      procedure Flush is
      begin
         if Pending then
            for I in 1 .. Kept.Count loop
               declare
                  From : constant Float := X_Of (Kept.Start (I));
                  Base : constant Themes.Color :=
                    (if Soft = 0 or else Kept.Shade (I) = 255 then Ink
                     else Themes.Mix (Dark, Ink, Float (Kept.Shade (I)) / 255.0));
                  Ink_Here : constant Themes.Color :=
                    (if Kept.Light (I) = 255 then Base
                     else (Base with delta Alpha =>
                             SDL3.Painters.Renderers.Color_Component (Natural (Base.Alpha) * Kept.Light (I) / 255)));
               begin
                  Fill_Rect
                    (Target, Ink_Here, From, Place,
                     X_Of (Kept.Start (I) + Kept.Wide (I)) - From, Count);
               end;
            end loop;
            Pending := False;
         end if;
      end Flush;

      procedure Put_Row (Y : Natural; At_Y, High : Float) is
         --  The row Y, at At_Y, High high: one row, or a block of the same.
         Reach_L : constant Natural :=
           Natural'Max
             (Natural'Max (Side_Radius (Rd.Top_Left, Rd.Bottom_Left, Y, Rows),
                           (if Thick = 0 then 0
                            else Thick + Side_Radius (Inner.Top_Left, Inner.Bottom_Left, Y - Thick, In_Rows))),
              Thick);
         Reach_R : constant Natural :=
           Natural'Max
             (Natural'Max (Side_Radius (Rd.Top_Right, Rd.Bottom_Right, Y, Rows),
                           (if Thick = 0 then 0
                            else Thick + Side_Radius (Inner.Top_Right, Inner.Bottom_Right, Y - Thick, In_Rows))),
              Thick);
         Whole : constant Boolean := Reach_L + Reach_R >= Wide;
         Zone_L : constant Natural := (if Whole then Wide else Reach_L);
         Zone_R : constant Natural := (if Whole then 0 else Reach_R);
      begin
         Now.Count := 0;
         for Col in 0 .. Zone_L - 1 loop
            Add (Now, Col, 1, Light (Col, Y), Y);
         end loop;
         if not Whole then
            Add (Now, Zone_L, Wide - Zone_L - Zone_R, Light (Zone_L, Y), Y);
         end if;
         for Col in Wide - Zone_R .. Wide - 1 loop
            Add (Now, Col, 1, Light (Col, Y), Y);
         end loop;
         if Pending and then Same (Now, Kept) then
            Count := Count + High;
            return;
         end if;
         Flush;
         Pending := True;
         Place := At_Y;
         Count := High;
         Kept := Now;
      end Put_Row;

      procedure Put_Row (Y : Natural) is
      begin
         Put_Row (Y, Row_Top (Top, Height, Y, Rows), 1.0);
      end Put_Row;
   begin
      if Wide = 0 or else Rows = 0 then
         return;
      end if;
      if Above + Below >= Rows then
         for Y in 0 .. Rows - 1 loop
            Put_Row (Y);
         end loop;
         Flush;
         return;
      end if;
      for Y in 0 .. Above - 1 loop
         Put_Row (Y);
      end loop;
      Flush;
      if not Corners_Only then
         --  The rows between, all the same.
         Put_Row (Above, Top + Float (Above), Height - Float (Above + Below));
         Flush;
      end if;
      for Y in Rows - Below .. Rows - 1 loop
         Put_Row (Y);
      end loop;
      Flush;
   end Paint;

   procedure Fill_Round
     (Target  : SDL3.Painters.Painter'Class;
      Ink     : Themes.Color;
      Left, Top, Width, Height : Float;
      Radius  : Float;
      Round   : Corner_Flags := All_Corners;
      Rim     : Float := 0.0)
   is
      Rd : constant Radii := Radii_Of (Radius, Width, Height, Round);
   begin
      if Rd.Top_Left + Rd.Top_Right + Rd.Bottom_Right + Rd.Bottom_Left = 0 then
         Fill_Rect (Target, Ink, Left, Top, Width, Height);
      else
         Paint (Target, Ink, Left, Top, Width, Height, Natural (Float'Floor (Rim)), Rd,
                Over => Alone, Corners_Only => False, Under_Ring => Rim >= 1.0);
      end if;
   end Fill_Round;

   procedure Outline
     (Target  : SDL3.Painters.Painter'Class;
      Ink     : Themes.Color;
      Left, Top, Width, Height : Float;
      Thick   : Float;
      Dashed  : Boolean := False;
      Density : Float := 1.0;
      Radius  : Float := 0.0;
      Round   : Corner_Flags := All_Corners;
      Over    : Rings := Alone)
   is
      Rd : constant Radii :=
        Radii_Of (Corner (Radius, Density), Width, Height, Round);
      Rounded : constant Boolean :=
        Rd.Top_Left + Rd.Top_Right + Rd.Bottom_Right + Rd.Bottom_Left > 0;
      Step  : constant Float := Float'Rounding ((Dash + Gap) * Density);
      Long  : constant Float := Float'Rounding (Dash * Density);

      procedure Across (Y : Float; From, To : Float) is
         Place : Float := From;
      begin
         if not Dashed then
            Fill_Rect (Target, Ink, Left + From, Y, To - From, Thick);
            return;
         end if;
         while Place < To loop
            Fill_Rect (Target, Ink, Left + Place, Y,
                       Float'Min (Long, To - Place), Thick);
            Place := Place + Step;
         end loop;
      end Across;

      procedure Down (X : Float; From, To : Float) is
         Place : Float := From;
      begin
         if not Dashed then
            Fill_Rect (Target, Ink, X, Top + From, Thick, To - From);
            return;
         end if;
         while Place < To loop
            Fill_Rect (Target, Ink, X, Top + Place, Thick,
                       Float'Min (Long, To - Place));
            Place := Place + Step;
         end loop;
      end Down;
   begin
      if not Rounded then
         Across (Top, 0.0, Width);
         Across (Top + Height - Thick, 0.0, Width);
         Down (Left, 0.0, Height);
         Down (Left + Width - Thick, 0.0, Height);
         return;
      end if;
      Paint (Target, Ink, Left, Top, Width, Height, Natural (Float'Floor (Thick)), Rd, Over,
             Corners_Only => Dashed, Under_Ring => False);
      if Dashed then
         --  Between the corners, which are whole.
         Across (Top, Float (Rd.Top_Left), Width - Float (Rd.Top_Right));
         Across (Top + Height - Thick, Float (Rd.Bottom_Left), Width - Float (Rd.Bottom_Right));
         Down (Left, Float (Rd.Top_Left), Height - Float (Rd.Bottom_Left));
         Down (Left + Width - Thick, Float (Rd.Top_Right), Height - Float (Rd.Bottom_Right));
      end if;
   end Outline;

   procedure Draw
     (Target  : SDL3.Painters.Painter'Class;
      Item    : Look;
      Left, Top, Width, Height : Float;
      Density : Float)
   is
      Off  : constant Float := Inset (Item, Density);
      Wide : constant Float := Width - Off;
      High : constant Float := Height - Off;
      Round : constant Float := Corner (Item.Radius, Density);
   begin
      if Item.Shadowed then
         Fill_Round (Target, Item.Shadow, Left + Off, Top + Off, Wide, High, Round, Item.Round);
      end if;
      if Item.Filled then
         Fill_Round (Target, Item.Fill, Left, Top, Wide, High, Round, Item.Round,
                     Rim => (if Item.Bordered then Edge (Density) else 0.0));
      end if;
      if Item.Bordered then
         Outline (Target, Item.Border, Left, Top, Wide, High, Edge (Density),
                  Item.Dashed, Density, Item.Radius, Item.Round);
      end if;
   end Draw;

   procedure Bevel
     (Target  : SDL3.Painters.Painter'Class;
      Light   : Themes.Color;
      Dark    : Themes.Color;
      Left, Top, Width, Height : Float;
      Density : Float;
      Sunken  : Boolean := False;
      Radius  : Float := 0.0;
      Round   : Corner_Flags := All_Corners)
   is
      Thick : constant Float := Edge (Density);
      Lit   : constant Themes.Color := (if Sunken then Dark else Light);
      Dim   : constant Themes.Color := (if Sunken then Light else Dark);
      Rd    : constant Radii := Radii_Of (Radius, Width, Height, Round);
      Curved : constant Boolean := Rd.Top_Left + Rd.Top_Right + Rd.Bottom_Right + Rd.Bottom_Left > 0;
      --  What each corner takes off the end of the edges that meet there.
      TL    : constant Float := Float (Cut (Rd.Top_Left, 0));
      TR    : constant Float := Float (Cut (Rd.Top_Right, 0));
      BR    : constant Float := Float (Cut (Rd.Bottom_Right, 0));
      BL    : constant Float := Float (Cut (Rd.Bottom_Left, 0));
   begin
      if Width < 2.0 * Thick or else Height < 2.0 * Thick then
         return;
      end if;
      if Curved then
         --  A ring, as the outline is, in the light at the top and left and
         --  the dark at the foot and right, turning from one to the other
         --  at the corners where they meet.
         Paint (Target, Lit, Left, Top, Width, Height, Natural (Float'Floor (Thick)), Rd,
                Over => Alone, Corners_Only => False, Under_Ring => False,
                Dark => Dim,
                Soft => Natural'Max (2, Natural'Max (Natural'Max (Rd.Top_Left, Rd.Top_Right),
                                                     Natural'Max (Rd.Bottom_Left, Rd.Bottom_Right))
                                        + Natural (Float'Floor (Thick))));
         return;
      end if;
      --  The foot and right over the ends of the top and left, as a
      --  light from the top left falls.
      Fill_Rect (Target, Lit, Left + TL, Top, Width - TL - TR, Thick);
      Fill_Rect (Target, Lit, Left, Top + TL, Thick, Height - TL - BL);
      Fill_Rect (Target, Dim, Left + BL, Top + Height - Thick, Width - BL - BR, Thick);
      Fill_Rect (Target, Dim, Left + Width - Thick, Top + TR, Thick, Height - TR - BR);
   end Bevel;

   procedure Draw_Control
     (Target  : SDL3.Painters.Painter'Class;
      Colors  : Themes.Theme;
      Fill    : Themes.Color;
      Edge_Color : Themes.Color;
      Edges   : Themes.Bevel_Colors;
      Left, Top, Width, Height : Float;
      Density : Float;
      Bevelled : Boolean := True;
      Sunken  : Boolean := False;
      Radius  : Float := 0.0;
      Round   : Corner_Flags := All_Corners)
   is
      Thick : constant Float := Edge (Density);
      Whole : constant Float := Corner (Radius, Density);
   begin
      Fill_Round (Target, Fill, Left, Top, Width, Height, Whole, Round, Rim => Thick);
      Outline (Target, Edge_Color, Left, Top, Width, Height, Thick,
               Density => Density, Radius => Radius, Round => Round, Over => Alone);
      if Bevelled and then Colors.Bevelled then
         Bevel (Target, Edges.Light, Edges.Dark, Left + Thick, Top + Thick,
                Width - 2.0 * Thick, Height - 2.0 * Thick, Density, Sunken,
                Radius => Float'Max (0.0, Whole - Thick), Round => Round);
      end if;
   end Draw_Control;

   procedure Draw_Flat
     (Target  : SDL3.Painters.Painter'Class;
      Fill    : Themes.Color;
      Edge_Color : Themes.Color;
      Left, Top, Width, Height : Float;
      Density : Float;
      Radius  : Float := 0.0;
      Round   : Corner_Flags := All_Corners)
   is
   begin
      Fill_Round (Target, Fill, Left, Top, Width, Height, Corner (Radius, Density), Round,
                  Rim => Edge (Density));
      Outline (Target, Edge_Color, Left, Top, Width, Height, Edge (Density),
               Density => Density, Radius => Radius, Round => Round, Over => Alone);
   end Draw_Flat;

end Pomarine.Boxes;
