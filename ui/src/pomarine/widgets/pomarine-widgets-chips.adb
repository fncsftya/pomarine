with Pomarine.Boxes;
with Pomarine.Icons;

package body Pomarine.Widgets.Chips is

   use type Semantics.Action;
   use type Semantics.Role;

   use type Pomarine.Events.Event_Kind;
   use all type SDL3.Painters.Painter;

   --  In points
   Pad         : constant Float := 6.0;
   Gap         : constant Float := 6.0;
   Swatch_Size : constant Float := 8.0;
   Cross_Size  : constant Float := 14.0;
   Cross_Icon  : constant Float := 8.0;
   Cross_Inset : constant Float := 3.0;  --  from the right and the top

   procedure Changed_Look (Item : in out Chip);

   procedure Changed_Look (Item : in out Chip) is
   begin
      if Is_Attached (Item) then
         Invalidate (Item);
      end if;
   end Changed_Look;

   procedure Set_Label (Item : in out Chip; Text : String) is
   begin
      if Text /= Label (Item) then
         Item.Text := Ada.Strings.Unbounded.To_Unbounded_String (Text);
         Changed_Look (Item);
      end if;
   end Set_Label;

   function Label (Item : Chip) return String
   is (Ada.Strings.Unbounded.To_String (Item.Text));

   procedure Set_Swatch (Item : in out Chip; To : Themes.Slot) is
   begin
      Item.Swatched := True;
      Item.Swatch := To;
      Changed_Look (Item);
   end Set_Swatch;

   procedure Cross_Box (Item : Chip; Left, Top, Side : out Float);
   --  Where the cross's button is, in pixels, with its shadow.

   procedure Cross_Box (Item : Chip; Left, Top, Side : out Float) is
      Pixels : constant Float := Density (Item);
   begin
      Side := Float'Rounding (Cross_Size * Pixels);
      Left := Float'Rounding (Left_Of (Item) + Width_Of (Item) - Cross_Inset * Pixels - Side);
      Top := Float'Rounding (Top_Of (Item) + (Height_Of (Item) - Side) / 2.0);
   end Cross_Box;

   function On_Cross (Item : Chip; X, Y : Float) return Boolean is
      Left, Top, Side : Float;
   begin
      Cross_Box (Item, Left, Top, Side);
      return X in Left .. Left + Side and then Y in Top .. Top + Side;
   end On_Cross;

   overriding
   procedure Handle (Item : in out Chip; Event : Pomarine.Events.Event; Handled : out Boolean) is
      X    : constant Float := Event.Mouse_X * Density (Item);
      Y    : constant Float := Event.Mouse_Y * Density (Item);
      Over : constant Boolean := On_Cross (Item, X, Y);
   begin
      Handled := False;
      case Event.Kind is
         when Pomarine.Events.Mouse_Move =>
            if Over /= Item.Over then
               Item.Over := Over;
               Invalidate (Item);
            end if;

         when Pomarine.Events.Mouse_Down =>
            if Event.Button = 1 and then Over then
               Item.Down := True;
               Handled := True;
               Invalidate (Item);
            end if;

         when Pomarine.Events.Mouse_Up   =>
            if Event.Button = 1 and then Item.Down then
               Item.Down := False;
               if Over then
                  Notify (Item, Close);
               end if;
               Handled := True;
               Invalidate (Item);
            end if;

         when others                     =>
            null;
      end case;
   end Handle;

   overriding
   procedure Hover_Changed (Item : in out Chip; Hovered : Boolean) is
   begin
      if not Hovered and then Item.Over then
         Item.Over := False;
         Invalidate (Item);
      end if;
   end Hover_Changed;

   overriding
   procedure Draw (Item : in out Chip; Target : SDL3.Painters.Painter'Class; Colors : Themes.Theme) is
      Pixels          : constant Float := Density (Item);
      Middle          : constant Float := Top_Of (Item) + Height_Of (Item) / 2.0;
      After           : Float := Left_Of (Item) + Pad * Pixels;
      Left, Top, Side : Float;
   begin
      Pomarine.Boxes.Draw_Flat
        (Target,
         Colors (Themes.Page),
         Colors (Themes.Border),
         Left_Of (Item),
         Top_Of (Item),
         Width_Of (Item),
         Height_Of (Item),
         Pixels,
         Radius => Themes.Small_Radius);
      if Item.Swatched then
         declare
            Size : constant Float := Float'Rounding (Swatch_Size * Pixels);
         begin
            Fill_Rect
              (Target,
               Themes.Resolve (Colors, Item.Swatch),
               Float'Rounding (After),
               Float'Rounding (Middle - Size / 2.0),
               Size,
               Size);
            After := After + Size + Gap * Pixels;
         end;
      end if;
      if Ada.Strings.Unbounded.Length (Item.Text) > 0 and then Text_Lines (Item) /= null then
         Pomarine.Line_Texts.Draw
           (Text_Lines (Item).all, Target, Colors (Themes.Foreground), Label (Item), After, Middle, Pixels);
      end if;
      Cross_Box (Item, Left, Top, Side);
      declare
         Face : constant Themes.Color := Colors.Face_For (Hovered => Item.Over and then not Item.Down);
      begin
         Pomarine.Boxes.Draw_Control
           (Target,
            Colors,
            Face,
            Colors (Themes.Border),
            (Themes.Highlight (Face), Themes.Shadow_Of (Face)),
            Left,
            Top,
            Side,
            Side,
            Pixels,
            Sunken => Item.Down and then Item.Over,
            Radius => Themes.Small_Radius - 1.0);
      end;
      if Icon_Library (Item) /= null then
         declare
            Size  : constant Positive := Positive (Float'Rounding (Cross_Icon * Pixels));
            Drawn : Boolean;
         begin
            Pomarine.Icons.Draw
              (Icon_Library (Item).all,
               Target,
               Pomarine.Icons.Close,
               Colors (Themes.Foreground),
               Float'Rounding (Left + (Side - Float (Size)) / 2.0),
               Float'Rounding (Top + (Side - Float (Size)) / 2.0),
               Size,
               Drawn);
         end;
      end if;
   end Draw;

   overriding
   procedure Describe (Item : Chip; Facts : in out Semantics.Description) is
   begin
      if Facts.Kind = Semantics.Unknown then
         Facts.Kind := Semantics.Group;
      end if;
      Semantics.Name_As (Facts, Label (Item));
   end Describe;

   overriding
   procedure Describe_Part
     (Item : Chip; Part : Positive; Facts : in out Semantics.Description; Bounds : out Semantics.Rectangle)
   is
      pragma Unreferenced (Part);
   begin
      Facts.Kind := Semantics.Button;
      Semantics.Name_As (Facts, "close " & Label (Item));
      Facts.Actions (Semantics.Click) := True;
      --  The cross is at the right end.
      Bounds :=
        (Left   => Left_Of (Item) + Width_Of (Item) - Height_Of (Item),
         Top    => Top_Of (Item),
         Right  => Left_Of (Item) + Width_Of (Item),
         Bottom => Top_Of (Item) + Height_Of (Item));
   end Describe_Part;

   overriding
   procedure Perform_Part (Item : in out Chip; Part : Positive; Request : Semantics.Request; Done : out Boolean) is
      pragma Unreferenced (Part);
   begin
      Done := Request.Doing = Semantics.Click;
      if Done then
         Notify (Item, Close);
         Invalidate (Item);
      end if;
   end Perform_Part;

end Pomarine.Widgets.Chips;
