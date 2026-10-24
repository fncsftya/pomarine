with SDL3.Windows;
with SDL3.Windows.Renderers;
with Ada.Strings.Fixed;
with Pomarine.Boxes;
package body Pomarine.Widgets.Buttons is

   use type Semantics.Action;
   use type Semantics.Role;

   use type Pomarine.Events.Event_Kind;
   use type Pomarine.Events.Key_Code;
   use SDL3.Windows.Renderers;
   use all type SDL3.Painters.Painter;

   Icon_Size : constant := 16.0;  --  in points, a side
   Caption_Gap : constant := 7.0;  --  between an icon and its label
   Icon_Pad : constant := 10.0;  --  in points, from the edge to a leading icon
   Badge_Size : constant := 16.0;  --  in points, a side
   Badge_Gap  : constant := 6.0;   --  between the label and the badge
   Caret_Size : constant := 10.0;  --  in points, a side, of a dropdown's
   Ring_Width : constant := 2.0;   --  in points, of the ring of the focus
   White : constant Themes.Color := Themes.Soft_White;
   --  For an icon on a button of a colour of its own.

   procedure Set_Label (Item : in out Button; Text : String) is
   begin
      if Text /= Label (Item) then
         Item.Length := Text'Length;
         Item.Text (1 .. Item.Length) := Text;
         if Is_Attached (Item) then
            Invalidate (Item);
         end if;
      end if;
   end Set_Label;

   procedure Set_Label_Style
     (Item : in out Button; Using : Line_Texts.Style; Underlined, Struck : Boolean := False)
   is
   begin
      Item.Label_Style := Using;
      Item.Underlined := Underlined;
      Item.Struck := Struck;
      if Is_Attached (Item) then
         Invalidate (Item);
      end if;
   end Set_Label_Style;

   function Looks
     (Caption     : String := "";
      Of_Kind     : Kind := Normal;
      Icon        : Pomarine.Icons.Optional := Pomarine.Icons.No_Icon;
      Icon_Points : Float := 0.0;
      Captioned   : Boolean := False;
      Shape       : Shape_Kind := Plain;
      Focusable   : Boolean := False;
      Label_Style : Line_Texts.Style := Line_Texts.Strong;
      Underlined  : Boolean := False;
      Struck      : Boolean := False) return Settings
   is
   begin
      return Result : Settings do
         Result.Length := Caption'Length;
         Result.Text (1 .. Caption'Length) := Caption;
         Result.Style := Of_Kind;
         Result.Label_Style := Label_Style;
         Result.Underlined := Underlined;
         Result.Struck := Struck;
         Result.Icon := Icon;
         Result.Icon_Points := Icon_Points;
         Result.Captioned := Captioned;
         Result.Shape := Shape;
         Result.Focusable := Focusable;
      end return;
   end Looks;

   procedure Configure (Item : in out Button; Using : Settings) is
      use type Pomarine.Icons.Optional;
   begin
      Set_Label (Item, Using.Text (1 .. Using.Length));
      Set_Kind (Item, Using.Style);
      Set_Label_Style (Item, Using.Label_Style, Using.Underlined, Using.Struck);
      if Using.Icon = Pomarine.Icons.No_Icon then
         if Item.Picture then
            Item.Picture := False;
            if Is_Attached (Item) then
               Invalidate (Item);
            end if;
         end if;
      else
         Set_Icon (Item, Pomarine.Icons.Icon_Of (Using.Icon));
      end if;
      if Item.Icon_Points /= Using.Icon_Points then
         Item.Icon_Points := Using.Icon_Points;
         if Is_Attached (Item) then
            Invalidate (Item);
         end if;
      end if;
      Set_Captioned (Item, Using.Captioned);
      Set_Shape (Item, Using.Shape);
      Set_Focusable (Item, Using.Focusable);
   end Configure;

   procedure Add
     (Parent : in out Widget'Class;
      Item   : in out Button;
      Using  : Settings;
      Box    : Layouts.Style := (others => <>))
   is
   begin
      Layouts.Add (Parent, Item, Box);
      Configure (Item, Using);
   end Add;

   procedure Set_Kind (Item : in out Button; To : Kind) is
   begin
      if To /= Item.Style then
         Item.Style := To;
         if Is_Attached (Item) then
            Invalidate (Item);
         end if;
      end if;
   end Set_Kind;

   procedure Set_Icon (Item : in out Button; To : Pomarine.Icons.Icon) is
      use type Pomarine.Icons.Icon;
   begin
      if not Item.Picture or else Item.Which /= To then
         Item.Picture := True;
         Item.Which := To;
         if Is_Attached (Item) then
            Invalidate (Item);
         end if;
      end if;
   end Set_Icon;

   procedure Set_Icon_Size (Item : in out Button; Points : Float) is
   begin
      if Item.Icon_Points /= Points then
         Item.Icon_Points := Points;
         if Is_Attached (Item) then
            Invalidate (Item);
         end if;
      end if;
   end Set_Icon_Size;

   procedure Set_Swatch (Item : in out Button; To : Themes.Slot) is
   begin
      Item.Swatched := True;
      Item.Swatch := To;
      if Is_Attached (Item) then
         Invalidate (Item);
      end if;
   end Set_Swatch;

   function Has_Icon (Item : Button) return Boolean is (Item.Picture);

   procedure Set_Badge (Item : in out Button; Count : Natural) is
   begin
      if Count /= Item.Badge then
         Item.Badge := Count;
         if Is_Attached (Item) then
            Invalidate (Item);
         end if;
      end if;
   end Set_Badge;

   procedure Set_Captioned (Item : in out Button; To : Boolean) is
   begin
      if To /= Item.Captioned then
         Item.Captioned := To;
         if Is_Attached (Item) then
            Invalidate (Item);
         end if;
      end if;
   end Set_Captioned;

   procedure Set_Selected (Item : in out Button; To : Boolean) is
   begin
      if To /= Item.Selected then
         Item.Selected := To;
         if Is_Attached (Item) then
            Invalidate (Item);
         end if;
      end if;
   end Set_Selected;

   function Is_Selected (Item : Button) return Boolean is (Item.Selected);

   procedure Set_Shape (Item : in out Button; To : Shape_Kind) is
   begin
      if To /= Item.Shape then
         Item.Shape := To;
         Item.Over_Caret := False;
         Item.Down_Caret := False;
         if Is_Attached (Item) then
            Invalidate (Item);
         end if;
      end if;
   end Set_Shape;

   function Shape_Of (Item : Button) return Shape_Kind is (Item.Shape);

   procedure Set_Dropdown (Item : in out Button; To : Boolean) is
   begin
      Set_Shape (Item, (if To then Dropdown else Plain));
   end Set_Dropdown;

   function Is_Dropdown (Item : Button) return Boolean is (Item.Shape /= Plain);

   function Caret_Clicked (Item : Button) return Boolean is (Item.Last_Caret);

   procedure Set_Enabled (Item : in out Button; To : Boolean) is
   begin
      if To /= Item.Enabled then
         Item.Enabled := To;
         if not To then
            Item.Down := False;
            Item.Clicked := False;
            if Is_Attached (Item) and then Has_Focus (Item) then
               Release_Focus (Item);
            end if;
         end if;
         if Is_Attached (Item) then
            Invalidate (Item);
         end if;
      end if;
   end Set_Enabled;

   function Is_Enabled (Item : Button) return Boolean is (Item.Enabled);

   procedure Set_Focusable (Item : in out Button; To : Boolean) is
   begin
      Item.Focusable := To;
      if not To and then Is_Attached (Item) and then Has_Focus (Item) then
         Release_Focus (Item);
      end if;
   end Set_Focusable;

   overriding function Accepts_Focus (Item : Button) return Boolean is
     (Item.Focusable and then Item.Enabled);

   overriding procedure Focus_Changed
     (Item : in out Button; Focused : Boolean)
   is
      pragma Unreferenced (Focused);
   begin
      Invalidate (Item);
   end Focus_Changed;

   function Kind_Of (Item : Button) return Kind is (Item.Style);

   function Label (Item : Button) return String is
     (Item.Text (1 .. Item.Length));

   procedure Take_Click (Item : in out Button; Clicked : out Boolean) is
   begin
      Clicked := Item.Clicked;
      Item.Clicked := False;
   end Take_Click;

   function Is_Pressed (Item : Button) return Boolean is
     (Item.Down and then Is_Hovered (Item));

   overriding procedure Handle
     (Item    : in out Button;
      Event   : Pomarine.Events.Event;
      Handled : out Boolean)
   is
      Over : constant Boolean :=
        Contains (Item, Event.Mouse_X * Density (Item),
                  Event.Mouse_Y * Density (Item));
      On_Caret : constant Boolean :=
        Item.Shape = Split_Dropdown and then Over
        and then Event.Mouse_X * Density (Item) >= Left_Of (Item) + Width_Of (Item)
                                                     - Float'Rounding (Height_Of (Item));
   begin
      Handled := False;
      if not Item.Enabled then
         return;
      end if;
      if Event.Kind in Pomarine.Events.Mouse_Move | Pomarine.Events.Mouse_Down
        and then On_Caret /= Item.Over_Caret
      then
         Item.Over_Caret := On_Caret;
         Invalidate (Item);
      end if;
      case Event.Kind is
         when Pomarine.Events.Key_Down =>
            --  Only with the focus: keys come to others as shortcuts.
            if Has_Focus (Item)
              and then (Event.Key = Pomarine.Events.Key_Return
                        or else Event.Key = Pomarine.Events.Key_Space)
              and then not Event.Command
            then
               Item.Clicked := True;
               Item.Last_Caret := False;
               Notify (Item, Click);
               Handled := True;
            end if;
         when Pomarine.Events.Mouse_Down =>
            if Event.Button = 1 and then Over then
               Item.Down := True;
               Item.Down_Caret := On_Caret;
               Handled := True;
               Invalidate (Item);
            end if;
         when Pomarine.Events.Mouse_Up =>
            if Event.Button = 1 and then Item.Down then
               Item.Down := False;
               Item.Clicked := Over;
               if Over then
                  Item.Last_Caret := Item.Down_Caret and then On_Caret;
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
     (Item : in out Button; Hovered : Boolean)
   is
   begin
      if not Hovered then
         Item.Over_Caret := False;
      end if;
      Invalidate (Item);
   end Hover_Changed;

   overriding function Cursor (Item : Button) return SDL3.Cursors.Kind is
     (if Item.Enabled then SDL3.Cursors.Pointer else SDL3.Cursors.Default);

   function Label_Span (Item : Button; Wide : Float) return Float;
   --  Of the label, in pixels, as it is drawn: in the one style every
   --  button's label has, whatever else is on the button.

   function Label_Span (Item : Button; Wide : Float) return Float is
     (if Item.Length = 0 then 0.0
      elsif Text_Lines (Item) /= null
      then Pomarine.Line_Texts.Width
             (Text_Lines (Item).all, Label (Item), Density (Item),
              Item.Label_Style)
      else Wide);

   overriding procedure Draw
     (Item   : in out Button;
      Target : SDL3.Painters.Painter'Class;
      Colors : Themes.Theme)
   is
      Pixels  : constant Float := Density (Item);
      Edge    : constant Float := Pomarine.Boxes.Edge (Pixels);
      Apart   : constant Boolean := Item.Shape = Split_Dropdown and then Item.Style /= Quiet;
      --  The caret is a button of its own: it and the rest are each pressed or hovered.
      Pressed_All : constant Boolean := Item.Enabled and then Is_Pressed (Item);
      Hovered_All : constant Boolean := Item.Enabled and then Is_Hovered (Item);
      Pressed : constant Boolean := Pressed_All and then not (Apart and then Item.Down_Caret);
      Hovered : constant Boolean := Hovered_All and then not (Apart and then Item.Over_Caret);
      Caret_Pressed : constant Boolean := Apart and then Pressed_All and then Item.Down_Caret;
      Caret_Hovered : constant Boolean := Apart and then Hovered_All and then Item.Over_Caret;
      Toggled : constant Boolean := Item.Selected and then Item.Shape = Plain;
      --  Pressed in, in the accent; an open dropdown is in its own face.
      Tone  : constant Themes.Tone :=
        (case Item.Style is
            when Primary => Themes.Primary_Tone,
            when Danger  => Themes.Danger_Tone,
            when Quiet   => Themes.Quiet_Tone,
            when Warning => Themes.Warning_Tone,
            when Normal  =>
              (if Toggled then Themes.Selected_Tone else Themes.Normal_Tone));
      Face  : constant Themes.Color :=
        Colors.Face_For
          (Tone, Enabled => Item.Enabled, Hovered => Hovered, Held => Pressed);
      Edges : constant Themes.Bevel_Colors :=
        Colors.Bevel_For (Tone, Hovered => Hovered, Held => Pressed);
      Ink   : constant Themes.Color :=
        Colors.Ink_For
          (Tone, Enabled => Item.Enabled,
           Hovered => Hovered or else (Item.Style = Quiet and then Item.Selected));
      Edge_Color : constant Themes.Color :=
        Colors.Edge_For (Tone, Enabled => Item.Enabled);
      Caret_Face : constant Themes.Color :=
        Colors.Face_For
          (Tone, Enabled => Item.Enabled, Hovered => Caret_Hovered, Held => Caret_Pressed);
      Caret_Edges : constant Themes.Bevel_Colors :=
        Colors.Bevel_For (Tone, Hovered => Caret_Hovered, Held => Caret_Pressed);
      Caret_Ink : constant Themes.Color :=
        Colors.Ink_For (Tone, Enabled => Item.Enabled, Hovered => Caret_Hovered);
      Left, Top, Wide_Box, High_Box : Float;
      --  The face, which what is on it goes with.
      Caret_Room : Float := 0.0;
      Icon_Drawn : Boolean := False;
      Text_Left  : Float := 0.0;
      Scale : constant Positive :=
        Positive (Float'Max (1.0, Float'Rounding (Pixels)));
      Wide  : constant Float :=
        Float (Item.Length * Debug_Text_Size * Scale);
      High  : constant Float := Float (Debug_Text_Size * Scale);
      Span  : constant Float := Label_Span (Item, Wide);
      Together : constant Boolean :=
        Item.Picture and then Item.Captioned and then Item.Length > 0;
      Badged : constant Boolean :=
        Item.Badge > 0 and then Item.Length > 0
        and then Text_Lines (Item) /= null;
      Badge_Room : constant Float :=
        (if Badged then (Badge_Gap + Badge_Size) * Pixels else 0.0);
   begin
      Left := Left_Of (Item);
      Top := Top_Of (Item);
      Wide_Box := Width_Of (Item);
      High_Box := Height_Of (Item);
      if Apart then
         declare
            Room : constant Float := Float'Rounding (High_Box);
         begin
            Pomarine.Boxes.Draw_Control
              (Target, Colors, Face, Edge_Color, Edges, Left, Top, Wide_Box - Room, High_Box, Pixels,
               Bevelled => Item.Enabled, Sunken => Pressed, Radius => Themes.Small_Radius,
               Round => Pomarine.Boxes.Left_Corners);
            Pomarine.Boxes.Draw_Control
              (Target, Colors, Caret_Face, Edge_Color, Caret_Edges, Left + Wide_Box - Room, Top, Room,
               High_Box, Pixels,
               Bevelled => Item.Enabled, Sunken => Caret_Pressed or else Item.Selected,
               Radius => Themes.Small_Radius, Round => Pomarine.Boxes.Right_Corners);
         end;
      elsif Item.Style /= Quiet then
         Pomarine.Boxes.Draw_Control
           (Target, Colors, Face, Edge_Color, Edges, Left, Top, Wide_Box, High_Box, Pixels,
            Bevelled => Item.Enabled, Sunken => Pressed or else Item.Selected,
            Radius => Themes.Small_Radius);
      end if;
      --  The ring of the focus: of a quiet button too, which has no face.
      if Item.Focusable and then Is_Focus_Visible (Item) then
         Pomarine.Boxes.Outline
           (Target, Colors (Themes.Focus), Left, Top, Wide_Box, High_Box,
            Float'Max (1.0, Float'Rounding (Ring_Width * Pixels)),
            Density => Pixels, Radius => Themes.Small_Radius);
      end if;

      --  A dropdown's caret, in a square of its own at the right, a groove
      --  between it and the rest; up while it is open.
      if Item.Shape /= Plain and then Item.Style /= Quiet then
         Caret_Room := Float'Rounding (High_Box);
         declare
            Line : constant Float := Left + Wide_Box - Caret_Room;
            Size : constant Positive :=
              Positive (Float'Rounding (Caret_Size * Pixels));
            Drawn : Boolean;
         begin
            if not Apart then
               Fill_Rect
                 (Target, Themes.Shadow_Of (Face), Line, Top + 2.0 * Edge, Edge,
                  High_Box - 4.0 * Edge);
               Fill_Rect
                 (Target, Themes.Highlight (Face), Line + Edge, Top + 2.0 * Edge,
                  Edge, High_Box - 4.0 * Edge);
            end if;
            if Icon_Library (Item) /= null then
               Icons.Draw
                 (Icon_Library (Item).all, Target,
                  (if Item.Selected then Pomarine.Icons.Chevron_Up
                   else Pomarine.Icons.Chevron_Down),
                  (if Apart then Caret_Ink else Ink),
                  Float'Rounding
                    (Line + Edge + (Caret_Room - Edge - Float (Size)) / 2.0),
                  Float'Rounding (Top + (High_Box - Float (Size)) / 2.0),
                  Size, Drawn);
            end if;
         end;
         Wide_Box := Wide_Box - Caret_Room;
      end if;

      --  The icon, if there is one, and the label: the icon leading, the
      --  label centred on the face, if it is captioned; otherwise the
      --  icon alone in the middle, or the label only where the icon
      --  cannot be drawn.
      if Item.Swatched then
         declare
            Side : constant Float := 10.0 * Pixels;
         begin
            Fill_Rect
              (Target, Themes.Resolve (Colors, Item.Swatch),
               Float'Rounding (Left + (Wide_Box - Side) / 2.0),
               Float'Rounding (Top + (High_Box - Side) / 2.0),
               Side, Side);
            Icon_Drawn := True;
         end;
      elsif Item.Picture and then Icon_Library (Item) /= null then
         declare
            Points : constant Float :=
              (if Item.Icon_Points > 0.0 then Item.Icon_Points else Icon_Size);
            Size : constant Positive :=
              Positive (Float'Rounding (Points * Pixels));
            Group_Left : constant Float :=
              (if Together then Left + Icon_Pad * Pixels
               else Left + (Wide_Box - Float (Size)) / 2.0);
            Drawn : Boolean;
         begin
            Icons.Draw
              (Icon_Library (Item).all, Target,
               Item.Which, Ink,
               Float'Rounding (Group_Left),
               Float'Rounding (Top + (High_Box - Float (Size)) / 2.0),
               Size, Drawn);
            Icon_Drawn := Drawn;
            --  The label is centred on the face, not on what is left
            --  of it, but never over the icon.
            Text_Left :=
              Float'Max
                (Left + (Wide_Box - Span) / 2.0,
                 Group_Left + (Points + Caption_Gap) * Pixels);
         end;
      end if;
      if Item.Length > 0 and then (Together or else not Icon_Drawn) then
         if not (Together and then Icon_Drawn) then
            Text_Left := Left + (Wide_Box - Span - Badge_Room) / 2.0;
         end if;
         if Text_Lines (Item) /= null then
            Pomarine.Line_Texts.Draw
              (Text_Lines (Item).all, Target, Ink, Label (Item),
               Text_Left, Top + High_Box / 2.0,
               Pixels, Item.Label_Style);
            if Item.Underlined then
               Fill_Rect (Target, Ink, Text_Left, Top + High_Box / 2.0 + 6.0 * Pixels, Span, Pixels);
            end if;
            if Item.Struck then
               Fill_Rect (Target, Ink, Text_Left, Top + High_Box / 2.0, Span, Pixels);
            end if;
         else
            Draw_Text
              (Target, Ink, Float'Rounding (Text_Left),
               Float'Rounding (Top + (High_Box - High) / 2.0),
               Label (Item), Scale);
         end if;
         --  The count, white in a dark square, after the label.
         if Badged then
            declare
               Count : constant String :=
                 Ada.Strings.Fixed.Trim (Item.Badge'Image, Ada.Strings.Both);
               Side  : constant Float := Float'Rounding (Badge_Size * Pixels);
               Left_Edge : constant Float :=
                 Float'Rounding (Text_Left + Span + Badge_Gap * Pixels);
               Top_Edge  : constant Float :=
                 Float'Rounding (Top + (High_Box - Side) / 2.0);
            begin
               Fill_Rect
                 (Target,
                  (if Item.Enabled then Colors (Themes.Bar)
                   else Themes.Dull (Colors, Colors (Themes.Bar))),
                  Left_Edge, Top_Edge, Side, Side);
               Pomarine.Line_Texts.Draw
                 (Text_Lines (Item).all, Target, White, Count,
                  Left_Edge + (Side - Pomarine.Line_Texts.Width
                                        (Text_Lines (Item).all, Count, Pixels,
                                         Item.Label_Style)) / 2.0,
                  Top_Edge + Side / 2.0, Pixels, Item.Label_Style);
            end;
         end if;
      end if;
   end Draw;

   function Icon_Words (Item : Button) return String;
   --  What a button of a picture alone is called: the name of the
   --  picture's file, without its extension, as words.

   function Icon_Words (Item : Button) return String is
      Library : constant Icons_Access := Icon_Library (Item);
   begin
      if Library = null then
         return "";
      end if;
      declare
         File : constant String := Pomarine.Icons.File_Name (Library.all, Item.Which);
         Stop : constant Natural :=
           Ada.Strings.Fixed.Index (File, ".", Ada.Strings.Backward);
         Stem : String :=
           (if Stop > 0 then File (File'First .. Stop - 1) else File);
      begin
         for C of Stem loop
            if C = '_' or else C = '-' then
               C := ' ';
            end if;
         end loop;
         return Stem;
      end;
   end Icon_Words;

   overriding procedure Describe
     (Item  : Button;
      Facts : in out Semantics.Description) is
   begin
      if Facts.Kind = Semantics.Unknown then
         Facts.Kind := Semantics.Button;
      end if;
      if Item.Length > 0 then
         Semantics.Name_As (Facts, Label (Item));
      elsif Item.Picture then
         Semantics.Name_As (Facts, Icon_Words (Item));
      end if;
      if Item.Badge > 0 then
         Semantics.Help_As
           (Facts, Ada.Strings.Fixed.Trim (Natural'Image (Item.Badge), Ada.Strings.Left));
      end if;
      Facts.Disabled := not Item.Enabled;
      Facts.Selected := Item.Selected;
      Facts.Focusable := Item.Focusable and then Item.Enabled;
      if Item.Shape /= Plain then
         Facts.Has_Expanded := True;
         Facts.Expanded := Item.Selected;
      end if;
      Facts.Actions (Semantics.Click) := Item.Enabled;
      Facts.Actions (Semantics.Focus) := Facts.Focusable;
   end Describe;

   overriding procedure Perform
     (Item    : in out Button;
      Request : Semantics.Request;
      Done    : out Boolean) is
   begin
      Done := False;
      if Request.Doing = Semantics.Click and then Item.Enabled then
         Item.Clicked := True;
         Item.Last_Caret := False;
         Notify (Item, Click);
         Invalidate (Item);
         Done := True;
      end if;
   end Perform;

   overriding procedure Command_State_Changed
     (Item : in out Button; State : Command_State) is
   begin
      Set_Enabled (Item, State in Enabled | Ticked);
      if State = Ticked then
         Item.By_Command := True;
         Set_Selected (Item, True);
      elsif Item.By_Command then
         Item.By_Command := False;
         Set_Selected (Item, False);
      end if;
   end Command_State_Changed;

end Pomarine.Widgets.Buttons;
