with SDL3.Painters;
with Pomarine.Themes;

--  How a box is drawn: filled, with an outline a point wide, solid or
--  dashed, and a shadow cast down and to the right, solid and offset,
--  never blurred. Each is optional. The shadow is inside the box, so that
--  nothing is drawn outside it: the face is the box less the shadow's
--  offset at its right and foot, and what is in it is to be kept off that.
package Pomarine.Boxes is

   type Sides is (Top_Side, Right_Side, Bottom_Side, Left_Side);
   --  The edges of a box.

   type Spot is record
      X, Y : Float;
   end record;

   function Side_Midpoint
     (Left, Top, Width, Height : Float; Side : Sides) return Spot is
     (case Side is
         when Top_Side    => (Left + Width / 2.0, Top),
         when Right_Side  => (Left + Width, Top + Height / 2.0),
         when Bottom_Side => (Left + Width / 2.0, Top + Height),
         when Left_Side   => (Left, Top + Height / 2.0));
   --  The middle of the edge of the box.

   type Corner_Flags is record
      Top_Left     : Boolean := True;
      Top_Right    : Boolean := True;
      Bottom_Right : Boolean := True;
      Bottom_Left  : Boolean := True;
   end record;
   --  Which corners of a box are rounded, if it has a radius.

   All_Corners    : constant Corner_Flags := (others => True);
   Top_Corners    : constant Corner_Flags := (True, True, False, False);
   Bottom_Corners : constant Corner_Flags := (False, False, True, True);
   Left_Corners   : constant Corner_Flags := (True, False, False, True);
   Right_Corners  : constant Corner_Flags := (False, True, True, False);

   function Corner (Radius, Density : Float) return Float is
     (Float'Max (0.0, Float'Rounding (Radius * Density)));
   --  A radius in points, in whole pixels: it is cut from the pixels of
   --  the box, so that its edge is drawn on them, never between.

   type Look is record
      Filled   : Boolean := False;
      Fill     : Themes.Color := (0, 0, 0, 255);
      Bordered : Boolean := False;
      Border   : Themes.Color := (0, 0, 0, 255);
      Dashed   : Boolean := False;
      Shadowed : Boolean := False;
      Shadow   : Themes.Color := (0, 0, 0, 255);
      Radius   : Float := 0.0;  --  in points; none if 0
      Round    : Corner_Flags := All_Corners;
   end record;

   function Edge (Density : Float) return Float is
     (Float'Max (1.0, Float'Rounding (Density)));
   --  The width of an outline, in whole pixels: one that is not is a
   --  pixel more or less where it is drawn, or none.

   function Offset (Density : Float) return Float is
     (Float'Rounding (Themes.Shadow_Offset * Density));
   --  Of a shadow, in whole pixels.

   function Inset (Item : Look; Density : Float) return Float is
     (if Item.Shadowed then Offset (Density) else 0.0);
   --  What the shadow takes of the box at its right and its foot.

   procedure Draw
     (Target  : SDL3.Painters.Painter'Class;
      Item    : Look;
      Left, Top, Width, Height : Float;
      Density : Float)
     with Pre => Density > 0.0;
   --  In pixels from the top left of Target.

   type Rings is (Alone, Over_Content);
   --  What a ring is drawn over: a fill, or nothing in particular (what is
   --  behind shows through its smooth edges, which a fill leaves to it: see
   --  Fill_Round); or what is in the box, that it covers at its inner edge,
   --  leaving its outer edge as it is.

   procedure Fill_Round
     (Target  : SDL3.Painters.Painter'Class;
      Ink     : Themes.Color;
      Left, Top, Width, Height : Float;
      Radius  : Float;
      Round   : Corner_Flags := All_Corners;
      Rim     : Float := 0.0)
     with Pre => Radius >= 0.0 and then Rim >= 0.0;
   --  A box filled, its corners (those in Round) cut by a quarter of a
   --  circle Radius pixels across, a row of the box at a time: square if
   --  Radius is 0. The curve is smooth: a pixel it cuts is blended.
   --  If a ring Rim pixels wide is to be drawn over it (see Outline), the
   --  fill leaves the pixels at the outer edge to the ring, which blends
   --  them with what is behind: the fill would show at the rim.

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
     with Pre => Thick > 0.0 and then Density > 0.0 and then Radius >= 0.0;
   --  A ring Thick pixels wide just inside the box: in dashes of a few
   --  points, if Dashed. If the corners are rounded, by Radius points,
   --  the ring follows them, and is as wide there as at the sides, to
   --  the pixel; dashes run along the sides, and the corners are solid.
   --  The edges of a rounded corner are smooth: a pixel the curve cuts is
   --  inked as much as it covers it, blended with what is behind, as Over
   --  says.

   procedure Bevel
     (Target  : SDL3.Painters.Painter'Class;
      Light   : Themes.Color;
      Dark    : Themes.Color;
      Left, Top, Width, Height : Float;
      Density : Float;
      Sunken  : Boolean := False;
      Radius  : Float := 0.0;
      Round   : Corner_Flags := All_Corners)
     with Pre => Density > 0.0 and then Radius >= 0.0;
   --  The edges of a face that stands up, a point wide, just inside the
   --  box: Light at its top and left, Dark at its foot and right; the
   --  other way round if it is Sunken, as pressed in. Flat colours, never
   --  a gradient. Where a corner is rounded (Radius, in pixels, that of the
   --  box), the edges stop short of it.

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
     with Pre => Density > 0.0 and then Radius >= 0.0;
   --  A control's face (its corners rounded by Radius points): filled, and
   --  outlined a point wide just inside the box, and, if the theme has a bevel (and Bevelled), with Edges just
   --  inside the outline, turned over if Sunken, as of one held down.
   --  Pressed, hovered or turned off is a matter of the colours given.

   procedure Draw_Flat
     (Target  : SDL3.Painters.Painter'Class;
      Fill    : Themes.Color;
      Edge_Color : Themes.Color;
      Left, Top, Width, Height : Float;
      Density : Float;
      Radius  : Float := 0.0;
      Round   : Corner_Flags := All_Corners)
     with Pre => Density > 0.0 and then Radius >= 0.0;
   --  A control's face, flat (its corners rounded by Radius points): filled,
   --  and outlined a point wide just inside the box. Pressed, hovered or turned off is a matter of the
   --  colours it is given (see Pomarine.Themes.Tone_Color).

end Pomarine.Boxes;
