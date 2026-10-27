with Pomarine.Boxes;

package body Pomarine.Widgets.Switches is

   use type Pomarine.Events.Key_Code;

   use type Semantics.Action;
   use type Semantics.Role;

   use type Pomarine.Events.Event_Kind;

   Gap  : constant Float := 8.0;  --  in points, before the label
   Room : constant Float := 2.0;  --  in points, round the knob in the track

   procedure Changed_Look (Item : in out Switch);
   --  Draw it again, if it is in a tree.

   procedure Changed_Look (Item : in out Switch) is
   begin
      if Is_Attached (Item) then
         Invalidate (Item);
      end if;
   end Changed_Look;

   procedure Set_Label (Item : in out Switch; Text : String) is
   begin
      if Text /= Label (Item) then
         Item.Text := Ada.Strings.Unbounded.To_Unbounded_String (Text);
         Changed_Look (Item);
      end if;
   end Set_Label;

   function Label (Item : Switch) return String
   is (Ada.Strings.Unbounded.To_String (Item.Text));

   procedure Set_On (Item : in out Switch; To : Boolean) is
   begin
      if To /= Item.On then
         Item.On := To;
         Changed_Look (Item);
      end if;
   end Set_On;

   function Is_On (Item : Switch) return Boolean
   is (Item.On);

   procedure Set_Enabled (Item : in out Switch; To : Boolean) is
   begin
      if To /= Item.Enabled then
         Item.Enabled := To;
         Item.Down := False;
         Changed_Look (Item);
      end if;
   end Set_Enabled;

   function Is_Enabled (Item : Switch) return Boolean
   is (Item.Enabled);

   overriding
   procedure Handle (Item : in out Switch; Event : Pomarine.Events.Event; Handled : out Boolean) is
      Over : constant Boolean := Contains (Item, Event.Mouse_X * Density (Item), Event.Mouse_Y * Density (Item));
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

         when Pomarine.Events.Mouse_Up   =>
            if Event.Button = 1 and then Item.Down then
               Item.Down := False;
               if Over then
                  Item.On := not Item.On;
                  Notify (Item, Change);
               end if;
               Handled := True;
               Invalidate (Item);
            end if;

         when Pomarine.Events.Key_Down   =>
            if Has_Focus (Item) and then Event.Key = Pomarine.Events.Key_Space and then not Event.Command then
               Perform (Item, (Doing => Semantics.Click, others => <>), Handled);
            end if;

         when others                     =>
            null;
      end case;
   end Handle;

   overriding
   procedure Hover_Changed (Item : in out Switch; Hovered : Boolean) is
      pragma Unreferenced (Hovered);
   begin
      Invalidate (Item);
   end Hover_Changed;

   overriding
   function Cursor (Item : Switch) return SDL3.Cursors.Kind
   is (if Item.Enabled then SDL3.Cursors.Pointer else SDL3.Cursors.Default);

   overriding
   procedure Draw (Item : in out Switch; Target : SDL3.Painters.Painter'Class; Colors : Themes.Theme) is
      Pixels    : constant Float := Density (Item);
      Edge      : constant Float := Pomarine.Boxes.Edge (Pixels);
      Wide      : constant Float := Float'Rounding (Track_Width * Pixels);
      High      : constant Float := Float'Rounding (Track_Height * Pixels);
      Left      : constant Float := Float'Rounding (Left_Of (Item));
      Top       : constant Float := Float'Rounding (Top_Of (Item) + (Height_Of (Item) - High) / 2.0);
      Track     : constant Themes.Color := (if Item.On then Colors (Themes.Primary) else Colors (Themes.Face));
      Inner     : constant Float := Float'Rounding (Room * Pixels) + Edge;
      Knob_High : constant Float := High - 2.0 * Inner;
      Knob_Wide : constant Float := Float'Rounding (Wide / 2.0) - Inner;
      Pressed   : constant Boolean := Item.Down and then Is_Hovered (Item);

      procedure Draw_Label is
         Text            : constant String := Label (Item);
         Available_Width : constant Float := Float'Max (1.0, Width_Of (Item) - Wide - Gap * Pixels);
         Line_Ends       : array (Text'Range) of Positive;
         Count           : Natural := 0;
         First           : Positive := Text'First;
         Stop            : Positive;
         Line_High       : constant Float := Pomarine.Line_Texts.Height (Text_Lines (Item).all, Pixels);
      begin
         --  Long labels wrap within their allocated row. Short labels
         --  retain the existing single-line appearance.
         while First <= Text'Last loop
            Stop := Text'Last + 1;
            if Pomarine.Line_Texts.Width (Text_Lines (Item).all, Text (First .. Text'Last), Pixels) > Available_Width
            then
               Stop := First;
               for Last in First .. Text'Last loop
                  if Text (Last) = ' ' then
                     exit when
                       Stop > First
                       and then Pomarine.Line_Texts.Width (Text_Lines (Item).all, Text (First .. Last - 1), Pixels)
                                > Available_Width;
                     Stop := Last;
                  end if;
               end loop;
               if Stop = First then
                  Stop := Text'Last + 1;
               end if;
            end if;
            Count := Count + 1;
            Line_Ends (Count) := Stop;
            First := Stop + 1;
         end loop;
         First := Text'First;
         for Number in 1 .. Count loop
            Pomarine.Line_Texts.Draw
              (Text_Lines (Item).all,
               Target,
               (if Item.Enabled then Colors (Themes.Foreground) else Colors (Themes.Muted)),
               Text (First .. Line_Ends (Number) - 1),
               Left + Wide + Gap * Pixels,
               Top_Of (Item) + Height_Of (Item) / 2.0 + (Float (Number) - Float (Count + 1) / 2.0) * Line_High,
               Pixels);
            First := Line_Ends (Number) + 1;
         end loop;
      end Draw_Label;
   begin
      --  The track, sunk.
      Pomarine.Boxes.Draw_Flat
        (Target,
         (if Item.Enabled then Track else Themes.Dull (Colors, Track)),
         (if Item.Enabled
          then Themes.Mix (Track, Colors (Themes.Foreground), 0.35)
          else Themes.Dull (Colors, Colors (Themes.Border))),
         Left,
         Top,
         Wide,
         High,
         Pixels,
         Radius => Themes.Small_Radius);
      if Item.Enabled and then Colors.Bevelled then
         Pomarine.Boxes.Bevel
           (Target,
            Themes.Highlight (Track),
            Themes.Shadow_Of (Track),
            Left + Edge,
            Top + Edge,
            Wide - 2.0 * Edge,
            High - 2.0 * Edge,
            Pixels,
            Sunken => True,
            Radius => Float'Max (0.0, Pomarine.Boxes.Corner (Themes.Small_Radius, Pixels) - Edge));
      end if;
      --  The knob, standing up in it, at the end it is turned to.
      declare
         Face : constant Themes.Color :=
           Colors.Face_For (Enabled => Item.Enabled, Hovered => Is_Hovered (Item) and then not Pressed);
         X    : constant Float := (if Item.On then Left + Wide - Inner - Knob_Wide else Left + Inner);
      begin
         Pomarine.Boxes.Draw_Control
           (Target,
            Colors,
            Face,
            (if Item.Enabled then Colors (Themes.Border) else Themes.Dull (Colors, Colors (Themes.Border))),
            (Themes.Highlight (Face), Themes.Shadow_Of (Face)),
            X,
            Top + Inner,
            Knob_Wide,
            Knob_High,
            Pixels,
            Bevelled => Item.Enabled,
            Sunken   => Pressed,
            Radius   => Themes.Small_Radius - 1.0);
      end;
      if Ada.Strings.Unbounded.Length (Item.Text) > 0 and then Text_Lines (Item) /= null then
         Draw_Label;
      end if;
   end Draw;

   overriding
   procedure Describe (Item : Switch; Facts : in out Semantics.Description) is
   begin
      if Facts.Kind = Semantics.Unknown then
         Facts.Kind := Semantics.Switch;
      end if;
      Semantics.Name_As (Facts, Label (Item));
      Facts.Disabled := not Item.Enabled;
      Facts.Checked := (if Item.On then Semantics.On else Semantics.Off);
      Facts.Actions (Semantics.Click) := Item.Enabled;
   end Describe;

   overriding
   procedure Perform (Item : in out Switch; Request : Semantics.Request; Done : out Boolean) is
   begin
      Done := False;
      if Request.Doing = Semantics.Click and then Item.Enabled then
         Item.On := not Item.On;
         Notify (Item, Change);
         Invalidate (Item);
         Done := True;
      end if;
   end Perform;

   overriding
   procedure Command_State_Changed (Item : in out Switch; State : Command_State) is
   begin
      Set_Enabled (Item, State in Enabled | Ticked);
      if State = Ticked then
         Item.By_Command := True;
         Set_On (Item, True);
      elsif Item.By_Command then
         Item.By_Command := False;
         Set_On (Item, False);
      end if;
   end Command_State_Changed;

   procedure Set_Focusable (Item : in out Switch; To : Boolean) is
   begin
      Item.Focusable := To;
      if not To and then Is_Attached (Item) and then Has_Focus (Item) then
         Release_Focus (Item);
      end if;
   end Set_Focusable;

   overriding
   function Is_Focusable (Item : Switch) return Boolean
   is (Item.Focusable);

   overriding
   procedure Focus_Changed (Item : in out Switch; Focused : Boolean) is
      pragma Unreferenced (Focused);
   begin
      Invalidate (Item);
   end Focus_Changed;

   overriding
   procedure Draw_Over (Item : in out Switch; Target : SDL3.Painters.Painter'Class; Colors : Themes.Theme) is
   begin
      if Item.Focusable and then Is_Focus_Visible (Item) then
         Pomarine.Boxes.Outline
           (Target,
            Colors (Themes.Focus),
            Left_Of (Item),
            Top_Of (Item),
            Width_Of (Item),
            Height_Of (Item),
            Thick   => Float'Max (1.0, Float'Rounding (2.0 * Density (Item))),
            Density => Density (Item),
            Radius  => Themes.Small_Radius);
      end if;
   end Draw_Over;

end Pomarine.Widgets.Switches;
