with Ada.Strings.Unbounded;
with Pomarine.Text_Areas.Finding;
with Pomarine.Text_Areas.Geometry;
with Typeset.Layouts;

package body Pomarine.Text_Areas.Core is

   package Docs renames Texts.Documents;
   package Layouts renames Typeset.Layouts;

   use Geometry;
   use type Texts.Position;
   use type Docs.Version;

   procedure Restart_Blink (Item : in out Text_Area) is
   begin
      Item.Since := Item.Now;
      Item.Caret_On := True;
   end Restart_Blink;

   procedure Catch_Up (Item : in out Text_Area) is
      Seen         : Docs.Version renames Item.Seen;
      Relayout_Top : Boolean := False;
   begin
      if Item.Serial /= Docs.Serial (Item.Doc.all) or else Seen < Docs.Oldest (Item.Doc.all) then
         --  Too far behind: from the start.
         Item.Serial := Docs.Serial (Item.Doc.all);
         Item.At_Caret := (1, 1);
         Item.At_Mark := (1, 1);
         Item.Anchor := 1;
         Item.Offset := 0.0;
         Item.Composing := False;
         Item.Has_Goal := False;
         Item.Dragging := False;
      else
         while Seen < Docs.Current (Item.Doc.all) loop
            declare
               Done       : constant Docs.Change := Docs.Change_After (Item.Doc.all, Seen);
               Old_Anchor : constant Position := (Item.Anchor, 1);
               Moved_To   : constant Position := Docs.Map (Done, Old_Anchor);
            begin
               Seen := Seen + 1;
               Item.At_Caret := Docs.Map (Done, Item.At_Caret);
               Item.At_Mark := Docs.Map (Done, Item.At_Mark);
               if Item.Composing
                 and then not Done.Kind_Only
                 and then not Done.Formats_Only
                 and then Done.From < Composed_End (Item)
                 and then Item.Composed < Done.To
               then
                  --  Changed from elsewhere: it is now just text.
                  Item.Composing := False;
               elsif Item.Composing then
                  Item.Composed := Docs.Map (Done, Item.Composed);
               end if;

               --  What is shown stays where it was: by its paragraph, or
               --  if that went, down the page. The layout is as before
               --  the change, still.
               if Moved_To = Done.From
                 and then Old_Anchor /= Done.From
                 and then Item.Anchor <= Layouts.Count (Item.Laid)
               then
                  Item.Offset :=
                    Item.Offset + Layouts.Top (Item.Laid, Item.Anchor) - Layouts.Top (Item.Laid, Done.From.Paragraph);
               end if;
               if Item.Anchor = 1 and then Item.Offset = 0.0 and then Done.From = (1, 1) then
                  --  The top of the document stays visible when text is inserted there.
                  Item.Anchor := 1;
                  Relayout_Top := Relayout_Top or else Moved_To.Paragraph > 1;
               else
                  Item.Anchor := Moved_To.Paragraph;
               end if;
            end;
         end loop;
      end if;
      if Item.Search_Seen /= Docs.Current (Item.Doc.all) or else Item.Search_Serial /= Docs.Serial (Item.Doc.all) then
         Finding.Refresh (Item, Ada.Strings.Unbounded.To_String (Item.Search_Term));
      end if;
      Seen := Docs.Current (Item.Doc.all);
      Layouts.Sync (Item.Laid, Item.Doc.all);
      if Relayout_Top then
         Layouts.Lay_Out (Item.Laid, Item.Doc.all, 1);
      end if;
      Item.Anchor := Positive'Min (Item.Anchor, Count (Item));
      pragma Assert (Is_Position (Item, Item.At_Caret));
      pragma Assert (Is_Position (Item, Item.At_Mark));
   end Catch_Up;

   function Line_Of (Item : in out Text_Area; At_Point : Position) return Positive is
      At_Units : constant Natural := Units (Item, At_Point);
   begin
      Layouts.Lay_Out_To (Item.Laid, Item.Doc.all, At_Point.Paragraph, At_Units);
      return Layouts.Line_At (Item.Laid, At_Point.Paragraph, At_Units);
   end Line_Of;

   function Updated (Item : Text_Area; At_Point : Position) return Position is
      Result : Position := At_Point;
   begin
      if Item.Serial /= Docs.Serial (Item.Doc.all) or else Item.Seen < Docs.Oldest (Item.Doc.all) then
         return (1, 1);  --  as Catch_Up will have it

      end if;
      for Seen in Item.Seen .. Docs.Current (Item.Doc.all) - 1 loop
         Result := Docs.Map (Docs.Change_After (Item.Doc.all, Seen), Result);
      end loop;
      return Result;
   end Updated;

   function Selection_First (Item : Text_Area) return Position
   is (if Mark (Item) < Caret (Item) then Mark (Item) else Caret (Item));

   function Selection_Last (Item : Text_Area) return Position
   is (if Mark (Item) < Caret (Item) then Caret (Item) else Mark (Item));

   procedure Scroll_By (Item : in out Text_Area; By : Float) is
   begin
      Catch_Up (Item);
      if Item.Grows then
         return;  --  its owner scrolls

      end if;
      Layouts.Scroll (Item.Laid, Item.Anchor, Item.Offset, By, Extent (Item));
   end Scroll_By;

   procedure Reveal (Item : in out Text_Area) is
      Para     : constant Positive := Item.At_Caret.Paragraph;
      Number   : constant Positive := Line_Of (Item, Item.At_Caret);
      High     : constant Float := Layouts.Line_Height (Item.Laid, Para);
      Line_Top : constant Float := Layouts.Top (Item.Laid, Para) + Float (Number - 1) * High;
      Shown    : constant Float := View_Top (Item);
   begin
      if Line_Top < Shown or else Extent (Item) < High then
         Scroll_By (Item, Line_Top - Shown);
      elsif Line_Top + High > Shown + Extent (Item) then
         Scroll_By (Item, Line_Top + High - (Shown + Extent (Item)));
      end if;

      --  Once it has a place.
      if Item.Single and then Item.Width > 0.0 then
         declare
            X, Y, Wide, Tall : Float;
            Least            : constant Float := Item.Left + Inset (Item) + Lead_Room (Item);
            Most             : constant Float := Item.Left + Item.Width - Inset (Item) - Trail_Room (Item);
            Last             : constant Position := Last_Position (Item);
            Last_Line        : constant Positive := Line_Of (Item, Last);
            End_Across       : constant Float :=
              Layouts.Caret_Offset (Item.Laid, Item.Doc.all, Last.Paragraph, Last_Line, Units (Item, Last))
              * Scale (Item);
         begin
            if End_Across <= Most - Least then
               Item.Across_Scroll := 0.0;
               return;
            end if;
            Measure_Caret (Item, X, Y, Wide, Tall);
            if X < Least then
               Item.Across_Scroll := Float'Max (0.0, Item.Across_Scroll - (Least - X));
            elsif X + Wide > Most then
               Item.Across_Scroll := Item.Across_Scroll + (X + Wide - Most);
            end if;
         end;
      end if;
   end Reveal;

   procedure Moved (Item : in out Text_Area) is
   begin
      pragma Assert (Is_Position (Item, Item.At_Caret));
      pragma Assert (Is_Position (Item, Item.At_Mark));
      Restart_Blink (Item);
      Reveal (Item);
   end Moved;

   procedure Measure_Caret (Item : in out Text_Area; X, Y, Width, Height : out Float) is
   begin
      Catch_Up (Item);
      if not (Item.Caret_Kept
              and then Item.Caret_For = Item.At_Caret
              and then Item.Caret_Version = Item.Seen
              and then Item.Caret_Serial = Item.Serial
              and then Item.Caret_Width = Layouts.Width (Item.Laid))
      then
         --  Shaping the line to measure it is the cost: not the top of
         --  the paragraph, which moves as others are laid out.
         Item.Caret_Line := Line_Of (Item, Item.At_Caret);
         Item.Caret_Across :=
           Layouts.Caret_Offset
             (Item.Laid, Item.Doc.all, Item.At_Caret.Paragraph, Item.Caret_Line, Units (Item, Item.At_Caret));
         Item.Caret_For := Item.At_Caret;
         Item.Caret_Version := Item.Seen;
         Item.Caret_Serial := Item.Serial;
         Item.Caret_Width := Layouts.Width (Item.Laid);
         Item.Caret_Kept := True;
         Item.Caret_Worked := Item.Caret_Worked + 1;
      end if;
      declare
         Para     : constant Positive := Item.At_Caret.Paragraph;
         Number   : constant Positive := Item.Caret_Line;
         High     : constant Float := Layouts.Line_Height (Item.Laid, Para);
         Line_Top : constant Float := Layouts.Top (Item.Laid, Para) + Float (Number - 1) * High;
         Across   : constant Float := Item.Caret_Across;
      begin
         Width := Caret_Width * Item.Density;
         X := Column_Left (Item) + Across * Scale (Item) - Width / 2.0;
         Y := Text_Top (Item) + (Line_Top - View_Top (Item)) * Scale (Item);
         Height := High * Scale (Item);
      end;
   end Measure_Caret;

   procedure Change
     (Item     : in out Text_Area;
      From, To : Position;
      By       : String;
      Undo_As  : Docs.Edit_Kind := Docs.Other;
      Recorded : Boolean := True) is
   begin
      if Item.Read_Only then
         return;
      end if;
      Docs.Replace
        (Item.Doc.all,
         From,
         To,
         By,
         Undo_As,
         Recorded,
         Explicit_Formats => Item.Explicit_Formats,
         Formats          => Item.Pending_Formats,
         Sizing           => Item.Pending_Size,
         Facing           => Ada.Strings.Unbounded.To_String (Item.Pending_Family));
      Catch_Up (Item);
      Item.At_Caret := Texts.End_After (From, By);
      Item.At_Mark := Item.At_Caret;
   end Change;

   procedure Edit (Item : in out Text_Area; From, To : Position; By : String; Undo_As : Docs.Edit_Kind) is
   begin
      Item.Has_Goal := False;
      if From /= To or else By /= "" then
         Change (Item, From, To, By, Undo_As);
      end if;
      Moved (Item);
   end Edit;

   function Without_Returns (Raw : String) return String is
      Returns : Natural := 0;
   begin
      for C of Raw loop
         if C = ASCII.CR then
            Returns := Returns + 1;
         end if;
      end loop;
      if Returns = 0 then
         return Raw;
      end if;

      --  Made in place as the result, not on the stack: what is pasted
      --  may be megabytes.
      return Result : String (1 .. Raw'Length - Returns) do
         declare
            Last : Natural := 0;
         begin
            for C of Raw loop
               if C /= ASCII.CR then
                  Last := Last + 1;
                  Result (Last) := C;
               end if;
            end loop;
         end;
      end return;
   end Without_Returns;

   function Fitted (Item : Text_Area; Raw : String) return String is
      Result : String := Without_Returns (Raw);
   begin
      if Item.Single then
         for Char of Result loop
            if Char = ASCII.LF then
               Char := ' ';
            end if;
         end loop;
      end if;
      return Result;
   end Fitted;

   procedure Drop_Composition (Item : in out Text_Area) is
   begin
      Catch_Up (Item);
      if Item.Composing then
         Item.Composing := False;
         Change (Item, Item.Composed, Composed_End (Item), "", Recorded => False);
      end if;
   end Drop_Composition;

   procedure Finish_Composition (Item : in out Text_Area) is
   begin
      Catch_Up (Item);
      if Item.Composing then
         declare
            Composed : constant String := Docs.Between (Item.Doc.all, Item.Composed, Composed_End (Item));
            From     : constant Position := Item.Composed;
         begin
            Drop_Composition (Item);
            Change (Item, From, From, Composed);
         end;
      end if;
   end Finish_Composition;

end Pomarine.Text_Areas.Core;
