with Pomarine.Boxes;
with Yoga.Nodes;
package body Pomarine.Widgets.Menus is

   use type Semantics.Action;
   use type Semantics.Role;

   use type SDL3.Events.Event_Kind;
   use all type SDL3.Painters.Painter;

   --  In points

   Pad         : constant Float := 3.0;   --  above the first row, and below
   Inset       : constant Float := 10.0;  --  before what is in a row
   Gap         : constant Float := 8.0;   --  between the parts of a row
   Box_Size    : constant Float := 12.0;
   Tick_Size   : constant Float := 10.0;
   Icon_Size   : constant Float := 12.0;
   Swatch_Size : constant Float := 8.0;

   function Row_Height (Kind : Row_Kind) return Float is
     (case Kind is
         when Heading   => 24.0,
         when Separator => 9.0,
         when Action | Check | Note => 26.0);

   function Can_Click (Kind : Row_Kind) return Boolean is
     (Kind in Action | Check);

   procedure Fit (Item : in out Menu);
   --  Make it as tall as its rows, and draw it again.

   procedure Fit (Item : in out Menu) is
   begin
      if Is_Attached (Item) then
         Yoga.Nodes.Set_Height
           (Node (Item), Float'Rounding (Shown_Height (Item) * Density (Item)));
         Request_Layout (Item);
         Invalidate (Item);
      end if;
   end Fit;

   procedure Clear (Item : in out Menu) is
   begin
      Item.Used := 0;
      Item.Scrolled := 0.0;
      Item.Over := 0;
      Item.Pressed := 0;
      Item.Chosen := 0;
      Fit (Item);
   end Clear;

   procedure Add
     (Item    : in out Menu;
      Kind    : Row_Kind;
      Text    : String := "";
      Shade   : Tone := Plain;
      Checked : Boolean := False)
   is
      Made : Line;
   begin
      Made.Kind := Kind;
      Made.Length := Text'Length;
      Made.Text (1 .. Text'Length) := Text;
      Made.Shade := Shade;
      Made.Checked := Checked;
      Item.Used := Item.Used + 1;
      Item.Rows (Item.Used) := Made;
      Fit (Item);
   end Add;

   function Row_Count (Item : Menu) return Natural is (Item.Used);

   procedure Changed_Look (Item : in out Menu);

   procedure Changed_Look (Item : in out Menu) is
   begin
      if Is_Attached (Item) then
         Invalidate (Item);
      end if;
   end Changed_Look;

   procedure Set_Icon (Item : in out Menu; Row : Positive; To : Pomarine.Icons.Icon)
   is
   begin
      Item.Rows (Row).Iconed := True;
      Item.Rows (Row).Which := To;
      Changed_Look (Item);
   end Set_Icon;

   procedure Set_Swatch
     (Item : in out Menu; Row : Positive; To : Themes.Slot) is
   begin
      Item.Rows (Row).Swatched := True;
      Item.Rows (Row).Swatch := To;
      Changed_Look (Item);
   end Set_Swatch;

   procedure Set_Checked (Item : in out Menu; Row : Positive; To : Boolean)
   is
   begin
      if Item.Rows (Row).Checked /= To then
         Item.Rows (Row).Checked := To;
         Changed_Look (Item);
      end if;
   end Set_Checked;

   function Kind_Of (Item : Menu; Row : Positive) return Row_Kind is
     (Item.Rows (Row).Kind);

   function Text_Of (Item : Menu; Row : Positive) return String is
     (Item.Rows (Row).Text (1 .. Item.Rows (Row).Length));

   procedure Set_Enabled (Item : in out Menu; Row : Positive; To : Boolean) is
   begin
      if Item.Rows (Row).Enabled /= To then
         Item.Rows (Row).Enabled := To;
         if not To and then Item.Over = Row then
            Item.Over := 0;
         end if;
         Invalidate (Item);
      end if;
   end Set_Enabled;

   function Is_Enabled (Item : Menu; Row : Positive) return Boolean is
     (Item.Rows (Row).Enabled);

   function Is_Checked (Item : Menu; Row : Positive) return Boolean is
     (Item.Rows (Row).Checked);

   function Height_For (Item : Menu) return Float is
      Total : Float := 2.0 * Pad + 2.0 + Themes.Shadow_Offset;
      --  The outline, a point each side, and the shadow.
   begin
      for Index in 1 .. Item.Used loop
         Total := Total + Row_Height (Item.Rows (Index).Kind);
      end loop;
      return Total;
   end Height_For;

   function Shown_Height (Item : Menu) return Float is
     (if Item.Max_High > 0.0 then Float'Min (Height_For (Item), Item.Max_High)
      else Height_For (Item));

   Chrome : constant Float := 2.0 * Pad + 2.0 + Themes.Shadow_Offset;
   --  Of the height that is not rows.

   function Rows_Height (Item : Menu) return Float is
      Total : Float := 0.0;
   begin
      for Index in 1 .. Item.Used loop
         Total := Total + Row_Height (Item.Rows (Index).Kind);
      end loop;
      return Total;
   end Rows_Height;

   function Max_Scroll (Item : Menu) return Float is
     (Float'Max (0.0, (Rows_Height (Item) - (Shown_Height (Item) - Chrome)) * Density (Item)));
   --  In pixels.

   function Is_Scrollable (Item : Menu) return Boolean is (Max_Scroll (Item) > 0.0);

   procedure Set_Max_Height (Item : in out Menu; Points : Float) is
   begin
      if Points /= Item.Max_High then
         Item.Max_High := Points;
         Item.Scrolled := Float'Min (Item.Scrolled, Max_Scroll (Item));
         Fit (Item);
      end if;
   end Set_Max_Height;

   procedure Reveal (Item : in out Menu; Row : Positive) is
      Pixels : constant Float := Density (Item);
      Above  : Float := 0.0;
   begin
      for Index in 1 .. Row - 1 loop
         Above := Above + Float'Rounding (Row_Height (Item.Rows (Index).Kind) * Pixels);
      end loop;
      declare
         High    : constant Float := Float'Rounding (Row_Height (Item.Rows (Row).Kind) * Pixels);
         Visible : constant Float := (Shown_Height (Item) - Chrome) * Pixels;
      begin
         if Above < Item.Scrolled then
            Item.Scrolled := Above;
         elsif Above + High > Item.Scrolled + Visible then
            Item.Scrolled := Above + High - Visible;
         end if;
         Item.Scrolled := Float'Max (0.0, Float'Min (Item.Scrolled, Max_Scroll (Item)));
         Invalidate (Item);
      end;
   end Reveal;

   function Hovered_Row (Item : Menu) return Natural is (Item.Over);

   procedure Take_Choice (Item : in out Menu; Chosen : out Natural) is
   begin
      Chosen := Item.Chosen;
      Item.Chosen := 0;
   end Take_Choice;

   function First_Top (Item : Menu) return Float is
     (Top_Of (Item) + Pomarine.Boxes.Edge (Density (Item))
      + Float'Rounding (Pad * Density (Item)) - Item.Scrolled);
   --  Of the first row, in pixels, as scrolled.

   function Rows_Top (Item : Menu) return Float is
     (Top_Of (Item) + Pomarine.Boxes.Edge (Density (Item))
      + Float'Rounding (Pad * Density (Item)));
   function Rows_Bottom (Item : Menu) return Float is
     (Rows_Top (Item) + Float'Rounding ((Shown_Height (Item) - Chrome) * Density (Item)));
   --  Where the rows show: the box less its padding, in pixels.

   function Row_At (Item : Menu; X, Y : Float) return Natural;
   --  The row that can be clicked at pixel X, Y; 0 if none.

   function Row_At (Item : Menu; X, Y : Float) return Natural is
      Pixels : constant Float := Density (Item);
      Top    : Float := First_Top (Item);
      Right  : constant Float :=
        Left_Of (Item) + Width_Of (Item) - Pomarine.Boxes.Offset (Pixels);
   begin
      if X < Left_Of (Item) or else X >= Right or else Y < Rows_Top (Item) or else Y >= Rows_Bottom (Item) then
         return 0;
      end if;
      for Index in 1 .. Item.Used loop
         declare
            High : constant Float :=
              Float'Rounding (Row_Height (Item.Rows (Index).Kind) * Pixels);
         begin
            if Y >= Top and then Y < Top + High then
               return (if Can_Click (Item.Rows (Index).Kind) and then Item.Rows (Index).Enabled
                       then Index else 0);
            end if;
            Top := Top + High;
         end;
      end loop;
      return 0;
   end Row_At;

   overriding procedure Handle
     (Item    : in out Menu;
      Event   : SDL3.Events.Event;
      Handled : out Boolean)
   is
      Under : constant Natural :=
        Row_At (Item, Event.Mouse_X * Density (Item),
                Event.Mouse_Y * Density (Item));
   begin
      Handled := False;
      case Event.Kind is
         when SDL3.Events.Mouse_Move =>
            if Under /= Item.Over then
               Item.Over := Under;
               Invalidate (Item);
            end if;
         when SDL3.Events.Mouse_Down =>
            if Event.Button = 1
              and then Contains (Item, Event.Mouse_X * Density (Item),
                                 Event.Mouse_Y * Density (Item))
            then
               --  Taken, so that a press on it is not on what is under it.
               Item.Pressed := Under;
               Item.Over := Under;
               Handled := True;
               Invalidate (Item);
            end if;
         when SDL3.Events.Mouse_Up =>
            if Event.Button = 1 then
               if Item.Pressed /= 0 and then Under = Item.Pressed then
                  Item.Chosen := Under;
                  Notify (Item, Choose, Row => Under);
               end if;
               Handled := Item.Pressed /= 0;
               Item.Pressed := 0;
               Invalidate (Item);
            end if;
         when SDL3.Events.Mouse_Wheel =>
            if Contains (Item, Event.Mouse_X * Density (Item), Event.Mouse_Y * Density (Item)) then
               declare
                  To : constant Float :=
                    Float'Max (0.0, Float'Min (Max_Scroll (Item),
                                               Item.Scrolled - Event.Wheel_Y * 24.0 * Density (Item)));
               begin
                  if To /= Item.Scrolled then
                     Item.Scrolled := To;
                     Item.Over := Row_At (Item, Event.Mouse_X * Density (Item), Event.Mouse_Y * Density (Item));
                     Invalidate (Item);
                  end if;
               end;
               --  Taken, so the canvas under it is not scrolled.
               Handled := True;
            end if;
         when others =>
            null;
      end case;
   end Handle;

   overriding procedure Hover_Changed
     (Item : in out Menu; Hovered : Boolean) is
   begin
      if not Hovered and then Item.Over /= 0 then
         Item.Over := 0;
         Invalidate (Item);
      end if;
   end Hover_Changed;

   overriding function Cursor (Item : Menu) return SDL3.Cursors.Kind is
     (if Item.Over /= 0 then SDL3.Cursors.Pointer else SDL3.Cursors.Default);

   overriding procedure Draw
     (Item   : in out Menu;
      Target : SDL3.Painters.Painter'Class;
      Colors : Themes.Theme)
   is
      Pixels : constant Float := Density (Item);
      Edge   : constant Float := Pomarine.Boxes.Edge (Pixels);
      Look   : constant Pomarine.Boxes.Look :=
        (Filled   => True,
         Fill     => Colors (Themes.Page),
         Bordered => True,
         Border   => Colors (Themes.Border),
         Dashed   => False,
         Shadowed => True,
         Shadow   => Colors (Themes.Drop_Shadow));
      Inner_Left  : constant Float := Left_Of (Item) + Edge;
      Inner_Width : constant Float :=
        Width_Of (Item) - Pomarine.Boxes.Inset (Look, Pixels) - 2.0 * Edge;
      Top    : Float := First_Top (Item);
      Any_Icon : constant Boolean :=
        (for some Index in 1 .. Item.Used => Item.Rows (Index).Iconed);
      Saved    : SDL3.Painters.Clip;
      Reserve  : constant Float := (if Is_Scrollable (Item) then 8.0 * Pixels else 0.0);
      --  Of the width, for the bar that shows how far it is scrolled.

      Ellipsis : constant String :=
        [Character'Val (16#E2#), Character'Val (16#80#), Character'Val (16#A6#)];

      function Fitted (Value : String; Room : Float; Using : Pomarine.Line_Texts.Style) return String;
      --  Value, or as much of its start as fits Room pixels with an
      --  ellipsis after it, cut where a character begins.

      function Fitted (Value : String; Room : Float; Using : Pomarine.Line_Texts.Style) return String is
         Last : Natural := Value'Length;
      begin
         if Room <= 0.0 or else Pomarine.Line_Texts.Width (Text_Lines (Item).all, Value, Pixels, Using) <= Room then
            return Value;
         end if;
         while Last > 0 loop
            Last := Last - 1;
            while Last > 0 and then Character'Pos (Value (Value'First + Last)) in 16#80# .. 16#BF# loop
               Last := Last - 1;
            end loop;
            exit when Pomarine.Line_Texts.Width
                        (Text_Lines (Item).all, Value (Value'First .. Value'First + Last - 1) & Ellipsis,
                         Pixels, Using) <= Room;
         end loop;
         return Value (Value'First .. Value'First + Last - 1) & Ellipsis;
      end Fitted;
   begin
      Pomarine.Boxes.Draw
        (Target, Look, Left_Of (Item), Top_Of (Item), Width_Of (Item),
         Height_Of (Item), Pixels);
      Saved := Current_Clip (Target);
      Narrow_Clip
        (Target, Integer (Float'Floor (Inner_Left)), Integer (Float'Floor (Rows_Top (Item))),
         Integer (Float'Ceiling (Inner_Width)), Integer (Float'Ceiling (Rows_Bottom (Item) - Rows_Top (Item))));
      for Index in 1 .. Item.Used loop
         declare
            Each   : Line renames Item.Rows (Index);
            High   : constant Float :=
              Float'Rounding (Row_Height (Each.Kind) * Pixels);
            Middle : constant Float := Top + High / 2.0;
            Ink    : constant Themes.Color :=
              (case Each.Kind is
                  when Heading | Note => Colors (Themes.Muted),
                  when others =>
                    (if not Each.Enabled then Colors (Themes.Muted) else
                     (case Each.Shade is
                         when Plain   => Colors (Themes.Foreground),
                         when Primary => Colors (Themes.Primary_Ink),
                         when Danger  => Colors (Themes.Danger_Ink))));
            Using  : constant Pomarine.Line_Texts.Style :=
              (case Each.Kind is
                  when Heading => Pomarine.Line_Texts.Caption,
                  when others  =>
                    (if Each.Shade = Plain then Pomarine.Line_Texts.Regular
                     else Pomarine.Line_Texts.Strong));
            After  : Float := Inner_Left + Inset * Pixels;

            procedure Square (Side : Float; Value : Themes.Color) is
               Size : constant Float := Float'Rounding (Side * Pixels);
            begin
               Fill_Rect
                 (Target, Value, Float'Rounding (After),
                  Float'Rounding (Middle - Size / 2.0), Size, Size);
            end Square;

            procedure Picture (Which : Pomarine.Icons.Icon; Side : Float;
                               Left : Float) is
               Size  : constant Positive :=
                 Positive (Float'Rounding (Side * Pixels));
               Drawn : Boolean;
            begin
               if Icon_Library (Item) /= null then
                  Pomarine.Icons.Draw
                    (Icon_Library (Item).all, Target, Which, Ink,
                     Float'Rounding (Left),
                     Float'Rounding (Middle - Float (Size) / 2.0),
                     Size, Drawn);
               end if;
            end Picture;
         begin
            if Can_Click (Each.Kind) and then Index = Item.Over then
               Fill_Rect
                 (Target,
                  (if Index = Item.Pressed then Colors (Themes.Face)
                   else Colors (Themes.Background)),
                  Inner_Left, Top, Inner_Width, High);
            end if;
            case Each.Kind is
               when Separator =>
                  Fill_Rect
                    (Target, Themes.Mix (Colors (Themes.Border), Colors (Themes.Page), 0.4),
                     Inner_Left, Float'Rounding (Middle), Inner_Width, Edge);
               when Check =>
                  declare
                     Side : constant Float :=
                       Float'Rounding (Box_Size * Pixels);
                     Box_Top : constant Float :=
                       Float'Rounding (Middle - Side / 2.0);
                  begin
                     Fill_Rect
                       (Target, Colors (Themes.Page), Float'Rounding (After), Box_Top,
                        Side, Side);
                     Pomarine.Boxes.Outline
                       (Target,
                        Themes.Mix (Colors (Themes.Border), Colors (Themes.Foreground), 0.35),
                        Float'Rounding (After), Box_Top, Side, Side, Edge);
                     if Each.Checked then
                        Picture
                          (Pomarine.Icons.Check, Tick_Size,
                           After + (Side - Tick_Size * Pixels) / 2.0);
                     end if;
                     After := After + Side + Gap * Pixels;
                  end;
               when Action | Note =>
                  --  A row without an icon is in line with those that
                  --  have one.
                  if Each.Iconed then
                     Picture (Each.Which, Icon_Size, After);
                     After := After + (Icon_Size + Gap) * Pixels;
                  elsif Each.Kind = Action and then Any_Icon then
                     After := After + (Icon_Size + Gap) * Pixels;
                  end if;
               when Heading =>
                  null;
            end case;
            if Each.Swatched and then Each.Kind /= Separator then
               Square
                 (Swatch_Size,
                  (if Each.Enabled then Themes.Resolve (Colors, Each.Swatch)
                   else Themes.Mix (Themes.Resolve (Colors, Each.Swatch), Colors (Themes.Page), 0.6)));
               After := After + (Swatch_Size + Gap) * Pixels;
            end if;
            if Each.Length > 0 and then Text_Lines (Item) /= null then
               Pomarine.Line_Texts.Draw
                 (Text_Lines (Item).all, Target, Ink,
                  Fitted (Each.Text (1 .. Each.Length),
                          Inner_Left + Inner_Width - Reserve - Inset * Pixels - After, Using),
                  After, Middle, Pixels, Using);
            end if;
            Top := Top + High;
         end;
      end loop;
      Restore_Clip (Target, Saved);
      if Reserve > 0.0 then
         declare
            Track  : constant Float := Rows_Bottom (Item) - Rows_Top (Item);
            Whole  : constant Float := Rows_Height (Item) * Pixels;
            Thumb  : constant Float := Float'Max (12.0 * Pixels, Track * Track / Whole);
            Space  : constant Float := Max_Scroll (Item);
            Along  : constant Float := (if Space > 0.0 then Item.Scrolled / Space else 0.0);
         begin
            Fill_Rect
              (Target, Themes.Mix (Colors (Themes.Border), Colors (Themes.Foreground), 0.35),
               Float'Rounding (Inner_Left + Inner_Width - 5.0 * Pixels),
               Float'Rounding (Rows_Top (Item) + Along * (Track - Thumb)),
               Float'Rounding (3.0 * Pixels), Float'Rounding (Thumb));
         end;
      end if;
   end Draw;

   overriding procedure Describe
     (Item  : Menu;
      Facts : in out Semantics.Description) is
   begin
      if Facts.Kind = Semantics.Unknown then
         Facts.Kind := Semantics.Menu;
      end if;
   end Describe;

   overriding function Part_Count (Item : Menu) return Natural is (Item.Used);

   overriding procedure Describe_Part
     (Item   : Menu;
      Part   : Positive;
      Facts  : in out Semantics.Description;
      Bounds : out Semantics.Rectangle)
   is
      Pixels : constant Float := Density (Item);
      Top    : Float := First_Top (Item);
      Row    : Line renames Item.Rows (Part);
   begin
      for Before in 1 .. Part - 1 loop
         Top := Top + Float'Rounding (Row_Height (Item.Rows (Before).Kind) * Pixels);
      end loop;
      Bounds :=
        (Left   => Left_Of (Item),
         Top    => Top,
         Right  => Left_Of (Item) + Width_Of (Item) - Pomarine.Boxes.Offset (Pixels),
         Bottom => Top + Float'Rounding (Row_Height (Row.Kind) * Pixels));
      case Row.Kind is
         when Heading =>
            Facts.Kind := Semantics.Heading;
         when Action =>
            Facts.Kind := Semantics.Menu_Item;
            Facts.Actions (Semantics.Click) := True;
         when Check =>
            Facts.Kind := Semantics.Menu_Item;
            Facts.Checked := (if Row.Checked then Semantics.On else Semantics.Off);
            Facts.Actions (Semantics.Click) := True;
         when Separator =>
            Facts.Kind := Semantics.Separator;
         when Note =>
            Facts.Kind := Semantics.Label;
      end case;
      Semantics.Name_As (Facts, Row.Text (1 .. Row.Length));
   end Describe_Part;

   overriding procedure Perform_Part
     (Item    : in out Menu;
      Part    : Positive;
      Request : Semantics.Request;
      Done    : out Boolean) is
   begin
      Done := Request.Doing = Semantics.Click and then Part <= Item.Used
        and then Can_Click (Item.Rows (Part).Kind) and then Item.Rows (Part).Enabled;
      if Done then
         Item.Chosen := Part;
         Notify (Item, Choose, Row => Part);
         Invalidate (Item);
      end if;
   end Perform_Part;

end Pomarine.Widgets.Menus;
