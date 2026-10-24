with Ada.Strings.Fixed;
with Pomarine.Boxes;
package body Pomarine.Widgets.Sliders is

   use type Pomarine.Events.Key_Code;

   use type Semantics.Role;

   use type Pomarine.Events.Event_Kind;
   use all type SDL3.Painters.Painter;

   Knob_Points  : constant Float := 9.0;
   Track_Points : constant Float := 4.0;
   --  The knob's width, and the track's thickness, in points.

   function Knob_Width (Item : Slider) return Float is
     (Float'Min
        (Width_Of (Item), Float'Rounding (Knob_Points * Density (Item))));

   function Travel (Item : Slider) return Float is
     (Width_Of (Item) - Knob_Width (Item));
   --  How far the knob's left edge goes, in pixels.

   function Fraction_At (Item : Slider; X : Float) return Float is
     (if Travel (Item) <= 0.0 then 0.0
      else Float'Min
        (1.0,
         Float'Max
           (0.0,
            (X * Density (Item) - Left_Of (Item) - Knob_Width (Item) / 2.0)
            / Travel (Item))));
   --  Of the pointer at X, in points.

   function Value (Item : Slider) return Float is (Item.Fraction);

   procedure Set_Value (Item : in out Slider; To : Float) is
   begin
      if not Item.Held and then To /= Item.Fraction then
         Item.Fraction := To;
         if Is_Attached (Item) then
            Invalidate (Item);
         end if;
      end if;
   end Set_Value;

   procedure Take_Change (Item : in out Slider; Changed : out Boolean) is
   begin
      Changed := Item.Moved;
      Item.Moved := False;
   end Take_Change;

   function Is_Dragging (Item : Slider) return Boolean is (Item.Held);

   procedure Move_To (Item : in out Slider; X : Float);
   --  Put the knob under the pointer at X, in points.

   procedure Move_To (Item : in out Slider; X : Float) is
      To : constant Float := Fraction_At (Item, X);
   begin
      if To /= Item.Fraction then
         Item.Fraction := To;
         Item.Moved := True;
         Notify (Item, Change);
         Invalidate (Item);
      end if;
   end Move_To;

   overriding procedure Handle
     (Item    : in out Slider;
      Event   : Pomarine.Events.Event;
      Handled : out Boolean) is
   begin
      Handled := False;
      case Event.Kind is
         when Pomarine.Events.Mouse_Down =>
            if Event.Button = 1
              and then Contains
                         (Item, Event.Mouse_X * Density (Item),
                          Event.Mouse_Y * Density (Item))
            then
               Item.Held := True;
               Move_To (Item, Event.Mouse_X);
               Handled := True;
            end if;
         when Pomarine.Events.Mouse_Move =>
            if Item.Held then
               Move_To (Item, Event.Mouse_X);
               Handled := True;
            end if;
         when Pomarine.Events.Mouse_Up =>
            if Item.Held and then Event.Button = 1 then
               Item.Held := False;
               Invalidate (Item);
               Handled := True;
            end if;
         when Pomarine.Events.Key_Down =>
            if Has_Focus (Item) and then not Event.Command then
               if Event.Key = Pomarine.Events.Key_Right_Arrow
                 or else Event.Key = Pomarine.Events.Key_Up_Arrow
               then
                  Perform (Item, (Doing => Semantics.Increment, others => <>), Handled);
               elsif Event.Key = Pomarine.Events.Key_Left_Arrow
                 or else Event.Key = Pomarine.Events.Key_Down_Arrow
               then
                  Perform (Item, (Doing => Semantics.Decrement, others => <>), Handled);
               elsif Event.Key = Pomarine.Events.Key_Home then
                  Perform (Item, (Doing => Semantics.Set_Value, Number => 0.0, others => <>), Handled);
               elsif Event.Key = Pomarine.Events.Key_End then
                  Perform (Item, (Doing => Semantics.Set_Value, Number => 1.0, others => <>), Handled);
               end if;
            end if;
         when others =>
            null;
      end case;
   end Handle;

   overriding procedure Hover_Changed
     (Item : in out Slider; Hovered : Boolean)
   is
      pragma Unreferenced (Hovered);
   begin
      Invalidate (Item);
   end Hover_Changed;

   overriding function Cursor (Item : Slider) return SDL3.Cursors.Kind is
     (SDL3.Cursors.Pointer);

   overriding procedure Draw
     (Item   : in out Slider;
      Target : SDL3.Painters.Painter'Class;
      Colors : Themes.Theme)
   is
      Pixels : constant Float := Density (Item);
      Left   : constant Float := Left_Of (Item);
      High   : constant Float := Height_Of (Item);
      Thick  : constant Float :=
        Float'Max (2.0, Float'Rounding (Track_Points * Pixels));
      Wide   : constant Float := Knob_Width (Item);
      Knob   : constant Float :=
        Float'Rounding (Left + Item.Fraction * Travel (Item));
      Groove : constant Themes.Color :=
        Themes.Mix (Colors (Themes.Background), Colors (Themes.Foreground), 0.12);
      Groove_Top : constant Float :=
        Top_Of (Item) + Float'Rounding ((High - Thick) / 2.0);
   begin
      --  The groove, the light falling into it from the top left.
      Fill_Rect (Target, Groove, Left, Groove_Top, Width_Of (Item), Thick);
      if Colors.Bevelled then
         Pomarine.Boxes.Bevel
           (Target, Themes.Highlight (Groove), Themes.Shadow_Of (Groove), Left,
            Groove_Top, Width_Of (Item), Thick, Pixels, Sunken => True);
      end if;
      declare
         Face : constant Themes.Color :=
           Colors.Face_For (Hovered => Is_Hovered (Item) and then not Item.Held);
      begin
         Pomarine.Boxes.Draw_Control
           (Target, Colors, Face, Colors (Themes.Border),
            (Themes.Highlight (Face), Themes.Shadow_Of (Face)),
            Knob, Top_Of (Item), Wide, High, Pixels, Sunken => Item.Held);
      end;
   end Draw;

   Key_Step : constant := 0.05;
   --  How far Increment and Decrement move it, of the whole.

   overriding procedure Describe
     (Item  : Slider;
      Facts : in out Semantics.Description) is
   begin
      if Facts.Kind = Semantics.Unknown then
         Facts.Kind := Semantics.Slider;
      end if;
      Facts.Has_Number := True;
      Facts.Number := Item.Fraction;
      Facts.Minimum := 0.0;
      Facts.Maximum := 1.0;
      Facts.Step := Key_Step;
      Semantics.Value_As
        (Facts, Ada.Strings.Fixed.Trim
                  (Integer'Image (Integer (Item.Fraction * 100.0)), Ada.Strings.Left) & "%");
      Facts.Actions (Semantics.Increment) := True;
      Facts.Actions (Semantics.Decrement) := True;
      Facts.Actions (Semantics.Set_Value) := True;
   end Describe;

   overriding procedure Perform
     (Item    : in out Slider;
      Request : Semantics.Request;
      Done    : out Boolean)
   is
      To : Float := Item.Fraction;
   begin
      Done := True;
      case Request.Doing is
         when Semantics.Increment => To := Item.Fraction + Key_Step;
         when Semantics.Decrement => To := Item.Fraction - Key_Step;
         when Semantics.Set_Value => To := Request.Number;
         when others => Done := False;
      end case;
      if Done then
         To := Float'Max (0.0, Float'Min (1.0, To));
         if To /= Item.Fraction then
            Item.Fraction := To;
            Item.Moved := True;
            Notify (Item, Change);
            Invalidate (Item);
         end if;
      end if;
   end Perform;

   procedure Set_Focusable (Item : in out Slider; To : Boolean) is
   begin
      Item.Focusable := To;
      if not To and then Is_Attached (Item) and then Has_Focus (Item) then
         Release_Focus (Item);
      end if;
   end Set_Focusable;

   overriding function Accepts_Focus (Item : Slider) return Boolean is
     (Item.Focusable);

   overriding procedure Focus_Changed
     (Item : in out Slider; Focused : Boolean)
   is
      pragma Unreferenced (Focused);
   begin
      Invalidate (Item);
   end Focus_Changed;

   overriding procedure Draw_Over
     (Item   : in out Slider;
      Target : SDL3.Painters.Painter'Class;
      Colors : Themes.Theme) is
   begin
      if Item.Focusable and then Is_Focus_Visible (Item) then
         Pomarine.Boxes.Outline
           (Target, Colors (Themes.Focus),
            Left_Of (Item), Top_Of (Item), Width_Of (Item), Height_Of (Item),
            Thick => Float'Max (1.0, Float'Rounding (2.0 * Density (Item))),
            Density => Density (Item));
      end if;
   end Draw_Over;

end Pomarine.Widgets.Sliders;
