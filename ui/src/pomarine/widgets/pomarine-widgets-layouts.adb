with Pomarine.Boxes;
with Yoga.Nodes;
package body Pomarine.Widgets.Layouts is

   function Length_Of_Literal (Text : String) return Length is
     ((Kind => Unit_Relative, Amount => Float'Value (Text)));

   function Weight_Of_Literal (Text : String) return Weight is
     ((Given => True, Amount => Float'Value (Text)));

   function Length_Of (Amount : Float) return Length is ((Kind => Unit_Relative, Amount => Amount));

   function In_Points (Amount : Float) return Length is ((Kind => Point_Based, Amount => Amount));

   function In_Pixels (Amount : Float) return Length is ((Kind => Pixel_Based, Amount => Amount));

   function Weight_Of (Amount : Float) return Weight is ((Given => True, Amount => Amount));

   function "-" (Item : Length) return Length is
     (case Item.Kind is
         when Unit_Relative | Point_Based | Pixel_Based => (Kind => Item.Kind, Amount => -Item.Amount),
         when others                => Item);

   function Is_Set (Item : Length) return Boolean is (Item.Kind /= Unspecified);

   procedure Set_Layout (Item : in out Widget'Class; Using : Style) is
      Width      : Length renames Using.Width;
      Height     : Length renames Using.Height;
      Grow       : Weight renames Using.Grow;
      Shrink     : Weight renames Using.Shrink;
      Padding    : Sides renames Using.Padding;
      Outlined   : Toggle_Kind renames Using.Outlined;
      Shadowed   : Toggle_Kind renames Using.Shadowed;
      Margin     : Sides renames Using.Margin;
      Gap        : Length renames Using.Gap;
      Flow       : Flow_Kind renames Using.Flow;
      Align      : Align_Kind renames Using.Align;
      Align_Self : Align_Kind renames Using.Align_Self;
      Spread     : Spread_Kind renames Using.Spread;
      Wrap       : Toggle_Kind renames Using.Wrap;
      Place      : Place_Kind renames Using.Place;
      Position   : Sides renames Using.Position;
      Unit       : Unit_Kind renames Using.Unit;
      Box    : constant Yoga.Nodes.Node := Node (Item);
      Scale  : constant Float := (if Unit = Points then Density (Item) else 1.0);
      --  What a point of this call is, in pixels.

      function Yoga_Align (Of_Kind : Align_Kind) return Yoga.Align is
        (case Of_Kind is
            when As_Is    => Yoga.Auto,
            when Start    => Yoga.Flex_Start,
            when Center   => Yoga.Center,
            when Finish   => Yoga.Flex_End,
            when Stretch  => Yoga.Stretch);

      function Pixels_Of (Amount : Length) return Float is
        (case Amount.Kind is
            when One_Outline => Pomarine.Boxes.Edge (Density (Item)),
            when One_Shadow  => Pomarine.Boxes.Offset (Density (Item)),
            when Pixel_Based  => Amount.Amount,
            when Point_Based  => Amount.Amount * Density (Item),
            when others      => Amount.Amount * Scale);
      --  Unspecified is never asked for: it is left as it is.

      procedure Edges
        (Edge_Values : Sides;
         Set         : not null access procedure (Side : Yoga.Edge; Value : Float)) is
      begin
         if Is_Set (Edge_Values.Left) then
            Set (Yoga.Left, Pixels_Of (Edge_Values.Left));
         end if;
         if Is_Set (Edge_Values.Top) then
            Set (Yoga.Top, Pixels_Of (Edge_Values.Top));
         end if;
         if Is_Set (Edge_Values.Right) then
            Set (Yoga.Right, Pixels_Of (Edge_Values.Right));
         end if;
         if Is_Set (Edge_Values.Bottom) then
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
      if Is_Set (Width) then
         Yoga.Nodes.Set_Width (Box, Pixels_Of (Width));
      end if;
      if Is_Set (Height) then
         Yoga.Nodes.Set_Height (Box, Pixels_Of (Height));
      end if;
      if Grow.Given then
         Yoga.Nodes.Set_Flex_Grow (Box, Grow.Amount);
      end if;
      if Shrink.Given then
         Yoga.Nodes.Set_Flex_Shrink (Box, Shrink.Amount);
      end if;
      declare
         Edge   : constant Float := (if Outlined = On then Pomarine.Boxes.Edge (Density (Item)) else 0.0);
         Offset : constant Float := (if Shadowed = On then Pomarine.Boxes.Offset (Density (Item)) else 0.0);

         procedure Pad (Side : Yoga.Edge; Amount : Length; Room : Float; Turned_Off : Boolean) is
         begin
            if Is_Set (Amount) or else Room > 0.0 or else Turned_Off then
               Yoga.Nodes.Set_Padding
                 (Box, Side, (if Is_Set (Amount) then Pixels_Of (Amount) else 0.0) + Room);
            end if;
         end Pad;

         Off_Left_Top     : constant Boolean := Outlined = Off;
         Off_Right_Bottom : constant Boolean := Outlined = Off or else Shadowed = Off;
         --  Turned off, the room is not there: the padding is what is said and no more.
      begin
         Pad (Yoga.Left, Padding.Left, Edge, Off_Left_Top);
         Pad (Yoga.Top, Padding.Top, Edge, Off_Left_Top);
         Pad (Yoga.Right, Padding.Right, Edge + Offset, Off_Right_Bottom);
         Pad (Yoga.Bottom, Padding.Bottom, Edge + Offset, Off_Right_Bottom);
      end;
      Edges (Margin, Margins'Access);
      if Is_Set (Gap) then
         Yoga.Nodes.Set_Gap (Box, Yoga.All_Gutters, Pixels_Of (Gap));
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
      case Wrap is
         when As_Is => null;
         when On    => Yoga.Nodes.Set_Wrap (Box, Yoga.Wrap);
         when Off   => Yoga.Nodes.Set_Wrap (Box, Yoga.No_Wrap);
      end case;
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
      Width    : Length := Unset;
      Height   : Length := Unset;
      Grow     : Weight := Unchanged;
      Shrink   : Weight := Unchanged;
      Padding  : Sides := (others => <>);
      Outlined : Toggle_Kind := As_Is;
      Shadowed : Toggle_Kind := As_Is;
      Margin   : Sides := (others => <>);
      Gap      : Length := Unset;
      Flow     : Flow_Kind := As_Is;
      Align    : Align_Kind := As_Is;
      Align_Self : Align_Kind := As_Is;
      Spread   : Spread_Kind := As_Is;
      Wrap     : Toggle_Kind := As_Is;
      Place    : Place_Kind := As_Is;
      Position : Sides := (others => <>);
      Unit     : Unit_Kind := Points) is
   begin
      Set_Layout
        (Item,
         Style'(Width => Width, Height => Height, Grow => Grow, Shrink => Shrink, Padding => Padding,
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

   function Row
     (Width    : Length := Unset;
      Height   : Length := Unset;
      Grow     : Weight := Unchanged;
      Shrink   : Weight := Unchanged;
      Padding  : Sides := (others => <>);
      Margin   : Sides := (others => <>);
      Gap      : Length := Unset;
      Align    : Align_Kind := As_Is;
      Spread   : Spread_Kind := As_Is;
      Wrap     : Toggle_Kind := As_Is) return Style is
     (Width => Width, Height => Height, Grow => Grow, Shrink => Shrink, Padding => Padding, Margin => Margin,
      Gap => Gap, Flow => Layouts.Row, Align => Align, Spread => Spread, Wrap => Wrap, others => <>);

   function Column
     (Width    : Length := Unset;
      Height   : Length := Unset;
      Grow     : Weight := Unchanged;
      Shrink   : Weight := Unchanged;
      Padding  : Sides := (others => <>);
      Margin   : Sides := (others => <>);
      Gap      : Length := Unset;
      Align    : Align_Kind := As_Is;
      Spread   : Spread_Kind := As_Is;
      Wrap     : Toggle_Kind := As_Is) return Style is
     (Width => Width, Height => Height, Grow => Grow, Shrink => Shrink, Padding => Padding, Margin => Margin,
      Gap => Gap, Flow => Layouts.Column, Align => Align, Spread => Spread, Wrap => Wrap, others => <>);

   procedure Row
     (Item     : in out Widget'Class;
      Width    : Length := Unset;
      Height   : Length := Unset;
      Grow     : Weight := Unchanged;
      Shrink   : Weight := Unchanged;
      Padding  : Sides := (others => <>);
      Margin   : Sides := (others => <>);
      Gap      : Length := Unset;
      Align    : Align_Kind := As_Is;
      Spread   : Spread_Kind := As_Is;
      Wrap     : Toggle_Kind := As_Is) is
      Using : constant Style := Row (Width, Height, Grow, Shrink, Padding, Margin, Gap, Align, Spread, Wrap);
   begin
      Set_Layout (Item, Using);
   end Row;

   procedure Column
     (Item     : in out Widget'Class;
      Width    : Length := Unset;
      Height   : Length := Unset;
      Grow     : Weight := Unchanged;
      Shrink   : Weight := Unchanged;
      Padding  : Sides := (others => <>);
      Margin   : Sides := (others => <>);
      Gap      : Length := Unset;
      Align    : Align_Kind := As_Is;
      Spread   : Spread_Kind := As_Is;
      Wrap     : Toggle_Kind := As_Is) is
      Using : constant Style := Column (Width, Height, Grow, Shrink, Padding, Margin, Gap, Align, Spread, Wrap);
   begin
      Set_Layout (Item, Using);
   end Column;

end Pomarine.Widgets.Layouts;
