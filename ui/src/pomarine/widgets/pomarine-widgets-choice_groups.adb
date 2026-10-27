with Pomarine.Boxes;
with Pomarine.Line_Texts;
with Pomarine.Widgets.Layouts;

package body Pomarine.Widgets.Choice_Groups is

   use type Semantics.Action;
   use type Semantics.Role;
   use type Pomarine.Events.Event_Kind;
   use type Pomarine.Events.Key_Code;
   use all type SDL3.Painters.Painter;

   Tab_Height    : constant Float := 32.0;  --  in points
   Radio_Height  : constant Float := 24.0;
   Dot_Size      : constant Float := 14.0;
   Dot_Gap       : constant Float := 8.0;
   Bar_Thickness : constant Float := 2.0;

   procedure Changed_Look (Item : in out Choice_Group) is
   begin
      if Is_Attached (Item) then
         Invalidate (Item);
      end if;
   end Changed_Look;

   procedure Add (Parent : in out Widget'Class; Item : in out Choice_Group; As : Look_Kind := Tabs) is
   begin
      Item.Form := As;
      Item.Down_Flow := As = Radios;
      Layouts.Add (Parent, Item, (Height => Layouts.In_Points (Tab_Height), others => <>));
   end Add;

   procedure Set_Look (Item : in out Choice_Group; To : Look_Kind) is
   begin
      Item.Form := To;
      Item.Down_Flow := To = Radios;
      Changed_Look (Item);
   end Set_Look;

   function Look (Item : Choice_Group) return Look_Kind
   is (Item.Form);

   procedure Set_Vertical (Item : in out Choice_Group; To : Boolean) is
   begin
      Item.Down_Flow := To;
      Changed_Look (Item);
   end Set_Vertical;

   function Is_Vertical (Item : Choice_Group) return Boolean
   is (Item.Down_Flow);

   procedure Add_Choice (Item : in out Choice_Group; Text : String) is
   begin
      Item.Choices.Append (Choice'(Text => Ada.Strings.Unbounded.To_Unbounded_String (Text), Enabled => True));
      if Item.Chosen = 0 then
         Item.Chosen := 1;
      end if;
      Changed_Look (Item);
   end Add_Choice;

   procedure Clear_Choices (Item : in out Choice_Group) is
   begin
      Item.Choices.Clear;
      Item.Chosen := 0;
      Item.Pressed := 0;
      Item.Over := 0;
      Changed_Look (Item);
   end Clear_Choices;

   function Choice_Count (Item : Choice_Group) return Natural
   is (Natural (Item.Choices.Length));

   function Label (Item : Choice_Group; Index : Positive) return String
   is (Ada.Strings.Unbounded.To_String (Item.Choices (Index).Text));

   procedure Set_Choice_Enabled (Item : in out Choice_Group; Index : Positive; To : Boolean) is
   begin
      if Item.Choices (Index).Enabled /= To then
         Item.Choices (Index).Enabled := To;
         Changed_Look (Item);
      end if;
   end Set_Choice_Enabled;

   function Is_Choice_Enabled (Item : Choice_Group; Index : Positive) return Boolean
   is (Item.Choices (Index).Enabled);

   procedure Select_Choice (Item : in out Choice_Group; Index : Positive) is
   begin
      if Item.Chosen /= Index then
         Item.Chosen := Index;
         Changed_Look (Item);
      end if;
   end Select_Choice;

   function Selected (Item : Choice_Group) return Natural
   is (Item.Chosen);

   procedure Set_Enabled (Item : in out Choice_Group; To : Boolean) is
   begin
      if Item.Enabled /= To then
         Item.Enabled := To;
         Item.Pressed := 0;
         Changed_Look (Item);
      end if;
   end Set_Enabled;

   function Is_Enabled (Item : Choice_Group) return Boolean
   is (Item.Enabled);

   procedure Fit (Item : in out Choice_Group) is
      High : constant Float :=
        (if Item.Down_Flow then Radio_Height * Float'Max (1.0, Float (Choice_Count (Item))) else Tab_Height);
   begin
      Layouts.Set_Layout (Item, Height => Layouts.In_Points (High));
   end Fit;

   procedure Set_Focusable (Item : in out Choice_Group; To : Boolean) is
   begin
      Item.Focusable := To;
      if not To and then Is_Attached (Item) and then Has_Focus (Item) then
         Release_Focus (Item);
      end if;
   end Set_Focusable;

   overriding
   function Is_Focusable (Item : Choice_Group) return Boolean
   is (Item.Focusable);

   --  Where each choice is, in pixels

   function Box_Of_Choice (Item : Choice_Group; Index : Positive) return Semantics.Rectangle is
      Count : constant Float := Float'Max (1.0, Float (Choice_Count (Item)));
   begin
      if Item.Down_Flow then
         declare
            Each : constant Float := Height_Of (Item) / Count;
         begin
            return
              (Left   => Left_Of (Item),
               Top    => Top_Of (Item) + Float (Index - 1) * Each,
               Right  => Left_Of (Item) + Width_Of (Item),
               Bottom => Top_Of (Item) + Float (Index) * Each);
         end;
      else
         declare
            Each : constant Float := Width_Of (Item) / Count;
         begin
            return
              (Left   => Left_Of (Item) + Float (Index - 1) * Each,
               Top    => Top_Of (Item),
               Right  => Left_Of (Item) + Float (Index) * Each,
               Bottom => Top_Of (Item) + Height_Of (Item));
         end;
      end if;
   end Box_Of_Choice;

   function Choice_At (Item : Choice_Group; X, Y : Float) return Natural is
   begin
      for Index in 1 .. Choice_Count (Item) loop
         declare
            Box : constant Semantics.Rectangle := Box_Of_Choice (Item, Index);
         begin
            if X >= Box.Left and then X < Box.Right and then Y >= Box.Top and then Y < Box.Bottom then
               return Index;
            end if;
         end;
      end loop;
      return 0;
   end Choice_At;

   procedure Choose (Item : in out Choice_Group; Index : Positive) is
   begin
      if Item.Enabled and then Item.Choices (Index).Enabled and then Index /= Item.Chosen then
         Item.Chosen := Index;
         Notify (Item, Choose, Row => Index);
         Invalidate (Item);
      end if;
   end Choose;

   function Step_From (Item : Choice_Group; Start : Natural; By : Integer) return Natural is
      --  The nearest choice that is turned on, from Start in the direction By, not wrapping; 0 if none.
      Index : Integer := Start + By;
   begin
      while Index in 1 .. Choice_Count (Item) loop
         if Item.Choices (Index).Enabled then
            return Index;
         end if;
         Index := Index + By;
      end loop;
      return 0;
   end Step_From;

   overriding
   procedure Handle (Item : in out Choice_Group; Event : Pomarine.Events.Event; Handled : out Boolean) is
      Pixels : constant Float := Density (Item);
      Under  : constant Natural :=
        (if Event.Kind in Pomarine.Events.Mouse_Down | Pomarine.Events.Mouse_Up | Pomarine.Events.Mouse_Move
         then Choice_At (Item, Event.Mouse_X * Pixels, Event.Mouse_Y * Pixels)
         else 0);
      Target : Natural := 0;
   begin
      Handled := False;
      case Event.Kind is
         when Pomarine.Events.Mouse_Move =>
            if Under /= Item.Over then
               Item.Over := Under;
               Invalidate (Item);
            end if;

         when Pomarine.Events.Mouse_Down =>
            if Event.Button = 1 and then Under /= 0 and then Item.Enabled then
               Item.Pressed := Under;
               Handled := True;
               Invalidate (Item);
            end if;

         when Pomarine.Events.Mouse_Up   =>
            if Event.Button = 1 and then Item.Pressed /= 0 then
               if Under = Item.Pressed then
                  Choose (Item, Under);
               end if;
               Item.Pressed := 0;
               Handled := True;
               Invalidate (Item);
            end if;

         when Pomarine.Events.Key_Down   =>
            if Has_Focus (Item) and then Item.Enabled and then not Event.Command then
               if Event.Key in Pomarine.Events.Key_Right_Arrow | Pomarine.Events.Key_Down_Arrow then
                  Target := Step_From (Item, Item.Chosen, 1);
               elsif Event.Key in Pomarine.Events.Key_Left_Arrow | Pomarine.Events.Key_Up_Arrow then
                  Target := Step_From (Item, Item.Chosen, -1);
               elsif Event.Key = Pomarine.Events.Key_Home then
                  Target := Step_From (Item, 0, 1);
               elsif Event.Key = Pomarine.Events.Key_End then
                  Target := Step_From (Item, Choice_Count (Item) + 1, -1);
               else
                  return;
               end if;
               Handled := True;
               if Target /= 0 then
                  Choose (Item, Target);
               end if;
            end if;

         when others                     =>
            null;
      end case;
   end Handle;

   overriding
   procedure Hover_Changed (Item : in out Choice_Group; Hovered : Boolean) is
   begin
      if not Hovered and then Item.Over /= 0 then
         Item.Over := 0;
      end if;
      Invalidate (Item);
   end Hover_Changed;

   overriding
   procedure Focus_Changed (Item : in out Choice_Group; Focused : Boolean) is
      pragma Unreferenced (Focused);
   begin
      Invalidate (Item);
   end Focus_Changed;

   overriding
   function Cursor (Item : Choice_Group) return SDL3.Cursors.Kind
   is (if Item.Enabled and then Item.Over /= 0 and then Item.Choices (Item.Over).Enabled
       then SDL3.Cursors.Pointer
       else SDL3.Cursors.Default);

   overriding
   procedure Draw (Item : in out Choice_Group; Target : SDL3.Painters.Painter'Class; Colors : Themes.Theme) is
      Pixels : constant Float := Density (Item);
      Edge   : constant Float := Pomarine.Boxes.Edge (Pixels);
      Bar    : constant Float := Float'Max (Edge, Float'Rounding (Bar_Thickness * Pixels));
   begin
      if Item.Form = Tabs and then Choice_Count (Item) > 0 then
         Fill_Rect
           (Target,
            Colors (Themes.Border),
            Left_Of (Item),
            Top_Of (Item) + Height_Of (Item) - Edge,
            Width_Of (Item),
            Edge);
      end if;
      for Index in 1 .. Choice_Count (Item) loop
         declare
            Box    : constant Semantics.Rectangle := Box_Of_Choice (Item, Index);
            Each   : Choice renames Item.Choices (Index);
            Chosen : constant Boolean := Index = Item.Chosen;
            Live   : constant Boolean := Item.Enabled and then Each.Enabled;
            Hot    : constant Boolean := Live and then Index = Item.Over and then Is_Hovered (Item);
            Wide   : constant Float := Box.Right - Box.Left;
            High   : constant Float := Box.Bottom - Box.Top;
            Words  : constant String := Ada.Strings.Unbounded.To_String (Each.Text);
            Ink    : Themes.Color :=
              (if not Live
               then Colors (Themes.Muted)
               elsif Chosen or else Hot
               then Colors (Themes.Foreground)
               else Themes.Mix (Colors (Themes.Foreground), Colors (Themes.Muted), 0.45));
         begin
            case Item.Form is
               when Tabs     =>
                  if Chosen then
                     Fill_Rect (Target, Colors (Themes.Accent), Box.Left, Box.Bottom - Bar, Wide, Bar);
                  end if;

               when Segments =>
                  Pomarine.Boxes.Draw_Flat
                    (Target,
                     (if Chosen
                      then Colors (Themes.Accent)
                      elsif Hot
                      then Colors (Themes.Tint)
                      else Colors (Themes.Page)),
                     Colors (Themes.Border),
                     Box.Left,
                     Box.Top,
                     Wide + (if Index < Choice_Count (Item) then Edge else 0.0),
                     High,
                     Pixels);
                  if Chosen then
                     Ink := Colors (Themes.On_Accent);
                  end if;

               when Radios   =>
                  declare
                     Side  : constant Float := Float'Rounding (Dot_Size * Pixels);
                     Left  : constant Float := Float'Rounding (Box.Left);
                     Top   : constant Float := Float'Rounding (Box.Top + (High - Side) / 2.0);
                     Paper : constant Themes.Color := (if Live then Colors (Themes.Page) else Colors (Themes.Tint));
                  begin
                     Fill_Rect (Target, Paper, Left, Top, Side, Side);
                     Pomarine.Boxes.Outline
                       (Target,
                        (if Hot
                         then Colors (Themes.Foreground)
                         else Themes.Mix (Colors (Themes.Border), Colors (Themes.Foreground), 0.35)),
                        Left,
                        Top,
                        Side,
                        Side,
                        Edge);
                     if Chosen then
                        Fill_Rect
                          (Target,
                           Ink,
                           Left + Float'Rounding (3.0 * Pixels),
                           Top + Float'Rounding (3.0 * Pixels),
                           Side - 2.0 * Float'Rounding (3.0 * Pixels),
                           Side - 2.0 * Float'Rounding (3.0 * Pixels));
                     end if;
                  end;
            end case;
            if Words /= "" and then Text_Lines (Item) /= null then
               if Item.Form = Radios then
                  Pomarine.Line_Texts.Draw
                    (Text_Lines (Item).all,
                     Target,
                     Ink,
                     Words,
                     Float'Rounding (Box.Left) + (Dot_Size + Dot_Gap) * Pixels,
                     Box.Top + High / 2.0,
                     Pixels);
               else
                  declare
                     Used  : constant Float :=
                       Pomarine.Line_Texts.Width (Text_Lines (Item).all, Words, Pixels, Pomarine.Line_Texts.Strong);
                     Shown : constant String :=
                       (if Used > Wide - 8.0 * Pixels
                        then
                          Pomarine.Line_Texts.Fitted
                            (Text_Lines (Item).all, Words, Wide - 8.0 * Pixels, Pixels, Pomarine.Line_Texts.Strong)
                        else Words);
                     Room  : constant Float :=
                       Pomarine.Line_Texts.Width (Text_Lines (Item).all, Shown, Pixels, Pomarine.Line_Texts.Strong);
                  begin
                     Pomarine.Line_Texts.Draw
                       (Text_Lines (Item).all,
                        Target,
                        Ink,
                        Shown,
                        Box.Left + (Wide - Room) / 2.0,
                        Box.Top + (High - (if Item.Form = Tabs then Bar else 0.0)) / 2.0,
                        Pixels,
                        Pomarine.Line_Texts.Strong);
                  end;
               end if;
            end if;
         end;
      end loop;
   end Draw;

   overriding
   procedure Draw_Over (Item : in out Choice_Group; Target : SDL3.Painters.Painter'Class; Colors : Themes.Theme) is
   begin
      if Item.Focusable and then Is_Focus_Visible (Item) and then Choice_Count (Item) > 0 and then Item.Chosen /= 0 then
         declare
            Box : constant Semantics.Rectangle := Box_Of_Choice (Item, Item.Chosen);
         begin
            Pomarine.Boxes.Outline
              (Target,
               Colors (Themes.Focus),
               Box.Left,
               Box.Top,
               Box.Right - Box.Left,
               Box.Bottom - Box.Top,
               Thick   => Float'Max (1.0, Float'Rounding (2.0 * Density (Item))),
               Density => Density (Item));
         end;
      end if;
   end Draw_Over;

   overriding
   procedure Describe (Item : Choice_Group; Facts : in out Semantics.Description) is
   begin
      if Facts.Kind = Semantics.Unknown then
         Facts.Kind := Semantics.Group;
      end if;
      Facts.Disabled := not Item.Enabled;
   end Describe;

   overriding
   function Part_Count (Item : Choice_Group) return Natural
   is (Choice_Count (Item));

   overriding
   procedure Describe_Part
     (Item : Choice_Group; Part : Positive; Facts : in out Semantics.Description; Bounds : out Semantics.Rectangle) is
   begin
      Bounds := Box_Of_Choice (Item, Part);
      Facts.Kind := Semantics.Radio_Button;
      Semantics.Name_As (Facts, Label (Item, Part));
      Facts.Disabled := not (Item.Enabled and then Item.Choices (Part).Enabled);
      Facts.Checked := (if Part = Item.Chosen then Semantics.On else Semantics.Off);
      Facts.Selected := Part = Item.Chosen;
      Facts.Actions (Semantics.Click) := not Facts.Disabled;
   end Describe_Part;

   overriding
   procedure Perform_Part (Item : in out Choice_Group; Part : Positive; Request : Semantics.Request; Done : out Boolean)
   is
   begin
      Done := False;
      if Request.Doing = Semantics.Click and then Item.Enabled and then Item.Choices (Part).Enabled then
         Choose (Item, Part);
         Done := True;
      end if;
   end Perform_Part;

end Pomarine.Widgets.Choice_Groups;
