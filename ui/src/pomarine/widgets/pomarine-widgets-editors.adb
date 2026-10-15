with Texts;
package body Pomarine.Widgets.Editors is

   use type Semantics.Role;

   package Docs renames Texts.Documents;

   Icon_Size : constant Float := 12.0;
   Icon_Room : constant Float := 18.0;
   --  In points: of the icon before a single line, and the room it is in.

   use type Docs.Version;
   use type Texts.Position;

   procedure Configure
     (Item    : in out Editor;
      Family  : String;
      Size    : Float;
      Measure : Float;
      Spacing : Float := 0.0) is
   begin
      Text_Areas.Configure (Item.Text, Family, Size, Measure, Spacing);
   end Configure;

   function Is_Configured (Item : Editor) return Boolean is
     (Text_Areas.Is_Configured (Item.Text));

   procedure Set_Shared
     (Item   : in out Editor;
      Shared : not null Shared_Access) is
   begin
      Text_Areas.Set_Shared (Item.Text, Shared);
   end Set_Shared;

   procedure Attach
     (Item : in out Editor; Doc : not null Texts.Documents.Document_Access) is
   begin
      Text_Areas.Attach (Item.Text, Doc);
      if Is_Attached (Item) then
         Invalidate (Item);
      end if;
   end Attach;

   function Has_Document (Item : Editor) return Boolean is
     (Text_Areas.Is_Attached (Item.Text));

   function Zoom (Item : Editor) return Float is (Item.Zoomed);

   procedure Set_Zoom (Item : in out Editor; To : Float) is
   begin
      if To /= Item.Zoomed then
         Item.Zoomed := To;
         if Is_Placed (Item) then
            --  Now, not at the next layout, which may be after an event
            --  for the text.
            Placed (Item, Left_Of (Item), Top_Of (Item), Width_Of (Item),
                    Height_Of (Item));
            Invalidate (Item);
         end if;
      end if;
   end Set_Zoom;

   procedure Set_Invalid (Item : in out Editor; To : Boolean) is
   begin
      if To /= Item.Invalid then
         Item.Invalid := To;
         if Is_Attached (Item) then
            Invalidate (Item);
         end if;
      end if;
   end Set_Invalid;

   function Is_Invalid (Item : Editor) return Boolean is (Item.Invalid);

   procedure Set_Enabled (Item : in out Editor; To : Boolean) is
   begin
      if To /= Item.Enabled then
         Item.Enabled := To;
         if Is_Attached (Item) then
            if not To and then Has_Focus (Item) then
               Release_Focus (Item);
            end if;
            Invalidate (Item);
         end if;
      end if;
   end Set_Enabled;

   function Is_Enabled (Item : Editor) return Boolean is (Item.Enabled);

   procedure Set_Placeholder (Item : in out Editor; Text : String) is
   begin
      Item.Hint_Length := Text'Length;
      Item.Hint (1 .. Text'Length) := Text;
      if Is_Attached (Item) then
         Invalidate (Item);
      end if;
   end Set_Placeholder;

   procedure Set_Icon (Item : in out Editor; To : Pomarine.Icons.Icon) is
   begin
      Item.Iconed := True;
      Item.Which := To;
      Text_Areas.Set_Lead (Item.Text, Icon_Room);
      if Is_Attached (Item) then
         Invalidate (Item);
      end if;
   end Set_Icon;

   procedure Clear_Icon (Item : in out Editor) is
   begin
      if Item.Iconed then
         Item.Iconed := False;
         Text_Areas.Set_Lead (Item.Text, 0.0);
         if Is_Attached (Item) then
            Invalidate (Item);
         end if;
      end if;
   end Clear_Icon;

   function Is_Focused (Item : Editor) return Boolean is
     (Text_Areas.Is_Focused (Item.Text));

   procedure Caret_Box
     (Item : in out Editor;
      X, Y, Width, Height : out Float) is
   begin
      Text_Areas.Caret_Box (Item.Text, X, Y, Width, Height);
   end Caret_Box;

   function Area (Item : in out Editor)
      return not null access Pomarine.Text_Areas.Text_Area is
     (Item.Text'Unchecked_Access);

   overriding procedure Placed
     (Item : in out Editor; Left, Top, Width, Height : Float) is
   begin
      pragma Assert
        (Is_Configured (Item), "an editor must be configured to be placed");
      --  Hidden, it has no room: it keeps where it was, rather than be
      --  wrapped to nothing and then wrapped again.
      if Width > 0.0 and then Height > 0.0 then
         Text_Areas.Place
           (Item.Text, Left, Top, Width, Height,
            Density => Density (Item), Zoom => Item.Zoomed);
      end if;
   end Placed;

   procedure Set_Paper (Item : in out Editor; To : Themes.Slot) is
   begin
      Item.Has_Paper := True;
      Item.Paper := To;
      Invalidate (Item);
   end Set_Paper;

   overriding procedure Draw
     (Item   : in out Editor;
      Target : SDL3.Painters.Painter'Class;
      Colors : Themes.Theme) is
   begin
      if Has_Document (Item) then
         --  Of the lines, only those the part to draw touches.
         declare
            Part  : constant Pixel_Box := Painting_Part (Item);
            Paper : constant Themes.Color :=
              (if not Item.Enabled then Colors (Themes.Tint)
               elsif Item.Has_Paper then Themes.Resolve (Colors, Item.Paper)
               else Colors (Themes.Page));
            Shown : constant Themes.Theme :=
              Themes.With_Slot
                (Themes.With_Slot
                   (Themes.With_Slot
                      (Themes.With_Slot
                         (Colors, Themes.Background, Paper),
                       Themes.Selection,
                       Themes.Mix (Paper, Colors (Themes.Accent), 0.4)),
                    Themes.Foreground,
                    (if Item.Enabled then Colors (Themes.Foreground)
                     else Colors (Themes.Muted))),
                 Themes.Border,
                 (if Item.Invalid then Colors (Themes.Danger) else Colors (Themes.Border)));
            Faint : constant Themes.Color :=
              Themes.Mix (Colors (Themes.Foreground), Paper, 0.55);
            Pixels : constant Float := Density (Item);
         begin
            Text_Areas.Draw
              (Item.Text, Target, Shown, Is_Settled (Item),
               Rows_From => Float (Part.Top),
               Rows_To   => Float (Part.Top + Part.Height));
            if Item.Hint_Length > 0 and then Text_Lines (Item) /= null
              and then Docs.Count (Text_Areas.Document (Item.Text).all) = 1
              and then Docs.Length (Text_Areas.Document (Item.Text).all, 1)
                       = 0
            then
               Pomarine.Line_Texts.Draw
                 (Text_Lines (Item).all, Target, Faint,
                  Item.Hint (1 .. Item.Hint_Length),
                  Text_Areas.Line_Left (Item.Text),
                  Text_Areas.Line_Middle (Item.Text),
                  Pixels * Item.Zoomed);
            end if;
            if Item.Iconed and then Icon_Library (Item) /= null then
               declare
                  Size  : constant Positive :=
                    Positive (Float'Rounding (Icon_Size * Pixels));
                  Drawn : Boolean;
               begin
                  Pomarine.Icons.Draw
                    (Icon_Library (Item).all, Target, Item.Which, Faint,
                     Float'Rounding
                       (Text_Areas.Lead_Left (Item.Text)
                        + (Icon_Room - Icon_Size) / 2.0 * Pixels),
                     Float'Rounding
                       (Text_Areas.Line_Middle (Item.Text)
                        - Float (Size) / 2.0),
                     Size, Drawn);
               end;
            end if;
         end;
         Item.Shown := Docs.Current (Text_Areas.Document (Item.Text).all);
         Item.Shown_Serial :=
           Docs.Serial (Text_Areas.Document (Item.Text).all);
      end if;
   end Draw;

   overriding procedure Handle
     (Item    : in out Editor;
      Event   : SDL3.Events.Event;
      Handled : out Boolean) is
   begin
      Handled := False;
      if Has_Document (Item) and then Item.Enabled then
         Text_Areas.Handle (Item.Text, Event, Clipboard (Item).all, Handled);
         if Text_Areas.Return_Pending (Item.Text)
           and then Event.Kind in SDL3.Events.Key_Down
           and then Event.Key in SDL3.Events.Key_Return
         then
            Notify (Item, Submit);
         end if;
         declare
            Changed : Boolean;
         begin
            Text_Areas.Take_Bar_Change (Item.Text, Changed);
            if Handled or else Changed then
               Invalidate (Item);
            end if;
         end;
         --  Escape, for one, leaves it unfocused.
         if Has_Focus (Item) and then not Is_Focused (Item) then
            Release_Focus (Item);
         end if;
      end if;
   end Handle;

   overriding procedure Update
     (Item : in out Editor; Now : SDL3.Events.Milliseconds)
   is
      Blinked : Boolean;
   begin
      if not Has_Document (Item) then
         return;
      end if;
      Text_Areas.Tick (Item.Text, Now, Blinked);
      if Blinked then
         --  Only the caret changes.
         declare
            X, Y, Wide, High : Float;
         begin
            Text_Areas.Caret_Box (Item.Text, X, Y, Wide, High);
            Invalidate
              (Item,
               (Left   => Integer (Float'Floor (X)) - 1,
                Top    => Integer (Float'Floor (Y)) - 1,
                Width  => Integer (Float'Ceiling (Wide)) + 3,
                Height => Integer (Float'Ceiling (High)) + 3));
         end;
      end if;
      --  Where the caret and the selection are is part of what an
      --  assistive technology is told.
      if Text_Areas.Caret (Item.Text) /= Item.Told_Caret
        or else Text_Areas.Mark (Item.Text) /= Item.Told_Mark
      then
         Item.Told_Caret := Text_Areas.Caret (Item.Text);
         Item.Told_Mark := Text_Areas.Mark (Item.Text);
         Mark_Dirty (Item, Semantics_Dirty);
      end if;
      --  The document may have been changed from elsewhere.
      declare
         Doc : constant Docs.Document_Access :=
           Text_Areas.Document (Item.Text);
      begin
         if Docs.Current (Doc.all) /= Item.Shown
           or else Docs.Serial (Doc.all) /= Item.Shown_Serial
         then
            Invalidate (Item);
         end if;
      end;
   end Update;

   overriding function Until_Update (Item : Editor) return Integer is
     (if Has_Document (Item) and then Is_Focused (Item)
      then Integer (Text_Areas.Until_Blink (Item.Text)) else -1);

   overriding function Accepts_Focus (Item : Editor) return Boolean is
     (Has_Document (Item) and then Item.Enabled);

   overriding procedure Hover_Changed
     (Item : in out Editor; Hovered : Boolean) is
   begin
      if Has_Document (Item) then
         Text_Areas.Set_Hovered (Item.Text, Hovered);
         Invalidate (Item);
      end if;
   end Hover_Changed;

   overriding procedure Focus_Changed
     (Item : in out Editor; Focused : Boolean) is
   begin
      if Has_Document (Item) then
         Text_Areas.Set_Focus (Item.Text, Focused);
         Invalidate (Item);
      end if;
   end Focus_Changed;

   Paragraphs_Told : constant := 24;
   --  How many paragraphs each side of the caret an assistive technology
   --  is told of, of a long text: the rest it asks for by moving.

   function First_Told (Item : Editor) return Positive;
   function Last_Told (Item : Editor) return Positive;
   --  The paragraphs told of: those near the caret.

   function First_Told (Item : Editor) return Positive is
     (if not Has_Document (Item) then 1
      else Positive'Max
             (1, Text_Areas.Caret (Item.Text).Paragraph - Paragraphs_Told));

   function Last_Told (Item : Editor) return Positive is
     (if not Has_Document (Item) then 1
      else Positive'Min
             (Docs.Count (Text_Areas.Document (Item.Text).all),
              Text_Areas.Caret (Item.Text).Paragraph + Paragraphs_Told));

   function Characters_Before
     (Doc : Docs.Document; Para : Positive; Index : Positive) return Natural;
   --  How many characters of the paragraph are before byte Index.

   function Characters_Before
     (Doc : Docs.Document; Para : Positive; Index : Positive) return Natural
   is
      Count : Natural := 0;
   begin
      if Index = 1 then
         return 0;
      end if;
      for C of Docs.Slice (Doc, Para, 1, Index) loop
         if not Texts.Is_Continuation (C) then
            Count := Count + 1;
         end if;
      end loop;
      return Count;
   end Characters_Before;

   function Byte_After
     (Doc : Docs.Document; Para : Positive; Characters : Natural) return Positive;
   --  The byte index that many characters into the paragraph, or its end.

   function Byte_After
     (Doc : Docs.Document; Para : Positive; Characters : Natural) return Positive
   is
      Text  : constant String := Docs.Text (Doc, Para);
      Seen  : Natural := 0;
   begin
      for Index in Text'Range loop
         if not Texts.Is_Continuation (Text (Index)) then
            if Seen = Characters then
               return Index;
            end if;
            Seen := Seen + 1;
         end if;
      end loop;
      return Text'Last + 1;
   end Byte_After;

   overriding procedure Describe
     (Item  : Editor;
      Facts : in out Semantics.Description) is
   begin
      if Facts.Kind = Semantics.Unknown then
         Facts.Kind :=
           (if Has_Document (Item) and then Text_Areas.Is_Single_Line (Item.Text)
            then Semantics.Text_Input else Semantics.Multiline_Text_Input);
      end if;
      Facts.Disabled := not Item.Enabled;
      Facts.Invalid := Item.Invalid;
      Facts.Focusable := Item.Enabled and then Has_Document (Item);
      if Item.Hint_Length > 0 then
         Semantics.Help_As (Facts, Item.Hint (1 .. Item.Hint_Length));
      end if;
      if not Has_Document (Item) then
         return;
      end if;
      declare
         Doc    : constant Docs.Document_Access := Text_Areas.Document (Item.Text);
         Anchor : constant Texts.Position := Text_Areas.Mark (Item.Text);
         Caret  : constant Texts.Position := Text_Areas.Caret (Item.Text);
         First  : constant Positive := First_Told (Item);
         Last   : constant Positive := Last_Told (Item);

         function Place_Of (At_Point : Texts.Position) return Semantics.Text_Place is
            Para : constant Positive :=
              Positive'Max (First, Positive'Min (Last, At_Point.Paragraph));
            Byte : constant Positive :=
              (if Para = At_Point.Paragraph then At_Point.Index
               elsif Para < At_Point.Paragraph
               then Docs.Byte_Length (Doc.all, Para) + 1 else 1);
         begin
            return (Part => Positive (Docs.Id (Doc.all, Para)),
                    Characters => Characters_Before (Doc.all, Para, Byte));
         end Place_Of;
      begin
         if Docs.Count (Doc.all) = 1 then
            Semantics.Value_As (Facts, Docs.Text (Doc.all, 1));
         end if;
         Facts.Has_Selection := True;
         Facts.Anchor := Place_Of (Anchor);
         Facts.Caret := Place_Of (Caret);
      end;
      Facts.Actions (Semantics.Focus) := Item.Enabled;
      Facts.Actions (Semantics.Replace_Selected_Text) := Item.Enabled;
      Facts.Actions (Semantics.Set_Value) := Item.Enabled;
      Facts.Actions (Semantics.Set_Text_Selection) := True;
   end Describe;

   overriding function Part_Count (Item : Editor) return Natural is
     (if Has_Document (Item) then Last_Told (Item) - First_Told (Item) + 1 else 0);

   overriding function Part_Number (Item : Editor; Index : Positive) return Positive is
     (Positive (Docs.Id (Text_Areas.Document (Item.Text).all, First_Told (Item) + Index - 1)));

   overriding procedure Describe_Part
     (Item   : Editor;
      Part   : Positive;
      Facts  : in out Semantics.Description;
      Bounds : out Semantics.Rectangle)
   is
      Doc  : constant Docs.Document_Access := Text_Areas.Document (Item.Text);
      Para : constant Natural := Docs.Find (Doc.all, Texts.Paragraph_Id (Part));
   begin
      Facts.Kind := Semantics.Text_Run;
      if Para > 0 then
         Semantics.Value_As (Facts, Docs.Text (Doc.all, Para));
      end if;
      --  Where each line is drawn is the text area's; the whole is told.
      Bounds := (Left => Left_Of (Item), Top => Top_Of (Item),
                 Right => Left_Of (Item) + Width_Of (Item),
                 Bottom => Top_Of (Item) + Height_Of (Item));
   end Describe_Part;

   overriding procedure Perform
     (Item    : in out Editor;
      Request : Semantics.Request;
      Done    : out Boolean) is
   begin
      Done := False;
      if not Has_Document (Item) or else not Item.Enabled then
         return;
      end if;
      declare
         Doc : constant Docs.Document_Access := Text_Areas.Document (Item.Text);
      begin
         case Request.Doing is
            when Semantics.Replace_Selected_Text =>
               Text_Areas.Insert (Item.Text, Semantics.To_String (Request.Contents));
               Invalidate (Item);
               Done := True;
            when Semantics.Set_Value =>
               Text_Areas.Select_All (Item.Text);
               Text_Areas.Insert (Item.Text, Semantics.To_String (Request.Contents));
               Invalidate (Item);
               Done := True;
            when Semantics.Set_Text_Selection =>
               declare
                  function At_Place (Part, Characters : Natural) return Texts.Position is
                     Para : constant Natural :=
                       Docs.Find (Doc.all, Texts.Paragraph_Id (Positive'Max (1, Part)));
                  begin
                     if Para = 0 then
                        return Text_Areas.Caret (Item.Text);
                     end if;
                     return (Paragraph => Para,
                             Index => Byte_After (Doc.all, Para, Characters));
                  end At_Place;
               begin
                  Text_Areas.Select_Range
                    (Item.Text,
                     At_Place (Request.Anchor_Part, Request.Anchor),
                     At_Place (Request.Focus_Part, Request.Focus));
                  Invalidate (Item);
                  Done := True;
               end;
            when others =>
               null;
         end case;
      end;
   end Perform;

   overriding procedure Command_State_Changed
     (Item : in out Editor; State : Command_State) is
   begin
      Set_Enabled (Item, State in Enabled | Ticked);
   end Command_State_Changed;

   overriding procedure Handle_Command
     (Item : in out Editor; Tag : Integer; Done : out Boolean) is
   begin
      Done := False;
      if not Has_Document (Item) or else not Item.Enabled then
         return;
      end if;
      Done := True;
      if Tag = Edit_Undo then
         Text_Areas.Undo (Item.Text);
      elsif Tag = Edit_Redo then
         Text_Areas.Redo (Item.Text);
      elsif Tag = Edit_Cut then
         Text_Areas.Cut (Item.Text, Clipboard (Item).all);
      elsif Tag = Edit_Copy then
         Text_Areas.Copy (Item.Text, Clipboard (Item).all);
      elsif Tag = Edit_Paste then
         Text_Areas.Paste (Item.Text, Clipboard (Item).all);
      elsif Tag = Edit_Select_All then
         Text_Areas.Select_All (Item.Text);
      else
         Done := False;
      end if;
      if Done then
         Invalidate (Item);
      end if;
   end Handle_Command;

end Pomarine.Widgets.Editors;
