with Ada.Unchecked_Conversion;
with System;
with Pomarine.Anchoring;
with Pomarine.Boxes;
with Pomarine.Icons;
with Pomarine.Widgets.Layouts;
with Pomarine.Widgets.Overlays;

package body Pomarine.Widgets.Selects is

   use type Ada.Strings.Unbounded.Unbounded_String;

   use type Semantics.Action;
   use type Semantics.Role;

   use type Pomarine.Events.Event_Kind;

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

   procedure Set_Faced (Item : in out Select_Field; To : Boolean) is
   begin
      if Item.Faced /= To then
         Item.Faced := To;
         Invalidate (Item);
      end if;
   end Set_Faced;

   procedure Set_Value (Item : in out Select_Field; Text : String) is
   begin
      if Text /= Value (Item) then
         Item.Text := Ada.Strings.Unbounded.To_Unbounded_String (Text);
         Changed_Look (Item);
      end if;
   end Set_Value;

   function Value (Item : Select_Field) return String
   is (Ada.Strings.Unbounded.To_String (Item.Text));

   procedure Set_Open (Item : in out Select_Field; To : Boolean) is
   begin
      if To /= Item.Open then
         Item.Open := To;
         Changed_Look (Item);
      end if;
   end Set_Open;

   function Is_Open (Item : Select_Field) return Boolean
   is (Item.Open);

   procedure Set_Enabled (Item : in out Select_Field; To : Boolean) is
   begin
      if To /= Item.Enabled then
         Item.Enabled := To;
         Item.Down := False;
         Changed_Look (Item);
      end if;
   end Set_Enabled;

   function Is_Enabled (Item : Select_Field) return Boolean
   is (Item.Enabled);

   --  Its menu

   Menu_Room : constant Float := 240.0;
   --  The most height of its menu, in points: more rows are scrolled.

   function Chosen (Item : Select_Field) return Natural is
   begin
      for Index in 1 .. Natural (Item.Choices.Length) loop
         if Item.Choices (Index) = Item.Text then
            return Index;
         end if;
      end loop;
      return 0;
   end Chosen;

   function Choice_Count (Item : Select_Field) return Natural
   is (Natural (Item.Choices.Length));

   function Choice (Item : Select_Field; Index : Positive) return String
   is (Ada.Strings.Unbounded.To_String (Item.Choices (Index)));

   procedure Choose (Item : in out Select_Field; Index : Positive) is
   begin
      Set_Value (Item, Choice (Item, Index));
   end Choose;

   procedure Open_When_Clicked (Self, Proc : System.Address; Source : in out Widget'Class; Event : Widget_Event);
   --  What a click on it does, when it has choices: after the event that was the click.

   procedure Chosen_From_Menu (Self, Proc : System.Address; Source : in out Widget'Class; Event : Widget_Event);
   --  What its menu says when a row is chosen.

   procedure Menu_Let_Go (Self, Proc : System.Address; Source : in out Widget'Class; Event : Widget_Event);
   --  What its menu says when Escape or a press elsewhere has let go of it.

   type Field_Access is access all Select_Field;
   function To_Field is new Ada.Unchecked_Conversion (System.Address, Field_Access);

   procedure Add_Choice (Item : in out Select_Field; Text : String) is
   begin
      Item.Choices.Append (Ada.Strings.Unbounded.To_Unbounded_String (Text));
      Set_Hook (Item, Click, Open_When_Clicked'Access, Item'Address, System.Null_Address);
   end Add_Choice;

   procedure Clear_Choices (Item : in out Select_Field) is
   begin
      Item.Choices.Clear;
      Clear_Hook (Item, Click);
   end Clear_Choices;

   procedure Open (Item : in out Select_Field) is
      Rows : Menus.Row_Vectors.Vector;
      Now  : constant Natural := Chosen (Item);
   begin
      if not Is_Attached (Item.Menu) then
         Layouts.Add (Root_Widget (Tree_Of (Item).all).all, Item.Menu, (Place => Layouts.Absolute, others => <>));
         Set_Visible (Item.Menu, False);
         Set_Hook (Item.Menu, Choose, Chosen_From_Menu'Access, Item'Address, System.Null_Address);
         Set_Hook (Item.Menu, Dismiss, Menu_Let_Go'Access, Item'Address, System.Null_Address);
         Menus.Set_Keyboard (Item.Menu, True);
      end if;
      for Index in 1 .. Choice_Count (Item) loop
         Rows.Append (Menus.Describe_Row (Menus.Check, Choice (Item, Index), Checked => Index = Now));
      end loop;
      Menus.Set_Rows (Item.Menu, Rows);
      Menus.Set_Faced (Item.Menu, Item.Faced);
      Menus.Set_Max_Height (Item.Menu, Menu_Room);
      Overlays.Present_Beside
        (Item.Menu, Item, (Gap => 2.0, Match_Width => True, others => <>), Pomarine.Anchoring.Light_Dismiss);
      Set_Open (Item, True);
      if Now /= 0 then
         Menus.Reveal (Item.Menu, Now);
         Menus.Highlight (Item.Menu, Now);
      end if;
   end Open;

   procedure Open_When_Clicked (Self, Proc : System.Address; Source : in out Widget'Class; Event : Widget_Event) is
      pragma Unreferenced (Self, Proc, Event);
      Field : Select_Field renames Select_Field (Source);
   begin
      if Choice_Count (Field) > 0 and then Field.Enabled then
         if Overlays.Is_Presented (Field.Menu) then
            Overlays.Dismiss (Field.Menu);
            Set_Open (Field, False);
         else
            Open (Field);
         end if;
      end if;
   end Open_When_Clicked;

   procedure Chosen_From_Menu (Self, Proc : System.Address; Source : in out Widget'Class; Event : Widget_Event) is
      pragma Unreferenced (Proc);
      Field : constant Field_Access := To_Field (Self);
   begin
      Overlays.Dismiss (Source);
      Set_Open (Field.all, False);
      if Event.Row in 1 .. Choice_Count (Field.all) and then Choice (Field.all, Event.Row) /= Value (Field.all) then
         Choose (Field.all, Event.Row);
         Notify (Field.all, Change);
      end if;
   end Chosen_From_Menu;

   procedure Menu_Let_Go (Self, Proc : System.Address; Source : in out Widget'Class; Event : Widget_Event) is
      pragma Unreferenced (Proc, Source, Event);
   begin
      Set_Open (To_Field (Self).all, False);
   end Menu_Let_Go;

   overriding
   procedure Handle (Item : in out Select_Field; Event : Pomarine.Events.Event; Handled : out Boolean) is
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
                  Notify (Item, Click);
               end if;
               Handled := True;
               Invalidate (Item);
            end if;

         when others                     =>
            null;
      end case;
   end Handle;

   overriding
   procedure Hover_Changed (Item : in out Select_Field; Hovered : Boolean) is
      pragma Unreferenced (Hovered);
   begin
      Invalidate (Item);
   end Hover_Changed;

   overriding
   function Cursor (Item : Select_Field) return SDL3.Cursors.Kind
   is (if Item.Enabled then SDL3.Cursors.Pointer else SDL3.Cursors.Default);

   overriding
   procedure Draw (Item : in out Select_Field; Target : SDL3.Painters.Painter'Class; Colors : Themes.Theme) is
      Pixels      : constant Float := Density (Item);
      Edge        : constant Float := Pomarine.Boxes.Edge (Pixels);
      Left        : constant Float := Left_Of (Item);
      Top         : constant Float := Top_Of (Item);
      Wide        : constant Float := Width_Of (Item);
      High        : constant Float := Height_Of (Item);
      Ink         : constant Themes.Color :=
        (if Item.Enabled then Colors (Themes.Foreground) else Colors (Themes.Muted));
      Around      : constant Float := Edge + Float'Rounding (Inner * Pixels);
      Side        : constant Float := Float'Max (0.0, High - 2.0 * Around);
      --  The button, square, with its shadow, inside the outline.
      Button_Left : constant Float := Left + Wide - Around - Side;
      Pressed     : constant Boolean :=
        Item.Enabled and then (Item.Open or else (Item.Down and then Is_Hovered (Item)));
   begin
      Pomarine.Boxes.Draw_Flat
        (Target,
         (if Item.Enabled then Colors (Themes.Page) else Colors (Themes.Tint)),
         (if Item.Open then Colors (Themes.Focus) else Colors (Themes.Border)),
         Left,
         Top,
         Wide,
         High,
         Pixels,
         Radius => Themes.Small_Radius);
      declare
         Face : constant Themes.Color :=
           Colors.Face_For (Enabled => Item.Enabled, Hovered => Is_Hovered (Item) and then not Pressed);
      begin
         Pomarine.Boxes.Draw_Control
           (Target,
            Colors,
            Face,
            (if Item.Enabled then Colors (Themes.Border) else Themes.Dull (Colors, Colors (Themes.Border))),
            (Themes.Highlight (Face), Themes.Shadow_Of (Face)),
            Button_Left,
            Top + Around,
            Side,
            Side,
            Pixels,
            Bevelled => Item.Enabled,
            Sunken   => Pressed,
            Radius   => Themes.Small_Radius - 1.0);
      end;
      if Icon_Library (Item) /= null then
         declare
            Size  : constant Positive := Positive (Float'Rounding (Caret_Size * Pixels));
            Drawn : Boolean;
         begin
            Pomarine.Icons.Draw
              (Icon_Library (Item).all,
               Target,
               (if Item.Open then Pomarine.Icons.Chevron_Up else Pomarine.Icons.Chevron_Down),
               Ink,
               Float'Rounding (Button_Left + (Side - Float (Size)) / 2.0),
               Float'Rounding (Top + Around + (Side - Float (Size)) / 2.0),
               Size,
               Drawn);
         end;
      end if;
      if Ada.Strings.Unbounded.Length (Item.Text) > 0 and then Text_Lines (Item) /= null then
         declare
            Face  : constant String := (if Item.Faced then Value (Item) else "");
            Start : constant Float := Left + Pad * Pixels;
         begin
            Pomarine.Line_Texts.Draw
              (Text_Lines (Item).all,
               Target,
               Ink,
               Pomarine.Line_Texts.Fitted
                 (Text_Lines (Item).all, Value (Item), Button_Left - Around - Start, Pixels, Face => Face),
               Start,
               Top + High / 2.0,
               Pixels,
               Face => Face);
         end;
      end if;
   end Draw;

   overriding
   procedure Describe (Item : Select_Field; Facts : in out Semantics.Description) is
   begin
      if Facts.Kind = Semantics.Unknown then
         Facts.Kind := Semantics.Button;
      end if;
      Semantics.Value_As (Facts, Value (Item));
      Facts.Disabled := not Item.Enabled;
      Facts.Has_Expanded := True;
      Facts.Expanded := Item.Open;
      Facts.Actions (Semantics.Click) := Item.Enabled;
   end Describe;

   overriding
   procedure Perform (Item : in out Select_Field; Request : Semantics.Request; Done : out Boolean) is
   begin
      Done := False;
      if Request.Doing = Semantics.Click and then Item.Enabled then
         Notify (Item, Click);
         Invalidate (Item);
         Done := True;
      end if;
   end Perform;

   overriding
   procedure Command_State_Changed (Item : in out Select_Field; State : Command_State) is
   begin
      Set_Enabled (Item, State in Enabled | Ticked);
   end Command_State_Changed;

end Pomarine.Widgets.Selects;
