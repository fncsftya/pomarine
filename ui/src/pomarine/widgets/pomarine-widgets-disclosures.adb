with Pomarine.Boxes;
with Pomarine.Line_Texts;
package body Pomarine.Widgets.Disclosures is

   use type Semantics.Action;
   use type Semantics.Role;
   use type Pomarine.Events.Event_Kind;
   use type Pomarine.Events.Key_Code;
   use all type SDL3.Painters.Painter;

   Indent : constant Layouts.Length := 16.0;

   function Box_Style return Layouts.Style is
     (Flow => Layouts.Column, Gap => 4.0,
      Padding => (Top => Layouts.In_Points (Heading_Height + 2.0), Left => Indent, others => <>),
      others => <>);

   procedure Add
     (Parent : in out Widget'Class;
      Item   : in out Disclosure;
      Words  : String;
      Open   : Boolean := True) is
   begin
      Item.Words := Ada.Strings.Unbounded.To_Unbounded_String (Words);
      Item.Opened := Open;
      Layouts.Add (Parent, Item, Box_Style);
   end Add;

   procedure Set_Title (Item : in out Disclosure; Text : String) is
   begin
      Item.Words := Ada.Strings.Unbounded.To_Unbounded_String (Text);
      if Is_Attached (Item) then
         Invalidate (Item);
      end if;
   end Set_Title;

   function Title (Item : Disclosure) return String is (Ada.Strings.Unbounded.To_String (Item.Words));

   procedure Set_Open (Item : in out Disclosure; To : Boolean) is
   begin
      Item.Opened := To;
      for Index in 1 .. Child_Count (Item) loop
         Set_Visible (Child_At (Item, Index).all, To);
      end loop;
      Invalidate (Item);
      Request_Layout (Item);
   end Set_Open;

   function Is_Open (Item : Disclosure) return Boolean is (Item.Opened);

   procedure Set_Focusable (Item : in out Disclosure; To : Boolean) is
   begin
      Item.Focusable := To;
      if not To and then Is_Attached (Item) and then Has_Focus (Item) then
         Release_Focus (Item);
      end if;
   end Set_Focusable;

   overriding function Is_Focusable (Item : Disclosure) return Boolean is (Item.Focusable);

   procedure Turn_Over (Item : in out Disclosure) is
   begin
      Set_Open (Item, not Item.Opened);
      Notify (Item, Change);
   end Turn_Over;

   function On_Heading (Item : Disclosure; X, Y : Float) return Boolean is
     (Contains (Item, X, Y) and then Y < Top_Of (Item) + Heading_Height * Density (Item));

   overriding procedure Handle
     (Item    : in out Disclosure;
      Event   : Pomarine.Events.Event;
      Handled : out Boolean)
   is
      Pixels : constant Float := Density (Item);
   begin
      Handled := False;
      case Event.Kind is
         when Pomarine.Events.Mouse_Down =>
            if Event.Button = 1 and then On_Heading (Item, Event.Mouse_X * Pixels, Event.Mouse_Y * Pixels) then
               Item.Pressed := True;
               Handled := True;
               Invalidate (Item);
            end if;
         when Pomarine.Events.Mouse_Up =>
            if Event.Button = 1 and then Item.Pressed then
               Item.Pressed := False;
               Handled := True;
               if On_Heading (Item, Event.Mouse_X * Pixels, Event.Mouse_Y * Pixels) then
                  Turn_Over (Item);
               end if;
               Invalidate (Item);
            end if;
         when Pomarine.Events.Key_Down =>
            if Has_Focus (Item) and then not Event.Command
              and then Event.Key in Pomarine.Events.Key_Space | Pomarine.Events.Key_Return
            then
               Turn_Over (Item);
               Handled := True;
            end if;
         when others =>
            null;
      end case;
   end Handle;

   overriding procedure Hover_Changed (Item : in out Disclosure; Hovered : Boolean) is
      pragma Unreferenced (Hovered);
   begin
      Invalidate (Item);
   end Hover_Changed;

   overriding procedure Focus_Changed (Item : in out Disclosure; Focused : Boolean) is
      pragma Unreferenced (Focused);
   begin
      Invalidate (Item);
   end Focus_Changed;

   overriding function Cursor (Item : Disclosure) return SDL3.Cursors.Kind is
     (if Is_Hovered (Item) then SDL3.Cursors.Pointer else SDL3.Cursors.Default);

   overriding procedure Draw
     (Item   : in out Disclosure;
      Target : SDL3.Painters.Painter'Class;
      Colors : Themes.Theme)
   is
      Pixels : constant Float := Density (Item);
      Edge   : constant Float := Pomarine.Boxes.Edge (Pixels);
      Middle : constant Float := Top_Of (Item) + Heading_Height * Pixels / 2.0;
   begin
      if Text_Lines (Item) /= null then
         Pomarine.Line_Texts.Draw
           (Text_Lines (Item).all, Target, Colors (Themes.Muted), (if Item.Opened then "v" else ">"),
            Left_Of (Item) + 4.0 * Pixels, Middle, Pixels, Pomarine.Line_Texts.Strong);
         Pomarine.Line_Texts.Draw
           (Text_Lines (Item).all, Target,
            Colors (Themes.Foreground),
            Pomarine.Line_Texts.Fitted
              (Text_Lines (Item).all, Title (Item), Width_Of (Item) - 24.0 * Pixels, Pixels,
               Pomarine.Line_Texts.Strong),
            Left_Of (Item) + 20.0 * Pixels, Middle, Pixels, Pomarine.Line_Texts.Strong);
      end if;
      Fill_Rect (Target, Colors (Themes.Border), Left_Of (Item), Top_Of (Item) + Heading_Height * Pixels - Edge,
                    Width_Of (Item), Edge);
   end Draw;

   overriding procedure Draw_Over
     (Item   : in out Disclosure;
      Target : SDL3.Painters.Painter'Class;
      Colors : Themes.Theme) is
   begin
      if Item.Focusable and then Is_Focus_Visible (Item) then
         Pomarine.Boxes.Outline
           (Target, Colors (Themes.Focus), Left_Of (Item), Top_Of (Item), Width_Of (Item),
            Heading_Height * Density (Item),
            Thick => Float'Max (1.0, Float'Rounding (2.0 * Density (Item))), Density => Density (Item));
      end if;
   end Draw_Over;

   overriding procedure Describe (Item : Disclosure; Facts : in out Semantics.Description) is
   begin
      if Facts.Kind = Semantics.Unknown then
         Facts.Kind := Semantics.Group;
      end if;
      Semantics.Name_As (Facts, Title (Item));
      Facts.Has_Expanded := True;
      Facts.Expanded := Item.Opened;
      Facts.Actions (Semantics.Expand) := not Item.Opened;
      Facts.Actions (Semantics.Collapse) := Item.Opened;
      Facts.Actions (Semantics.Click) := True;
   end Describe;

   overriding procedure Perform
     (Item    : in out Disclosure;
      Request : Semantics.Request;
      Done    : out Boolean) is
   begin
      Done := False;
      case Request.Doing is
         when Semantics.Click =>
            Turn_Over (Item);
            Done := True;
         when Semantics.Expand =>
            if not Item.Opened then
               Turn_Over (Item);
            end if;
            Done := True;
         when Semantics.Collapse =>
            if Item.Opened then
               Turn_Over (Item);
            end if;
            Done := True;
         when others =>
            null;
      end case;
   end Perform;

end Pomarine.Widgets.Disclosures;
