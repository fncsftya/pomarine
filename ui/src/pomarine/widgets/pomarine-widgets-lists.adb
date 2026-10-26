with Pomarine.Line_Texts;

package body Pomarine.Widgets.Lists is

   use type Pomarine.Events.Event_Kind;
   use type Pomarine.Events.Key_Code;
   use type Semantics.Role;
   use type Pomarine.Models.Model_Access;

   Pad : constant := 10.0;
   --  In points: between a row's edge and its text.

   --  Rows

   function Count (Item : List) return Natural is
     (if Item.Model = null then 0 else Pomarine.Models.Count (Item.Model.all));

   function Row_High (Item : List) return Float is
     (Float'Max (1.0, Float'Rounding (Item.Row_Points * Density (Item))));
   --  In pixels, whole.

   function Hidden_Points (Item : List) return Float is
     (Float'Max
        (0.0,
         (Float (Count (Item)) * Row_High (Item) - Height_Of (Item)) / Density (Item)));
   --  How much of the rows do not fit the box, in points.

   function Offset (Item : List) return Float is (Item.Moved);

   function First_Shown (Item : List) return Natural is
     (if Count (Item) = 0 or else Height_Of (Item) <= 0.0 then 0
      else 1 + Natural (Float'Floor (Item.Moved * Density (Item) / Row_High (Item))));

   function Last_Shown (Item : List) return Natural is
     (if Count (Item) = 0 or else Height_Of (Item) <= 0.0 then 0
      else Natural'Min
             (Count (Item),
              1 + Natural (Float'Floor
                             ((Item.Moved * Density (Item) + Height_Of (Item) - 1.0)
                              / Row_High (Item)))));

   function Top_Of_Row (Item : List; Row : Positive) return Float is
     (Top_Of (Item) - Item.Moved * Density (Item) + Float (Row - 1) * Row_High (Item));
   --  In pixels.

   function Row_At (Item : List; Y : Float) return Natural is
      Row : constant Float :=
        Float'Floor ((Y - Top_Of (Item) + Item.Moved * Density (Item)) / Row_High (Item));
   begin
      if Row < 0.0 or else Row >= Float (Count (Item)) then
         return 0;
      end if;
      return Natural (Row) + 1;
   end Row_At;
   --  The row at pixel Y; 0 if none.

   function Row_Of_Id (Item : List; Id : Natural) return Natural is
   begin
      if Item.Model = null or else Id = 0 then
         return 0;
      end if;
      for Row in 1 .. Count (Item) loop
         if Pomarine.Models.Row_Id (Item.Model.all, Row) = Id then
            return Row;
         end if;
      end loop;
      return 0;
   end Row_Of_Id;

   function Selected (Item : List) return Natural is (Row_Of_Id (Item, Item.Chosen));

   function Chosen_Id (Item : List) return Natural is (Item.Chosen);

   --  A row's buttons: squares as high as the row, side by side at its
   --  right end, before the bar, in the order the row has them.

   Part_Stride : constant := 2 ** 20;
   --  A part of a button is its row's id and, times this, which it is.

   function Button_Part (Row_Id : Positive; Action : Positive) return Positive is
     (Row_Id + Action * Part_Stride);

   function Present_Count (Content : Pomarine.Models.Row_Content) return Natural is
     (Pomarine.Models.Count_Actions (Content));

   function Cell_Left (Item : List; Shown, Place : Positive) return Float is
     (Left_Of (Item) + Width_Of (Item)
      - Float'Rounding (Scrollbars.Thickness * Density (Item))
      - Float (Shown - Place + 1) * Row_High (Item));
   --  Where the Placeth of Shown buttons begins, in pixels.

   function Action_At (Item : List; Row : Positive; X : Float) return Natural is
      Content : Pomarine.Models.Row_Content;
      Shown   : Natural := 0;
      Place   : Natural := 0;
   begin
      Pomarine.Models.Describe_Row (Item.Model.all, Row, Content);
      Shown := Present_Count (Content);
      for Number in Content.Actions'Range loop
         if Content.Actions (Number).Present then
            Place := Place + 1;
            if X >= Cell_Left (Item, Shown, Place)
              and then X < Cell_Left (Item, Shown, Place) + Row_High (Item)
            then
               return Number;
            end if;
         end if;
      end loop;
      return 0;
   end Action_At;
   --  Which of Row's buttons is at pixel X; 0 if none.

   --  Setting

   procedure Set_Model (Item : in out List; Model : not null Pomarine.Models.Model_Access) is
   begin
      Item.Model := Model;
      Item.Seen := Pomarine.Models.Version (Model.all);
      Item.Chosen := 0;
      Item.Moved := 0.0;
      Item.Over := 0;
      if Is_Attached (Item) then
         Invalidate (Item);
      end if;
   end Set_Model;

   procedure Set_Row_Height (Item : in out List; Points : Float) is
   begin
      if Points /= Item.Row_Points then
         Item.Row_Points := Points;
         if Is_Attached (Item) then
            Invalidate (Item);
         end if;
      end if;
   end Set_Row_Height;

   procedure Scroll_To (Item : in out List; To : Float) is
      Wanted : constant Float := Float'Min (Hidden_Points (Item), Float'Max (0.0, To));
   begin
      if Wanted /= Item.Moved then
         Item.Moved := Wanted;
         Invalidate (Item);
      end if;
   end Scroll_To;

   procedure Offset_Step (Item : in out Widget'Class; Value : Float);

   procedure Offset_Step (Item : in out Widget'Class; Value : Float) is
   begin
      Scroll_To (List (Item), Value);
   end Offset_Step;

   procedure Scroll_Smoothly (Item : in out List; To : Float; Milliseconds : Natural := 180) is
      Wanted : constant Float := Float'Min (Hidden_Points (Item), Float'Max (0.0, To));
   begin
      Animate (Item, Item.Moved, Wanted, Milliseconds, Ease_Out, Offset_Step'Access);
   end Scroll_Smoothly;

   procedure Reveal (Item : in out List; Row : Positive) is
      Pixels : constant Float := Density (Item);
      Top    : constant Float := Float (Row - 1) * Row_High (Item) / Pixels;
      Bottom : constant Float := Float (Row) * Row_High (Item) / Pixels;
      High   : constant Float := Height_Of (Item) / Pixels;
   begin
      if Top < Item.Moved then
         Scroll_Smoothly (Item, Top, 120);
      elsif Bottom > Item.Moved + High then
         Scroll_Smoothly (Item, Bottom - High, 120);
      end if;
   end Reveal;

   procedure Select_Row (Item : in out List; Row : Natural) is
      Now : constant Natural :=
        (if Row = 0 or else Item.Model = null then 0
         else Pomarine.Models.Row_Id (Item.Model.all, Row));
   begin
      if Now /= Item.Chosen then
         Item.Chosen := Now;
         if Is_Attached (Item) then
            Invalidate (Item);
         end if;
      end if;
      if Row > 0 and then Is_Placed (Item) then
         Reveal (Item, Row);
      end if;
   end Select_Row;

   procedure Select_Id (Item : in out List; Id : Natural) is
   begin
      Select_Row (Item, Row_Of_Id (Item, Id));
   end Select_Id;

   --  Events

   function Bar_Metrics (Item : List) return Scrollbars.Metrics is
     (Left    => Left_Of (Item), Top => Top_Of (Item),
      Width   => Width_Of (Item), Height => Height_Of (Item),
      Density => Density (Item),
      Start   => Item.Moved * Density (Item),
      Shown   => Height_Of (Item),
      Total   => Float (Count (Item)) * Row_High (Item),
      Horizontal => False);

   procedure Choose_Row (Item : in out List; Row : Positive) is
   begin
      Select_Row (Item, Row);
      Notify (Item, Choose, Row => Row);
   end Choose_Row;

   procedure Page_Rows (Item : List; Rows : out Positive) is
   begin
      Rows := Positive'Max (1, Natural (Height_Of (Item) / Row_High (Item)) - 1);
   end Page_Rows;

   overriding procedure Handle
     (Item    : in out List;
      Event   : Pomarine.Events.Event;
      Handled : out Boolean)
   is
      Pixels : constant Float := Density (Item);
      Under  : constant Natural :=
        (if Contains (Item, Event.Mouse_X * Pixels, Event.Mouse_Y * Pixels)
         then Row_At (Item, Event.Mouse_Y * Pixels) else 0);
   begin
      Handled := False;
      if Item.Model = null then
         return;
      end if;
      case Event.Kind is
         when Pomarine.Events.Mouse_Down | Pomarine.Events.Mouse_Move | Pomarine.Events.Mouse_Up =>
            declare
               Moved, Changed : Boolean;
               To : Float;
            begin
               Scrollbars.Handle
                 (Item.Bar, Event, Bar_Metrics (Item), Handled, Moved, To, Changed);
               if Moved then
                  Scroll_To (Item, To / Pixels);
               end if;
               if Changed or else Moved then
                  Invalidate (Item);
               end if;
               if Handled then
                  return;
               end if;
            end;
            if Event.Kind = Pomarine.Events.Mouse_Move then
               declare
                  Over_Button : constant Natural :=
                    (if Under > 0 then Action_At (Item, Under, Event.Mouse_X * Pixels) else 0);
               begin
                  if Under /= Item.Over or else Over_Button /= Item.Over_Action then
                     Item.Over := Under;
                     Item.Over_Action := Over_Button;
                     Invalidate (Item);
                  end if;
               end;
            elsif Event.Kind = Pomarine.Events.Mouse_Down
              and then Event.Button = 1 and then Under > 0
            then
               declare
                  Pressed : constant Natural := Action_At (Item, Under, Event.Mouse_X * Pixels);
               begin
                  if Pressed > 0 then
                     Notify (Item, Act, Row => Under, Action => Pressed);
                  else
                     Choose_Row (Item, Under);
                     Notify (Item, Click);
                     if Event.Clicks >= 2 then
                        Notify (Item, Double_Click);
                     end if;
                  end if;
               end;
               Handled := True;
            elsif Event.Kind = Pomarine.Events.Mouse_Down
              and then Event.Button = 1
              and then Contains (Item, Event.Mouse_X * Pixels, Event.Mouse_Y * Pixels)
            then
               --  Below the last row: nothing is chosen any more.
               Select_Row (Item, 0);
               Handled := True;
            end if;

         when Pomarine.Events.Mouse_Wheel =>
            if Contains (Item, Event.Mouse_X * Pixels, Event.Mouse_Y * Pixels) then
               Scroll_To (Item, Item.Moved - Event.Wheel_Y * 24.0);
               Handled := True;
            end if;

         when Pomarine.Events.Key_Down =>
            if Has_Focus (Item) and then not Event.Command then
               declare
                  Now  : constant Natural := Selected (Item);
                  Last : constant Natural := Count (Item);
                  Page : Positive;
                  To   : Natural := Now;
               begin
                  Page_Rows (Item, Page);
                  Handled := True;
                  if Event.Key = Pomarine.Events.Key_Down_Arrow then
                     To := Natural'Min (Last, Now + 1);
                  elsif Event.Key = Pomarine.Events.Key_Up_Arrow then
                     To := Natural'Max (1, Now - 1);
                  elsif Event.Key = Pomarine.Events.Key_Page_Down then
                     To := Natural'Min (Last, Now + Page);
                  elsif Event.Key = Pomarine.Events.Key_Page_Up then
                     To := Natural'Max (1, Now - Page);
                  elsif Event.Key = Pomarine.Events.Key_Home then
                     To := Natural'Min (1, Last);
                  elsif Event.Key = Pomarine.Events.Key_End then
                     To := Last;
                  elsif Event.Key = Pomarine.Events.Key_Return and then Now > 0 then
                     Notify (Item, Submit);
                     return;
                  elsif Now > 0
                    and then (Event.Key = Pomarine.Events.Key_Space
                              or else Event.Key = Pomarine.Events.Key_Delete
                              or else Event.Key = Pomarine.Events.Key_Backspace)
                  then
                     --  Space does a row's first button, and Delete or
                     --  Backspace its button that cannot be undone, if
                     --  it has one.
                     declare
                        Content : Pomarine.Models.Row_Content;
                        Number  : Natural := 0;
                     begin
                        Pomarine.Models.Describe_Row (Item.Model.all, Now, Content);
                        for Each in Content.Actions'Range loop
                           if Content.Actions (Each).Present
                             and then (Event.Key = Pomarine.Events.Key_Space or else Content.Actions (Each).Danger)
                             and then Number = 0
                           then
                              Number := Each;
                           end if;
                        end loop;
                        Handled := Number > 0;
                        if Handled then
                           Notify (Item, Act, Row => Now, Action => Number);
                        end if;
                     end;
                     return;
                  else
                     Handled := False;
                  end if;
                  if Handled and then To > 0 and then To /= Now then
                     Choose_Row (Item, To);
                  end if;
               end;
            end if;

         when others =>
            null;
      end case;
   end Handle;

   procedure Catch_Up (Item : in out List) is
   begin
      if Item.Model /= null
        and then Pomarine.Models.Version (Item.Model.all) /= Item.Seen
      then
         Item.Seen := Pomarine.Models.Version (Item.Model.all);
         --  Rows came or went: keep what shows within the rows, and let
         --  go of a choice that is gone.
         Item.Moved := Float'Min (Item.Moved, Hidden_Points (Item));
         if Item.Chosen /= 0 and then Row_Of_Id (Item, Item.Chosen) = 0 then
            Item.Chosen := 0;
         end if;
         Invalidate (Item);
      end if;
   end Catch_Up;

   overriding procedure Update (Item : in out List; Now : Pomarine.Events.Milliseconds) is
      pragma Unreferenced (Now);
   begin
      Catch_Up (Item);
   end Update;

   overriding procedure Hover_Changed (Item : in out List; Hovered : Boolean) is
   begin
      Scrollbars.Set_Pane (Item.Bar, Hovered);
      if not Hovered then
         Item.Over := 0;
         Item.Over_Action := 0;
      end if;
      Invalidate (Item);
   end Hover_Changed;

   overriding function Is_Focusable (Item : List) return Boolean is
     (Item.Model /= null);

   overriding procedure Focus_Changed (Item : in out List; Focused : Boolean) is
   begin
      Item.Has_Focus := Focused;
      Invalidate (Item);
   end Focus_Changed;

   overriding function Cursor (Item : List) return SDL3.Cursors.Kind is
     (if Item.Over /= 0 then SDL3.Cursors.Pointer else SDL3.Cursors.Default);

   --  Drawing

   overriding procedure Draw
     (Item   : in out List;
      Target : SDL3.Painters.Painter'Class;
      Colors : Themes.Theme)
   is
      Pixels : constant Float := Density (Item);
      High   : constant Float := Row_High (Item);
      Edge   : constant Float := Float'Max (1.0, Float'Rounding (Pixels));
      Gap    : constant Float := Float'Rounding (Pad * Pixels);
      Bar    : constant Float := Float'Rounding (Scrollbars.Thickness * Pixels);
      Part   : constant Pixel_Box := Painting_Part (Item);
   begin
      SDL3.Painters.Fill_Rect
        (Target, Colors (Themes.Page),
         Left_Of (Item), Top_Of (Item), Width_Of (Item), Height_Of (Item));
      if Item.Model = null then
         return;
      end if;
      for Row in Positive range Natural'Max (1, First_Shown (Item)) .. Last_Shown (Item) loop
         declare
            Top      : constant Float := Top_Of_Row (Item, Row);
            Chosen   : constant Boolean :=
              Pomarine.Models.Row_Id (Item.Model.all, Row) = Item.Chosen;
            Hot      : constant Boolean := Row = Item.Over and then not Chosen;
            Content  : Pomarine.Models.Row_Content;
            Ink      : Themes.Color;
            Faint    : Themes.Color;
            Shown    : Natural;
         begin
            --  Of the rows, only those the part to draw touches.
            if Top + High > Float (Part.Top) and then Top < Float (Part.Top + Part.Height) then
               Pomarine.Models.Describe_Row (Item.Model.all, Row, Content);
               Ink := (if Chosen then Colors (Themes.On_Accent)
                       elsif Content.Dimmed then Colors (Themes.Muted)
                       else Colors (Themes.Foreground));
               Shown := Present_Count (Content);
               Faint :=
                 (if Chosen then Colors (Themes.On_Accent)
                  else (case Content.Tone is
                           when Pomarine.Models.Plain    => Colors (Themes.Muted),
                           when Pomarine.Models.Good => Colors (Themes.Primary_Ink),
                           when Pomarine.Models.Bad => Colors (Themes.Danger_Ink)));
               if Chosen then
                  SDL3.Painters.Fill_Rect
                    (Target, Colors (Themes.Accent), Left_Of (Item), Top, Width_Of (Item), High);
               elsif Hot then
                  SDL3.Painters.Fill_Rect
                    (Target, Colors (Themes.Hover_Row), Left_Of (Item), Top, Width_Of (Item), High);
               end if;
               if Text_Lines (Item) /= null then
                  declare
                     Detail : constant String := Pomarine.Models.Detail_Of (Content);
                     Wide   : constant Float :=
                       (if Detail = "" then 0.0
                        else Line_Texts.Width
                               (Text_Lines (Item).all, Detail, Pixels * 0.9, Line_Texts.Regular));
                  begin
                     Line_Texts.Draw
                       (Text_Lines (Item).all, Target, Ink,
                        Pomarine.Models.Text_Of (Content),
                        Left_Of (Item) + Gap, Top + High / 2.0, Pixels, Line_Texts.Regular);
                     if Detail /= "" then
                        Line_Texts.Draw
                          (Text_Lines (Item).all, Target, Faint, Detail,
                           Left_Of (Item) + Width_Of (Item) - Gap - Bar - Float (Shown) * High - Wide + Gap / 2.0,
                           Top + High / 2.0, Pixels * 0.9, Line_Texts.Regular);
                     end if;
                  end;
               else
                  SDL3.Painters.Draw_Text
                    (Target, Ink, Left_Of (Item) + Gap,
                     Float'Rounding (Top + (High - 8.0) / 2.0),
                     Pomarine.Models.Text_Of (Content), 1);
               end if;
               --  The buttons at the end.
               declare
                  Place : Natural := 0;
                  Size  : constant Positive := Positive'Max (1, Natural (Float'Rounding (16.0 * Pixels)));
               begin
                  for Number in Content.Actions'Range loop
                     if Content.Actions (Number).Present then
                        Place := Place + 1;
                        declare
                           Cell  : constant Float := Cell_Left (Item, Shown, Place);
                           Both  : constant Themes.Color :=
                             (if Chosen then Colors (Themes.On_Accent)
                              elsif Content.Actions (Number).Danger then Colors (Themes.Danger_Ink)
                              elsif Content.Dimmed then Colors (Themes.Muted)
                              else Colors (Themes.Foreground));
                           Drawn : Boolean;
                        begin
                           if Row = Item.Over and then Number = Item.Over_Action then
                              SDL3.Painters.Fill_Rect
                                (Target, Colors (Themes.Tint), Cell, Top, High, High);
                           end if;
                           if Icon_Library (Item) /= null then
                              Icons.Draw
                                (Icon_Library (Item).all, Target, Content.Actions (Number).Icon, Both,
                                 Float'Rounding (Cell + (High - Float (Size)) / 2.0),
                                 Float'Rounding (Top + (High - Float (Size)) / 2.0), Size, Drawn);
                           end if;
                        end;
                     end if;
                  end loop;
               end;
            end if;
         end;
      end loop;
      --  The ring of the focus, inside the box.
      if Item.Has_Focus and then Is_Focus_Visible (Item) then
         declare
            Ring : constant Themes.Color := Colors (Themes.Focus);
         begin
            SDL3.Painters.Fill_Rect (Target, Ring, Left_Of (Item), Top_Of (Item), Width_Of (Item), Edge);
            SDL3.Painters.Fill_Rect
              (Target, Ring, Left_Of (Item), Top_Of (Item) + Height_Of (Item) - Edge, Width_Of (Item), Edge);
            SDL3.Painters.Fill_Rect (Target, Ring, Left_Of (Item), Top_Of (Item), Edge, Height_Of (Item));
            SDL3.Painters.Fill_Rect
              (Target, Ring, Left_Of (Item) + Width_Of (Item) - Edge, Top_Of (Item), Edge, Height_Of (Item));
         end;
      end if;
   end Draw;

   overriding procedure Draw_Over
     (Item   : in out List;
      Target : SDL3.Painters.Painter'Class;
      Colors : Themes.Theme) is
   begin
      if Item.Model /= null then
         Scrollbars.Draw (Item.Bar, Target, Colors, Bar_Metrics (Item));
      end if;
   end Draw_Over;

   --  What it is to an assistive technology

   overriding procedure Describe
     (Item  : List;
      Facts : in out Semantics.Description) is
   begin
      if Facts.Kind = Semantics.Unknown then
         Facts.Kind := Semantics.List;
      end if;
      Facts.Focusable := Item.Model /= null;
      Facts.Set_Size := Count (Item);
      Facts.Actions (Semantics.Focus) := Item.Model /= null;
      Facts.Actions (Semantics.Scroll_Up) := True;
      Facts.Actions (Semantics.Scroll_Down) := True;
   end Describe;

   overriding procedure Perform
     (Item    : in out List;
      Request : Semantics.Request;
      Done    : out Boolean)
   is
      Page : constant Float := 0.9 * Height_Of (Item) / Density (Item);
   begin
      Done := True;
      case Request.Doing is
         when Semantics.Scroll_Up   => Scroll_Smoothly (Item, Item.Moved - Page);
         when Semantics.Scroll_Down => Scroll_Smoothly (Item, Item.Moved + Page);
         when others                => Done := False;
      end case;
   end Perform;

   function Row_Parts (Item : List) return Natural is
     (if First_Shown (Item) = 0 then 0
      else Last_Shown (Item) - First_Shown (Item) + 1);
   --  How many rows are described.

   function Button_Parts (Item : List) return Natural is
      Found   : Natural := 0;
      Content : Pomarine.Models.Row_Content;
   begin
      for Row in Positive range Natural'Max (1, First_Shown (Item)) .. Last_Shown (Item) loop
         Pomarine.Models.Describe_Row (Item.Model.all, Row, Content);
         Found := Found + Present_Count (Content);
      end loop;
      return Found;
   end Button_Parts;
   --  How many buttons the rows described have.

   overriding function Part_Count (Item : List) return Natural is
     (if Item.Model = null then 0 else Row_Parts (Item) + Button_Parts (Item));
   --  The rows, and then the buttons of the rows in turn.

   overriding function Part_Number (Item : List; Index : Positive) return Positive is
      Rows    : constant Natural := Row_Parts (Item);
      Seen    : Natural := Rows;
      Content : Pomarine.Models.Row_Content;
   begin
      if Index <= Rows then
         return Pomarine.Models.Row_Id (Item.Model.all, First_Shown (Item) + Index - 1);
      end if;
      for Row in Positive range Natural'Max (1, First_Shown (Item)) .. Last_Shown (Item) loop
         Pomarine.Models.Describe_Row (Item.Model.all, Row, Content);
         for Number in Content.Actions'Range loop
            if Content.Actions (Number).Present then
               Seen := Seen + 1;
               if Seen = Index then
                  return Pomarine.Models.Row_Id (Item.Model.all, Row) + Number * Part_Stride;
               end if;
            end if;
         end loop;
      end loop;
      return 1;
   end Part_Number;

   overriding procedure Describe_Part
     (Item   : List;
      Part   : Positive;
      Facts  : in out Semantics.Description;
      Bounds : out Semantics.Rectangle)
   is
      Number  : constant Natural := Part / Part_Stride;
      Row     : constant Natural := Row_Of_Id (Item, Part mod Part_Stride);
      Content : Pomarine.Models.Row_Content;
   begin
      Facts.Kind := (if Number > 0 then Semantics.Button else Semantics.List_Item);
      Bounds := (others => 0.0);
      if Row = 0 then
         return;
      end if;
      Pomarine.Models.Describe_Row (Item.Model.all, Row, Content);
      if Number > 0 then
         if Number > Pomarine.Models.Max_Actions or else not Content.Actions (Number).Present then
            return;
         end if;
         Semantics.Name_As (Facts, Pomarine.Models.Action_Name (Content, Number));
         Facts.Actions (Semantics.Click) := True;
         declare
            Place : Natural := 0;
         begin
            for Each in 1 .. Number loop
               if Content.Actions (Each).Present then
                  Place := Place + 1;
               end if;
            end loop;
            Bounds :=
              (Left   => Cell_Left (Item, Present_Count (Content), Place),
               Top    => Top_Of_Row (Item, Row),
               Right  => Cell_Left (Item, Present_Count (Content), Place) + Row_High (Item),
               Bottom => Top_Of_Row (Item, Row) + Row_High (Item));
         end;
         return;
      end if;
      Semantics.Name_As (Facts, Pomarine.Models.Text_Of (Content));
      Semantics.Help_As (Facts, Pomarine.Models.Detail_Of (Content));
      Facts.Selected := Part = Item.Chosen;
      Facts.Position := Row;
      Facts.Set_Size := Count (Item);
      Facts.Actions (Semantics.Click) := True;
      Facts.Actions (Semantics.Scroll_Into_View) := True;
      Bounds :=
        (Left   => Left_Of (Item),
         Top    => Top_Of_Row (Item, Row),
         Right  => Left_Of (Item) + Width_Of (Item),
         Bottom => Top_Of_Row (Item, Row) + Row_High (Item));
   end Describe_Part;

   overriding procedure Perform_Part
     (Item    : in out List;
      Part    : Positive;
      Request : Semantics.Request;
      Done    : out Boolean)
   is
      Number : constant Natural := Part / Part_Stride;
      Row    : constant Natural := Row_Of_Id (Item, Part mod Part_Stride);
   begin
      Done := Row > 0;
      if not Done then
         return;
      end if;
      if Number > 0 then
         Done := Semantics."=" (Request.Doing, Semantics.Click);
         if Done then
            Notify (Item, Act, Row => Row, Action => Number);
         end if;
         return;
      end if;
      case Request.Doing is
         when Semantics.Click =>
            Choose_Row (Item, Row);
         when Semantics.Scroll_Into_View =>
            Reveal (Item, Row);
         when others =>
            Done := False;
      end case;
   end Perform_Part;

end Pomarine.Widgets.Lists;
