with System;
with Pomarine.Boxes;
with Pomarine.Widgets.Layouts;

package body Pomarine.Widgets.Splitters is

   use type Semantics.Action;
   use type Pomarine.Events.Event_Kind;
   use type Pomarine.Events.Key_Code;
   use type Semantics.Role;
   use type System.Address;
   use all type SDL3.Painters.Painter;

   procedure Add (Parent : in out Widget'Class; Item : in out Splitter; Along : Boolean := False) is
   begin
      Item.Down_Bar := Along;
      Layouts.Add
        (Parent,
         Item,
         (if Along
          then Layouts.Style'(Height => Layouts.In_Points (Thickness), Shrink => 0.0, others => <>)
          else Layouts.Style'(Width => Layouts.In_Points (Thickness), Shrink => 0.0, others => <>)));
   end Add;

   procedure Set_Limits (Item : in out Splitter; Least, Most : Float) is
   begin
      Item.Least := Least;
      Item.Most := Most;
   end Set_Limits;

   function Before_Box (Item : Splitter) return Widget_Access is
      Above : constant Widget_Access := Parent_Of (Item);
   begin
      if Above = null then
         return null;
      end if;
      for Index in 2 .. Child_Count (Above.all) loop
         if Child_At (Above.all, Index).all'Address = Item'Address then
            return Child_At (Above.all, Index - 1);
         end if;
      end loop;
      return null;
   end Before_Box;

   function Position (Item : Splitter) return Float is
      Box : constant Widget_Access := Before_Box (Item);
   begin
      if Box = null then
         return 0.0;
      end if;
      return (if Item.Down_Bar then Height_Of (Box.all) else Width_Of (Box.all)) / Density (Item);
   end Position;

   procedure Make_It (Item : in out Splitter; Points : Float; Said : Boolean) is
      Box : constant Widget_Access := Before_Box (Item);
      To  : constant Float := Float'Max (Item.Least, Float'Min (Item.Most, Points));
   begin
      if Box = null or else abs (To - Position (Item)) < 0.5 / Density (Item) then
         return;
      end if;
      if Item.Down_Bar then
         Layouts.Set_Layout (Box.all, Height => Layouts.In_Points (To), Grow => 0.0, Shrink => 0.0);
      else
         Layouts.Set_Layout (Box.all, Width => Layouts.In_Points (To), Grow => 0.0, Shrink => 0.0);
      end if;
      if Said then
         Notify (Item, Change);
      end if;
   end Make_It;

   procedure Set_Position (Item : in out Splitter; To : Float) is
   begin
      Make_It (Item, To, Said => False);
   end Set_Position;

   procedure Set_Focusable (Item : in out Splitter; To : Boolean) is
   begin
      Item.Focusable := To;
      if not To and then Is_Attached (Item) and then Has_Focus (Item) then
         Release_Focus (Item);
      end if;
   end Set_Focusable;

   overriding
   function Is_Focusable (Item : Splitter) return Boolean
   is (Item.Focusable);

   overriding
   procedure Handle (Item : in out Splitter; Event : Pomarine.Events.Event; Handled : out Boolean) is
      Pixels : constant Float := Density (Item);
      Box    : constant Widget_Access := Before_Box (Item);
      X      : constant Float := Event.Mouse_X * Pixels;
      Y      : constant Float := Event.Mouse_Y * Pixels;
   begin
      Handled := False;
      if Box = null then
         return;
      end if;
      case Event.Kind is
         when Pomarine.Events.Mouse_Down =>
            if Event.Button = 1 and then Contains (Item, X, Y) then
               Item.Held := True;
               Item.Grab := (if Item.Down_Bar then Y - Top_Of (Item) else X - Left_Of (Item));
               Handled := True;
               Invalidate (Item);
            end if;

         when Pomarine.Events.Mouse_Move =>
            if Item.Held then
               --  Where the bar's start is to be, less where it was taken, from where the box starts.
               Make_It
                 (Item,
                  ((if Item.Down_Bar then Y - Item.Grab - Top_Of (Box.all) else X - Item.Grab - Left_Of (Box.all))
                   / Pixels),
                  Said => True);
               Handled := True;
            end if;

         when Pomarine.Events.Mouse_Up   =>
            if Event.Button = 1 and then Item.Held then
               Item.Held := False;
               Handled := True;
               Invalidate (Item);
            end if;

         when Pomarine.Events.Key_Down   =>
            if Has_Focus (Item) and then not Event.Command then
               if Event.Key = (if Item.Down_Bar then Pomarine.Events.Key_Up_Arrow else Pomarine.Events.Key_Left_Arrow)
               then
                  Make_It (Item, Position (Item) - Key_Step, Said => True);
                  Handled := True;
               elsif Event.Key
                 = (if Item.Down_Bar then Pomarine.Events.Key_Down_Arrow else Pomarine.Events.Key_Right_Arrow)
               then
                  Make_It (Item, Position (Item) + Key_Step, Said => True);
                  Handled := True;
               end if;
            end if;

         when others                     =>
            null;
      end case;
   end Handle;

   overriding
   procedure Hover_Changed (Item : in out Splitter; Hovered : Boolean) is
      pragma Unreferenced (Hovered);
   begin
      Invalidate (Item);
   end Hover_Changed;

   overriding
   procedure Focus_Changed (Item : in out Splitter; Focused : Boolean) is
      pragma Unreferenced (Focused);
   begin
      Invalidate (Item);
   end Focus_Changed;

   overriding
   function Cursor (Item : Splitter) return SDL3.Cursors.Kind
   is (if Item.Down_Bar then SDL3.Cursors.Resize_Up_Down else SDL3.Cursors.Resize_Across);

   overriding
   procedure Draw (Item : in out Splitter; Target : SDL3.Painters.Painter'Class; Colors : Themes.Theme) is
      Pixels : constant Float := Density (Item);
      Edge   : constant Float := Pomarine.Boxes.Edge (Pixels);
      Ink    : constant Themes.Color :=
        (if Item.Held
         then Colors (Themes.Accent)
         elsif Is_Hovered (Item)
         then Themes.Mix (Colors (Themes.Border), Colors (Themes.Foreground), 0.4)
         else Colors (Themes.Border));
   begin
      if Item.Down_Bar then
         Fill_Rect
           (Target, Ink, Left_Of (Item), Top_Of (Item) + (Height_Of (Item) - Edge) / 2.0, Width_Of (Item), Edge);
      else
         Fill_Rect
           (Target, Ink, Left_Of (Item) + (Width_Of (Item) - Edge) / 2.0, Top_Of (Item), Edge, Height_Of (Item));
      end if;
   end Draw;

   overriding
   procedure Draw_Over (Item : in out Splitter; Target : SDL3.Painters.Painter'Class; Colors : Themes.Theme) is
   begin
      if Item.Focusable and then Is_Focus_Visible (Item) then
         Pomarine.Boxes.Outline
           (Target,
            Colors (Themes.Focus),
            Left_Of (Item),
            Top_Of (Item),
            Width_Of (Item),
            Height_Of (Item),
            Thick   => Float'Max (1.0, Float'Rounding (Density (Item))),
            Density => Density (Item));
      end if;
   end Draw_Over;

   overriding
   procedure Describe (Item : Splitter; Facts : in out Semantics.Description) is
   begin
      if Facts.Kind = Semantics.Unknown then
         Facts.Kind := Semantics.Separator;
      end if;
      Facts.Actions (Semantics.Increment) := Item.Focusable;
      Facts.Actions (Semantics.Decrement) := Item.Focusable;
   end Describe;

   overriding
   procedure Perform (Item : in out Splitter; Request : Semantics.Request; Done : out Boolean) is
   begin
      Done := False;
      if Request.Doing = Semantics.Increment then
         Make_It (Item, Position (Item) + Key_Step, Said => True);
         Done := True;
      elsif Request.Doing = Semantics.Decrement then
         Make_It (Item, Position (Item) - Key_Step, Said => True);
         Done := True;
      end if;
   end Perform;

end Pomarine.Widgets.Splitters;
