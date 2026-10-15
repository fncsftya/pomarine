with SDL3.Windows.Renderers;
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

   type Look is record
      Filled   : Boolean := False;
      Fill     : Themes.Color := (0, 0, 0, 255);
      Bordered : Boolean := False;
      Border   : Themes.Color := (0, 0, 0, 255);
      Dashed   : Boolean := False;
      Shadowed : Boolean := False;
      Shadow   : Themes.Color := (0, 0, 0, 255);
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
     (Target  : SDL3.Windows.Renderers.Renderer;
      Item    : Look;
      Left, Top, Width, Height : Float;
      Density : Float)
     with Pre => Density > 0.0;
   --  In pixels from the top left of Target.

   procedure Outline
     (Target  : SDL3.Windows.Renderers.Renderer;
      Ink     : Themes.Color;
      Left, Top, Width, Height : Float;
      Thick   : Float;
      Dashed  : Boolean := False;
      Density : Float := 1.0)
     with Pre => Thick > 0.0 and then Density > 0.0;
   --  A ring Thick pixels wide just inside the box: in dashes of a few
   --  points, if Dashed.

   procedure Bevel
     (Target  : SDL3.Windows.Renderers.Renderer;
      Light   : Themes.Color;
      Dark    : Themes.Color;
      Left, Top, Width, Height : Float;
      Density : Float;
      Sunken  : Boolean := False)
     with Pre => Density > 0.0;
   --  The edges of a face that stands up, a point wide, just inside the
   --  box: Light at its top and left, Dark at its foot and right; the
   --  other way round if it is Sunken, as pressed in. Flat colours, never
   --  a gradient.

   procedure Draw_Control
     (Target  : SDL3.Windows.Renderers.Renderer;
      Colors  : Themes.Theme;
      Fill    : Themes.Color;
      Edge_Color : Themes.Color;
      Edges   : Themes.Bevel_Colors;
      Left, Top, Width, Height : Float;
      Density : Float;
      Bevelled : Boolean := True;
      Sunken  : Boolean := False)
     with Pre => Density > 0.0;
   --  A control's face: filled, and outlined a point wide just inside the
   --  box, and, if the theme has a bevel (and Bevelled), with Edges just
   --  inside the outline, turned over if Sunken, as of one held down.
   --  Pressed, hovered or turned off is a matter of the colours given.

   procedure Draw_Flat
     (Target  : SDL3.Windows.Renderers.Renderer;
      Fill    : Themes.Color;
      Edge_Color : Themes.Color;
      Left, Top, Width, Height : Float;
      Density : Float)
     with Pre => Density > 0.0;
   --  A control's face, flat: filled, and outlined a point wide just
   --  inside the box. Pressed, hovered or turned off is a matter of the
   --  colours it is given (see Pomarine.Themes.Tone_Color).

end Pomarine.Boxes;
