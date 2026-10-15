with Pomarine.Boxes;
with Pomarine.Icons;

package body Pomarine.Widgets.Selects is

   use type SDL3.Events.Event_Kind;
   use SDL3.Windows.Renderers;

   Pad        : constant Float := 8.0;   --  in points, before the value
   Inner      : constant Float := 2.0;   --  round the button, in points
   Caret_Size : constant Float := 10.0;  --  in points, a side

   procedure Changed_Look (Item : in out Select_Field);
   --  Draw it again, if it is in a tree.

   procedure Changed_Look (Item : in out Select_Field) is
   begin
      if Is_Attached (Item) then
         Invalidate (Item);
      end if;
   end Changed_Look;

   procedure Set_Value (Item : in out Select_Field; Text : String) is
   begin
      if Text /= Value (Item) then
         Item.Length := Text'Length;
         Item.Text (1 .. Item.Length) := Text;
         Changed_Look (Item);
      end if;
   end Set_Value;

   function Value (Item : Select_Field) return String is
     (Item.Text (1 .. Item.Length));

   procedure Set_Open (Item : in out Select_Field; To : Boolean) is
   begin
      if To /= Item.Open then
         Item.Open := To;
         Changed_Look (Item);
      end if;
   end Set_Open;

   function Is_Open (Item : Select_Field) return Boolean is (Item.Open);

   procedure Set_Enabled (Item : in out Select_Field; To : Boolean) is
   begin
      if To /= Item.Enabled then
         Item.Enabled := To;
         Item.Down := False;
         Item.Clicked := False;
         Changed_Look (Item);
      end if;
   end Set_Enabled;

   function Is_Enabled (Item : Select_Field) return Boolean is
     (Item.Enabled);

   procedure Take_Click (Item : in out Select_Field; Clicked : out Boolean)
   is
   begin
      Clicked := Item.Clicked;
      Item.Clicked := False;
   end Take_Click;

   overriding procedure Handle
     (Item    : in out Select_Field;
      Event   : SDL3.Events.Event;
      Handled : out Boolean)
   is
      Over : constant Boolean :=
        Contains (Item, Event.Mouse_X * Density (Item),
                  Event.Mouse_Y * Density (Item));
   begin
      Handled := False;
      if not Item.Enabled then
         return;
      end if;
      case Event.Kind is
         when SDL3.Events.Mouse_Down =>
            if Event.Button = 1 and then Over then
               Item.Down := True;
               Handled := True;
               Invalidate (Item);
            end if;
         when SDL3.Events.Mouse_Up =>
            if Event.Button = 1 and then Item.Down then
               Item.Down := False;
               Item.Clicked := Over;
               if Over then
                  Notify (Item, Click);
               end if;
               Handled := True;
               Invalidate (Item);
            end if;
         when others =>
            null;
      end case;
   end Handle;

   overriding procedure Hover_Changed
     (Item : in out Select_Field; Hovered : Boolean)
   is
      pragma Unreferenced (Hovered);
   begin
      Invalidate (Item);
   end Hover_Changed;

   overriding function Cursor
     (Item : Select_Field) return SDL3.Cursors.Kind is
     (if Item.Enabled then SDL3.Cursors.Pointer else SDL3.Cursors.Default);

   overriding procedure Draw
     (Item   : in out Select_Field;
      Target : SDL3.Windows.Renderers.Renderer;
      Colors : Themes.Theme)
   is
      Pixels : constant Float := Density (Item);
      Edge   : constant Float := Pomarine.Boxes.Edge (Pixels);
      Left   : constant Float := Left_Of (Item);
      Top    : constant Float := Top_Of (Item);
      Wide   : constant Float := Width_Of (Item);
      High   : constant Float := Height_Of (Item);
      Ink    : constant Themes.Color :=
        (if Item.Enabled then Colors (Themes.Foreground) else Colors (Themes.Muted));
      Around : constant Float := Edge + Float'Rounding (Inner * Pixels);
      Side   : constant Float := Float'Max (0.0, High - 2.0 * Around);
      --  The button, square, with its shadow, inside the outline.
      Button_Left : constant Float := Left + Wide - Around - Side;
      Pressed : constant Boolean :=
        Item.Enabled
        and then (Item.Open or else (Item.Down and then Is_Hovered (Item)));
   begin
      Fill_Rect
        (Target, (if Item.Enabled then Themes.White else Colors (Themes.Tint)),
         Left, Top, Wide, High);
      Pomarine.Boxes.Outline
        (Target, (if Item.Open then Colors (Themes.Focus) else Colors (Themes.Border)),
         Left, Top, Wide, High, Edge);
      declare
         Face : constant Themes.Color :=
           Colors.Face_For
             (Enabled => Item.Enabled, Hovered => Is_Hovered (Item) and then not Pressed);
      begin
         Pomarine.Boxes.Draw_Control
           (Target, Colors, Face,
            (if Item.Enabled then Colors (Themes.Border)
             else Themes.Dull (Colors, Colors (Themes.Border))),
            (Themes.Highlight (Face), Themes.Shadow_Of (Face)),
            Button_Left, Top + Around, Side, Side, Pixels,
            Bevelled => Item.Enabled, Sunken => Pressed);
      end;
      if Icon_Library (Item) /= null then
         declare
            Size  : constant Positive :=
              Positive (Float'Rounding (Caret_Size * Pixels));
            Drawn : Boolean;
         begin
            Pomarine.Icons.Draw
              (Icon_Library (Item).all, Target,
               (if Item.Open then Pomarine.Icons.Chevron_Up
                else Pomarine.Icons.Chevron_Down),
               Ink,
               Float'Rounding (Button_Left + (Side - Float (Size)) / 2.0),
               Float'Rounding (Top + Around + (Side - Float (Size)) / 2.0),
               Size, Drawn);
         end;
      end if;
      if Item.Length > 0 and then Text_Lines (Item) /= null then
         Pomarine.Line_Texts.Draw
           (Text_Lines (Item).all, Target, Ink, Value (Item),
            Left + Pad * Pixels, Top + High / 2.0, Pixels);
      end if;
   end Draw;

end Pomarine.Widgets.Selects;
