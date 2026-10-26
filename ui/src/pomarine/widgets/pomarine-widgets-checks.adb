with Pomarine.Boxes;
with Pomarine.Icons;
package body Pomarine.Widgets.Checks is

   use type Pomarine.Events.Key_Code;

   use type Semantics.Action;
   use type Semantics.Role;

   use type Pomarine.Events.Event_Kind;
   use all type SDL3.Painters.Painter;

   Gap         : constant Float := 7.0;
   Swatch_Size : constant Float := 9.0;
   Dot_Inset   : constant Float := 3.5;
   Tick_Size   : constant Float := 11.0;
   --  In points: after the box, and after the swatch; the side of the
   --  swatch; of a chosen radio's square from the box's edge; of the tick.

   procedure Changed_Look (Item : in out Check);
   --  Draw it again, if it is in a tree.

   procedure Changed_Look (Item : in out Check) is
   begin
      if Is_Attached (Item) then
         Invalidate (Item);
      end if;
   end Changed_Look;

   procedure Set_Kind (Item : in out Check; To : Kind) is
   begin
      if To /= Item.Form then
         Item.Form := To;
         Changed_Look (Item);
      end if;
   end Set_Kind;

   function Kind_Of (Item : Check) return Kind is (Item.Form);

   procedure Set_Label (Item : in out Check; Text : String) is
   begin
      if Text /= Label (Item) then
         Item.Text := Ada.Strings.Unbounded.To_Unbounded_String (Text);
         Changed_Look (Item);
      end if;
   end Set_Label;

   function Label (Item : Check) return String is
     (Ada.Strings.Unbounded.To_String (Item.Text));

   procedure Set_Checked (Item : in out Check; To : Boolean) is
   begin
      if To /= Item.Checked then
         Item.Checked := To;
         Changed_Look (Item);
      end if;
   end Set_Checked;

   function Is_Checked (Item : Check) return Boolean is (Item.Checked);

   procedure Set_Swatch (Item : in out Check; To : Themes.Slot) is
   begin
      Item.Swatched := True;
      Item.Swatch := To;
      Changed_Look (Item);
   end Set_Swatch;

   procedure Set_Enabled (Item : in out Check; To : Boolean) is
   begin
      if To /= Item.Enabled then
         Item.Enabled := To;
         Item.Down := False;
         Changed_Look (Item);
      end if;
   end Set_Enabled;

   function Is_Enabled (Item : Check) return Boolean is (Item.Enabled);

   overriding procedure Handle
     (Item    : in out Check;
      Event   : Pomarine.Events.Event;
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
         when Pomarine.Events.Mouse_Down =>
            if Event.Button = 1 and then Over then
               Item.Down := True;
               Handled := True;
               Invalidate (Item);
            end if;
         when Pomarine.Events.Mouse_Up =>
            if Event.Button = 1 and then Item.Down then
               Item.Down := False;
               --  A radio that is chosen stays so.
               if Over and then not (Item.Form = Radio and then Item.Checked)
               then
                  Item.Checked := not Item.Checked;
                  Notify (Item, Change);
               end if;
               Handled := True;
               Invalidate (Item);
            end if;
         when Pomarine.Events.Key_Down =>
            if Has_Focus (Item) and then Event.Key = Pomarine.Events.Key_Space
              and then not Event.Command
            then
               Perform (Item, (Doing => Semantics.Click, others => <>), Handled);
            end if;
         when others =>
            null;
      end case;
   end Handle;

   overriding procedure Hover_Changed
     (Item : in out Check; Hovered : Boolean)
   is
      pragma Unreferenced (Hovered);
   begin
      Invalidate (Item);
   end Hover_Changed;

   overriding function Cursor (Item : Check) return SDL3.Cursors.Kind is
     (if Item.Enabled then SDL3.Cursors.Pointer else SDL3.Cursors.Default);

   overriding procedure Draw
     (Item   : in out Check;
      Target : SDL3.Painters.Painter'Class;
      Colors : Themes.Theme)
   is
      Pixels : constant Float := Density (Item);
      Edge   : constant Float := Pomarine.Boxes.Edge (Pixels);
      Side   : constant Float := Float'Rounding (Box_Size * Pixels);
      Left   : constant Float := Float'Rounding (Left_Of (Item));
      Top    : constant Float :=
        Float'Rounding (Top_Of (Item) + (Height_Of (Item) - Side) / 2.0);
      Paper  : constant Themes.Color :=
        (if not Item.Enabled then Colors (Themes.Tint)
         elsif Item.Down and then Is_Hovered (Item) then Colors (Themes.Background)
         else Colors (Themes.Page));
      Ink    : constant Themes.Color :=
        (if Item.Enabled then Colors (Themes.Foreground) else Colors (Themes.Muted));
      Ring   : constant Themes.Color :=
        (if not Item.Enabled then Themes.Dull (Colors, Colors (Themes.Border))
         elsif Is_Hovered (Item) then Colors (Themes.Foreground)
         else Themes.Mix (Colors (Themes.Border), Colors (Themes.Foreground), 0.35));
      After  : Float := Left + Side + Gap * Pixels;
   begin
      --  The box, sunk: the shade inside its top and left.
      Fill_Rect (Target, Paper, Left, Top, Side, Side);
      Pomarine.Boxes.Outline (Target, Ring, Left, Top, Side, Side, Edge);
      if Item.Enabled and then Colors.Bevelled then
         Fill_Rect
           (Target, Themes.Shadow_Of (Colors (Themes.Background)), Left + Edge, Top + Edge,
            Side - 2.0 * Edge, Edge);
         Fill_Rect
           (Target, Themes.Shadow_Of (Colors (Themes.Background)), Left + Edge, Top + Edge,
            Edge, Side - 2.0 * Edge);
      end if;
      if Item.Checked then
         case Item.Form is
            when Radio =>
               declare
                  In_By : constant Float :=
                    Float'Rounding (Dot_Inset * Pixels);
               begin
                  Fill_Rect
                    (Target, Ink, Left + In_By, Top + In_By,
                     Side - 2.0 * In_By, Side - 2.0 * In_By);
               end;
            when Box =>
               if Icon_Library (Item) /= null then
                  declare
                     Size  : constant Positive :=
                       Positive (Float'Rounding (Tick_Size * Pixels));
                     Drawn : Boolean;
                  begin
                     Pomarine.Icons.Draw
                       (Icon_Library (Item).all, Target, Pomarine.Icons.Check, Ink,
                        Float'Rounding (Left + (Side - Float (Size)) / 2.0),
                        Float'Rounding (Top + (Side - Float (Size)) / 2.0),
                        Size, Drawn);
                  end;
               end if;
         end case;
      end if;
      if Item.Swatched then
         declare
            Square : constant Float := Float'Rounding (Swatch_Size * Pixels);
         begin
            Fill_Rect
              (Target,
               (if Item.Enabled then Themes.Resolve (Colors, Item.Swatch)
                else Themes.Dull
                  (Colors, Themes.Resolve (Colors, Item.Swatch))),
               After, Float'Rounding (Top + (Side - Square) / 2.0),
               Square, Square);
            After := After + Square + Gap * Pixels;
         end;
      end if;
      if Ada.Strings.Unbounded.Length (Item.Text) > 0 and then Text_Lines (Item) /= null then
         Pomarine.Line_Texts.Draw
           (Text_Lines (Item).all, Target, Ink, Label (Item), After,
            Top_Of (Item) + Height_Of (Item) / 2.0, Pixels);
      end if;
   end Draw;

   overriding procedure Describe
     (Item  : Check;
      Facts : in out Semantics.Description) is
   begin
      if Facts.Kind = Semantics.Unknown then
         Facts.Kind := (if Item.Form = Radio then Semantics.Radio_Button
                        else Semantics.Check_Box);
      end if;
      Semantics.Name_As (Facts, Label (Item));
      Facts.Disabled := not Item.Enabled;
      Facts.Checked := (if Item.Checked then Semantics.On else Semantics.Off);
      Facts.Selected := Item.Checked and then Item.Form = Radio;
      Facts.Actions (Semantics.Click) := Item.Enabled;
   end Describe;

   overriding procedure Perform
     (Item    : in out Check;
      Request : Semantics.Request;
      Done    : out Boolean) is
   begin
      Done := False;
      if Request.Doing = Semantics.Click and then Item.Enabled then
         --  A radio that is chosen stays so.
         if not (Item.Form = Radio and then Item.Checked) then
            Item.Checked := not Item.Checked;
            Notify (Item, Change);
            Invalidate (Item);
         end if;
         Done := True;
      end if;
   end Perform;

   overriding procedure Command_State_Changed
     (Item : in out Check; State : Command_State) is
   begin
      Set_Enabled (Item, State in Enabled | Ticked);
      if State = Ticked then
         Item.By_Command := True;
         Set_Checked (Item, True);
      elsif Item.By_Command then
         Item.By_Command := False;
         Set_Checked (Item, False);
      end if;
   end Command_State_Changed;

   procedure Set_Focusable (Item : in out Check; To : Boolean) is
   begin
      Item.Focusable := To;
      if not To and then Is_Attached (Item) and then Has_Focus (Item) then
         Release_Focus (Item);
      end if;
   end Set_Focusable;

   overriding function Is_Focusable (Item : Check) return Boolean is
     (Item.Focusable);

   overriding procedure Focus_Changed
     (Item : in out Check; Focused : Boolean)
   is
      pragma Unreferenced (Focused);
   begin
      Invalidate (Item);
   end Focus_Changed;

   overriding procedure Draw_Over
     (Item   : in out Check;
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

end Pomarine.Widgets.Checks;
