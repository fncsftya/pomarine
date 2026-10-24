with Pomarine.Boxes;
with Yoga.Nodes;
package body Pomarine.Widgets.Layouts is

   procedure Set_Layout (Item : in out Widget'Class; Using : Style) is
      Width      : Float renames Using.Width;
      Height     : Float renames Using.Height;
      Grow       : Float renames Using.Grow;
      Shrink     : Float renames Using.Shrink;
      Padding    : Sides renames Using.Padding;
      Outlined   : Boolean renames Using.Outlined;
      Shadowed   : Boolean renames Using.Shadowed;
      Margin     : Sides renames Using.Margin;
      Gap        : Float renames Using.Gap;
      Flow       : Flow_Kind renames Using.Flow;
      Align      : Align_Kind renames Using.Align;
      Align_Self : Align_Kind renames Using.Align_Self;
      Spread     : Spread_Kind renames Using.Spread;
      Wrap       : Boolean renames Using.Wrap;
      Place      : Place_Kind renames Using.Place;
      Position   : Sides renames Using.Position;
      Unit       : Unit_Kind renames Using.Unit;
      Box    : constant Yoga.Nodes.Node := Node (Item);
      Pixels : constant Float := (if Unit = Points then Density (Item) else 1.0);
      --  What a point of this call is, in pixels.

      function Yoga_Align (Of_Kind : Align_Kind) return Yoga.Align is
        (case Of_Kind is
            when As_Is    => Yoga.Auto,
            when Start    => Yoga.Flex_Start,
            when Center   => Yoga.Center,
            when Finish   => Yoga.Flex_End,
            when Stretch  => Yoga.Stretch);

      function Pixels_Of (Amount : Float) return Float is
        (if Amount = Hairline then Pomarine.Boxes.Edge (Density (Item))
         elsif Amount = Shadow_Room then Pomarine.Boxes.Offset (Density (Item))
         else Amount * Pixels);

      procedure Edges
        (Edge_Values : Sides;
         Set         : not null access procedure (Side : Yoga.Edge; Value : Float)) is
      begin
         if Edge_Values.Left /= Unset then
            Set (Yoga.Left, Pixels_Of (Edge_Values.Left));
         end if;
         if Edge_Values.Top /= Unset then
            Set (Yoga.Top, Pixels_Of (Edge_Values.Top));
         end if;
         if Edge_Values.Right /= Unset then
            Set (Yoga.Right, Pixels_Of (Edge_Values.Right));
         end if;
         if Edge_Values.Bottom /= Unset then
            Set (Yoga.Bottom, Pixels_Of (Edge_Values.Bottom));
         end if;
      end Edges;

      procedure Margins (Side : Yoga.Edge; Value : Float) is
      begin
         Yoga.Nodes.Set_Margin (Box, Side, Value);
      end Margins;

      procedure Put (Side : Yoga.Edge; Value : Float) is
      begin
         Yoga.Nodes.Set_Position (Box, Side, Value);
      end Put;
   begin
      if Width /= Unset then
         Yoga.Nodes.Set_Width (Box, Pixels_Of (Width));
      end if;
      if Height /= Unset then
         Yoga.Nodes.Set_Height (Box, Pixels_Of (Height));
      end if;
      if Grow /= Unset then
         Yoga.Nodes.Set_Flex_Grow (Box, Grow);
      end if;
      if Shrink /= Unset then
         Yoga.Nodes.Set_Flex_Shrink (Box, Shrink);
      end if;
      declare
         Edge   : constant Float := (if Outlined then Pomarine.Boxes.Edge (Density (Item)) else 0.0);
         Offset : constant Float := (if Shadowed then Pomarine.Boxes.Offset (Density (Item)) else 0.0);

         procedure Pad (Side : Yoga.Edge; Amount : Float; Room : Float) is
         begin
            if Amount /= Unset or else Room > 0.0 then
               Yoga.Nodes.Set_Padding
                 (Box, Side, (if Amount /= Unset then Pixels_Of (Amount) else 0.0) + Room);
            end if;
         end Pad;
      begin
         Pad (Yoga.Left, Padding.Left, Edge);
         Pad (Yoga.Top, Padding.Top, Edge);
         Pad (Yoga.Right, Padding.Right, Edge + Offset);
         Pad (Yoga.Bottom, Padding.Bottom, Edge + Offset);
      end;
      Edges (Margin, Margins'Access);
      if Gap /= Unset then
         Yoga.Nodes.Set_Gap (Box, Yoga.All_Gutters, Gap * Pixels);
      end if;
      case Flow is
         when As_Is  => null;
         when Column => Yoga.Nodes.Set_Flex_Direction (Box, Yoga.Column);
         when Row    => Yoga.Nodes.Set_Flex_Direction (Box, Yoga.Row);
      end case;
      if Align /= As_Is then
         Yoga.Nodes.Set_Align_Items (Box, Yoga_Align (Align));
      end if;
      if Align_Self /= As_Is then
         Yoga.Nodes.Set_Align_Self (Box, Yoga_Align (Align_Self));
      end if;
      case Spread is
         when As_Is   => null;
         when Start   => Yoga.Nodes.Set_Justify_Content (Box, Yoga.Flex_Start);
         when Center  => Yoga.Nodes.Set_Justify_Content (Box, Yoga.Center);
         when Finish  => Yoga.Nodes.Set_Justify_Content (Box, Yoga.Flex_End);
         when Between => Yoga.Nodes.Set_Justify_Content (Box, Yoga.Space_Between);
      end case;
      if Wrap then
         Yoga.Nodes.Set_Wrap (Box, Yoga.Wrap);
      end if;
      case Place is
         when As_Is    => null;
         when Flowing  => Yoga.Nodes.Set_Position_Type (Box, Yoga.Relative);
         when Absolute => Yoga.Nodes.Set_Position_Type (Box, Yoga.Absolute);
      end case;
      Edges (Position, Put'Access);
      Request_Layout (Item);
   end Set_Layout;

   procedure Set_Layout
     (Item     : in out Widget'Class;
      Width    : Float := Unset;
      Height   : Float := Unset;
      Grow     : Float := Unset;
      Shrink   : Float := Unset;
      Padding  : Sides := (others => <>);
      Outlined : Boolean := False;
      Shadowed : Boolean := False;
      Margin   : Sides := (others => <>);
      Gap      : Float := Unset;
      Flow     : Flow_Kind := As_Is;
      Align    : Align_Kind := As_Is;
      Align_Self : Align_Kind := As_Is;
      Spread   : Spread_Kind := As_Is;
      Wrap     : Boolean := False;
      Place    : Place_Kind := As_Is;
      Position : Sides := (others => <>);
      Unit     : Unit_Kind := Points) is
   begin
      Set_Layout
        (Item,
         (Width => Width, Height => Height, Grow => Grow, Shrink => Shrink, Padding => Padding,
          Outlined => Outlined, Shadowed => Shadowed, Margin => Margin, Gap => Gap, Flow => Flow,
          Align => Align, Align_Self => Align_Self, Spread => Spread, Wrap => Wrap, Place => Place,
          Position => Position, Unit => Unit));
   end Set_Layout;

   procedure Add_Before
     (Parent : in out Widget'Class;
      Child  : in out Widget'Class;
      Before : Widget'Class;
      Using  : Style) is
   begin
      Widgets.Add_Before (Parent, Child, Before);
      Set_Layout (Child, Using);
   end Add_Before;

   procedure Add (Parent : in out Widget'Class; Child : in out Widget'Class; Using : Style) is
   begin
      Widgets.Add (Parent, Child);
      Set_Layout (Child, Using);
   end Add;

end Pomarine.Widgets.Layouts;
