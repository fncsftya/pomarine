with Pomarine.Boxes;
with Pomarine.Line_Texts;
with Pomarine.Widgets.Layouts;
package body Pomarine.Widgets.Steppers is

   use type Semantics.Action;
   use type Semantics.Role;
   use type Pomarine.Events.Event_Kind;
   use type Pomarine.Events.Key_Code;

   Button_Share : constant Float := 1.0;
   --  Of the box's height: the side of each of its two buttons, inside the outline.

   procedure Add
     (Parent : in out Widget'Class;
      Item   : in out Stepper;
      Min    : Integer := 0;
      Max    : Integer := 100;
      Start  : Integer := 0) is
   begin
      Item.Low := Min;
      Item.High := Max;
      Item.Current := Start;
      Layouts.Add (Parent, Item, (Width => 120.0, Height => 32.0, others => <>));
   end Add;

   procedure Changed_Look (Item : in out Stepper) is
   begin
      if Is_Attached (Item) then
         Invalidate (Item);
         Content_Changed (Item);
      end if;
   end Changed_Look;

   procedure Set_Range (Item : in out Stepper; Min, Max : Integer) is
   begin
      Item.Low := Min;
      Item.High := Max;
      Item.Current := Integer'Max (Min, Integer'Min (Max, Item.Current));
      Changed_Look (Item);
   end Set_Range;

   function Minimum (Item : Stepper) return Integer is (Item.Low);

   function Maximum (Item : Stepper) return Integer is (Item.High);

   procedure Set_Step (Item : in out Stepper; By : Positive) is
   begin
      Item.By := By;
   end Set_Step;

   function Step (Item : Stepper) return Positive is (Item.By);

   procedure Set_Value (Item : in out Stepper; To : Integer) is
   begin
      if To /= Item.Current then
         Item.Current := To;
         Changed_Look (Item);
      end if;
   end Set_Value;

   function Value (Item : Stepper) return Integer is (Item.Current);

   procedure Set_Suffix (Item : in out Stepper; Text : String) is
   begin
      Item.Suffix := Ada.Strings.Unbounded.To_Unbounded_String (Text);
      Changed_Look (Item);
   end Set_Suffix;

   procedure Set_Enabled (Item : in out Stepper; To : Boolean) is
   begin
      if Item.Enabled /= To then
         Item.Enabled := To;
         Item.Pressed := None;
         Changed_Look (Item);
      end if;
   end Set_Enabled;

   function Is_Enabled (Item : Stepper) return Boolean is (Item.Enabled);

   procedure Set_Focusable (Item : in out Stepper; To : Boolean) is
   begin
      Item.Focusable := To;
      if not To and then Is_Attached (Item) and then Has_Focus (Item) then
         Release_Focus (Item);
      end if;
   end Set_Focusable;

   overriding function Is_Focusable (Item : Stepper) return Boolean is (Item.Focusable);

   function Can_Go (Item : Stepper; Which : Which_Button) return Boolean is
     (Item.Enabled and then
        (case Which is
            when Minus => Item.Current > Item.Low,
            when Plus  => Item.Current < Item.High,
            when None  => False));

   procedure Move (Item : in out Stepper; By : Integer) is
      To : constant Integer := Integer'Max (Item.Low, Integer'Min (Item.High, Item.Current + By));
   begin
      if Item.Enabled and then To /= Item.Current then
         Item.Current := To;
         Notify (Item, Change);
         Changed_Look (Item);
      end if;
   end Move;

   --  The two buttons, in pixels: each a square of the box's height less its outline, plus at the far right.

   function Side_Of (Item : Stepper) return Float is
     (Float'Max (0.0, Height_Of (Item) - 2.0 * Pomarine.Boxes.Edge (Density (Item)))
      * Button_Share);

   function Button_At (Item : Stepper; X, Y : Float) return Which_Button is
      Edge  : constant Float := Pomarine.Boxes.Edge (Density (Item));
      Side  : constant Float := Side_Of (Item);
      Right : constant Float := Left_Of (Item) + Width_Of (Item) - Edge;
      Top   : constant Float := Top_Of (Item) + Edge;
   begin
      if Y < Top or else Y >= Top + Side then
         return None;
      elsif X >= Right - Side and then X < Right then
         return Plus;
      elsif X >= Right - 2.0 * Side and then X < Right - Side then
         return Minus;
      end if;
      return None;
   end Button_At;

   overriding procedure Handle
     (Item    : in out Stepper;
      Event   : Pomarine.Events.Event;
      Handled : out Boolean)
   is
      Pixels : constant Float := Density (Item);
      Under  : constant Which_Button :=
        (if Event.Kind in Pomarine.Events.Mouse_Down | Pomarine.Events.Mouse_Up
         then Button_At (Item, Event.Mouse_X * Pixels, Event.Mouse_Y * Pixels) else None);
   begin
      Handled := False;
      if not Item.Enabled then
         return;
      end if;
      case Event.Kind is
         when Pomarine.Events.Mouse_Down =>
            if Event.Button = 1 and then Contains (Item, Event.Mouse_X * Pixels, Event.Mouse_Y * Pixels) then
               Item.Pressed := Under;
               Handled := True;
               Invalidate (Item);
            end if;
         when Pomarine.Events.Mouse_Up =>
            if Event.Button = 1 and then Item.Pressed /= None then
               if Under = Item.Pressed and then Can_Go (Item, Under) then
                  Move (Item, (if Under = Plus then Item.By else -Item.By));
               end if;
               Item.Pressed := None;
               Handled := True;
               Invalidate (Item);
            end if;
         when Pomarine.Events.Key_Down =>
            if Has_Focus (Item) and then not Event.Command then
               if Event.Key = Pomarine.Events.Key_Up_Arrow then
                  Move (Item, Item.By);
                  Handled := True;
               elsif Event.Key = Pomarine.Events.Key_Down_Arrow then
                  Move (Item, -Item.By);
                  Handled := True;
               elsif Event.Key = Pomarine.Events.Key_Page_Up then
                  Move (Item, 10 * Item.By);
                  Handled := True;
               elsif Event.Key = Pomarine.Events.Key_Page_Down then
                  Move (Item, -10 * Item.By);
                  Handled := True;
               end if;
            end if;
         when others =>
            null;
      end case;
   end Handle;

   overriding procedure Hover_Changed (Item : in out Stepper; Hovered : Boolean) is
      pragma Unreferenced (Hovered);
   begin
      Invalidate (Item);
   end Hover_Changed;

   overriding procedure Focus_Changed (Item : in out Stepper; Focused : Boolean) is
      pragma Unreferenced (Focused);
   begin
      Invalidate (Item);
   end Focus_Changed;

   overriding function Cursor (Item : Stepper) return SDL3.Cursors.Kind is
     (if Item.Enabled then SDL3.Cursors.Pointer else SDL3.Cursors.Default);

   overriding procedure Draw
     (Item   : in out Stepper;
      Target : SDL3.Painters.Painter'Class;
      Colors : Themes.Theme)
   is
      Pixels : constant Float := Density (Item);
      Edge   : constant Float := Pomarine.Boxes.Edge (Pixels);
      Side   : constant Float := Side_Of (Item);
      Right  : constant Float := Left_Of (Item) + Width_Of (Item) - Edge;
      Top    : constant Float := Top_Of (Item) + Edge;
      Ink    : constant Themes.Color :=
        (if Item.Enabled then Colors (Themes.Foreground) else Colors (Themes.Muted));

      procedure Press (Which : Which_Button; Left : Float; Mark : String) is
         Down : constant Boolean := Item.Pressed = Which and then Is_Hovered (Item);
         Face : constant Themes.Color :=
           Colors.Face_For (Enabled => Can_Go (Item, Which), Hovered => Is_Hovered (Item) and then not Down);
      begin
         Pomarine.Boxes.Draw_Control
           (Target, Colors, Face,
            (if Can_Go (Item, Which) then Colors (Themes.Border) else Themes.Dull (Colors, Colors (Themes.Border))),
            (Themes.Highlight (Face), Themes.Shadow_Of (Face)),
            Left, Top, Side, Side, Pixels, Bevelled => Can_Go (Item, Which), Sunken => Down,
            Radius => Themes.Small_Radius - 1.0);
         if Text_Lines (Item) /= null then
            declare
               Used : constant Float :=
                 Pomarine.Line_Texts.Width (Text_Lines (Item).all, Mark, Pixels, Pomarine.Line_Texts.Strong);
            begin
               Pomarine.Line_Texts.Draw
                 (Text_Lines (Item).all, Target,
                  (if Can_Go (Item, Which) then Colors (Themes.Foreground) else Colors (Themes.Muted)), Mark,
                  Left + (Side - Used) / 2.0, Top + Side / 2.0, Pixels, Pomarine.Line_Texts.Strong);
            end;
         end if;
      end Press;
   begin
      Pomarine.Boxes.Draw_Flat
        (Target, (if Item.Enabled then Colors (Themes.Page) else Colors (Themes.Tint)), Colors (Themes.Border),
         Left_Of (Item), Top_Of (Item), Width_Of (Item), Height_Of (Item), Pixels, Radius => Themes.Small_Radius);
      Press (Minus, Right - 2.0 * Side, "-");
      Press (Plus, Right - Side, "+");
      if Text_Lines (Item) /= null then
         declare
            Number : constant String := Integer'Image (Item.Current);
            Words  : constant String :=
              Number (Number'First + (if Item.Current < 0 then 0 else 1) .. Number'Last)
              & Ada.Strings.Unbounded.To_String (Item.Suffix);
            Start  : constant Float := Left_Of (Item) + 8.0 * Pixels;
         begin
            Pomarine.Line_Texts.Draw
              (Text_Lines (Item).all, Target, Ink,
               Pomarine.Line_Texts.Fitted (Text_Lines (Item).all, Words, Right - 2.0 * Side - Start, Pixels), Start,
               Top_Of (Item) + Height_Of (Item) / 2.0, Pixels);
         end;
      end if;
   end Draw;

   overriding procedure Draw_Over
     (Item   : in out Stepper;
      Target : SDL3.Painters.Painter'Class;
      Colors : Themes.Theme) is
   begin
      if Item.Focusable and then Is_Focus_Visible (Item) then
         Pomarine.Boxes.Outline
           (Target, Colors (Themes.Focus), Left_Of (Item), Top_Of (Item), Width_Of (Item), Height_Of (Item),
            Thick => Float'Max (1.0, Float'Rounding (2.0 * Density (Item))), Density => Density (Item));
      end if;
   end Draw_Over;

   overriding procedure Describe (Item : Stepper; Facts : in out Semantics.Description) is
      Number : constant String := Integer'Image (Item.Current);
   begin
      if Facts.Kind = Semantics.Unknown then
         Facts.Kind := Semantics.Slider;
      end if;
      Semantics.Value_As
        (Facts, Number (Number'First + (if Item.Current < 0 then 0 else 1) .. Number'Last)
         & Ada.Strings.Unbounded.To_String (Item.Suffix));
      Facts.Disabled := not Item.Enabled;
      Facts.Actions (Semantics.Increment) := Can_Go (Item, Plus);
      Facts.Actions (Semantics.Decrement) := Can_Go (Item, Minus);
   end Describe;

   overriding procedure Perform
     (Item    : in out Stepper;
      Request : Semantics.Request;
      Done    : out Boolean) is
   begin
      Done := False;
      if Request.Doing = Semantics.Increment and then Can_Go (Item, Plus) then
         Move (Item, Item.By);
         Done := True;
      elsif Request.Doing = Semantics.Decrement and then Can_Go (Item, Minus) then
         Move (Item, -Item.By);
         Done := True;
      end if;
   end Perform;

end Pomarine.Widgets.Steppers;
