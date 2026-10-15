package body Pomarine.Boxes is

   use SDL3.Windows.Renderers;

   Dash : constant Float := 4.0;
   Gap  : constant Float := 3.0;
   --  In points, of a dashed outline.

   procedure Outline
     (Target  : SDL3.Windows.Renderers.Renderer;
      Ink     : Themes.Color;
      Left, Top, Width, Height : Float;
      Thick   : Float;
      Dashed  : Boolean := False;
      Density : Float := 1.0)
   is
      procedure Across (Y : Float) is
         Place : Float := 0.0;
         Step  : constant Float := Float'Rounding ((Dash + Gap) * Density);
         Long  : constant Float := Float'Rounding (Dash * Density);
      begin
         if not Dashed then
            Fill_Rect (Target, Ink, Left, Y, Width, Thick);
            return;
         end if;
         while Place < Width loop
            Fill_Rect (Target, Ink, Left + Place, Y,
                       Float'Min (Long, Width - Place), Thick);
            Place := Place + Step;
         end loop;
      end Across;

      procedure Down (X : Float) is
         Place : Float := 0.0;
         Step  : constant Float := Float'Rounding ((Dash + Gap) * Density);
         Long  : constant Float := Float'Rounding (Dash * Density);
      begin
         if not Dashed then
            Fill_Rect (Target, Ink, X, Top, Thick, Height);
            return;
         end if;
         while Place < Height loop
            Fill_Rect (Target, Ink, X, Top + Place, Thick,
                       Float'Min (Long, Height - Place));
            Place := Place + Step;
         end loop;
      end Down;
   begin
      Across (Top);
      Across (Top + Height - Thick);
      Down (Left);
      Down (Left + Width - Thick);
   end Outline;

   procedure Draw
     (Target  : SDL3.Windows.Renderers.Renderer;
      Item    : Look;
      Left, Top, Width, Height : Float;
      Density : Float)
   is
      Off  : constant Float := Inset (Item, Density);
      Wide : constant Float := Width - Off;
      High : constant Float := Height - Off;
   begin
      if Item.Shadowed then
         Fill_Rect (Target, Item.Shadow, Left + Off, Top + Off, Wide, High);
      end if;
      if Item.Filled then
         Fill_Rect (Target, Item.Fill, Left, Top, Wide, High);
      end if;
      if Item.Bordered then
         Outline (Target, Item.Border, Left, Top, Wide, High, Edge (Density),
                  Item.Dashed, Density);
      end if;
   end Draw;

   procedure Bevel
     (Target  : SDL3.Windows.Renderers.Renderer;
      Light   : Themes.Color;
      Dark    : Themes.Color;
      Left, Top, Width, Height : Float;
      Density : Float;
      Sunken  : Boolean := False)
   is
      Thick : constant Float := Edge (Density);
      Lit   : constant Themes.Color := (if Sunken then Dark else Light);
      Dim   : constant Themes.Color := (if Sunken then Light else Dark);
   begin
      if Width < 2.0 * Thick or else Height < 2.0 * Thick then
         return;
      end if;
      --  The foot and right over the ends of the top and left, as a
      --  light from the top left falls.
      Fill_Rect (Target, Lit, Left, Top, Width, Thick);
      Fill_Rect (Target, Lit, Left, Top, Thick, Height);
      Fill_Rect (Target, Dim, Left, Top + Height - Thick, Width, Thick);
      Fill_Rect (Target, Dim, Left + Width - Thick, Top, Thick, Height);
   end Bevel;

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
   is
      Thick : constant Float := Edge (Density);
   begin
      Fill_Rect (Target, Fill, Left, Top, Width, Height);
      Outline (Target, Edge_Color, Left, Top, Width, Height, Thick);
      if Bevelled and then Colors.Bevelled then
         Bevel (Target, Edges.Light, Edges.Dark, Left + Thick, Top + Thick,
                Width - 2.0 * Thick, Height - 2.0 * Thick, Density, Sunken);
      end if;
   end Draw_Control;

   procedure Draw_Flat
     (Target  : SDL3.Windows.Renderers.Renderer;
      Fill    : Themes.Color;
      Edge_Color : Themes.Color;
      Left, Top, Width, Height : Float;
      Density : Float)
   is
   begin
      Fill_Rect (Target, Fill, Left, Top, Width, Height);
      Outline (Target, Edge_Color, Left, Top, Width, Height, Edge (Density));
   end Draw_Flat;

end Pomarine.Boxes;
