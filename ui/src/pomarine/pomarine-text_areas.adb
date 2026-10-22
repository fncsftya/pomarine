with Ada.Strings.Fixed;
with Pomarine.Boxes;
with SDL3.Windows;
with SDL3.Windows.Renderers;
with CoreText.Wrapping;
package body Pomarine.Text_Areas is

   package Docs renames Texts.Documents;
   package Layouts renames Typeset.Layouts;
   package Views renames Typeset.Views;
   package Events renames SDL3.Events;

   use type Events.Key_Code;
   use type Texts.Paragraph_Kind;
   use type Events.Event_Kind;
   use type Docs.Version;
   use type Texts.Position;
   use type Docs.Document_Access;

   --  In points
   Outline       : constant Float := 1.0;
   Focus_Outline : constant Float := 2.0;
   Padding       : constant Float := 12.0;
   Line_Padding  : constant Float := 6.0;  --  of a field for one line
   --  From the outside of the outline to the text.
   Caret_Width   : constant Float := 1.5;
   Underline     : constant Float := 1.0;
   Underline_Gap : constant Float := 2.0;  --  below the baseline

   Lines_Per_Notch : constant Float := 3.0;
   Page_Fraction   : constant Float := 0.9;
   --  How much of what is shown Page Up and Page Down move.

   Most_Lines : constant := 1_000_000;

   --  Geometry

   function Scale (Item : Text_Area) return Float is
     (Item.Density * Item.Zoom);
   --  Pixels to a layout unit.

   function Inset (Item : Text_Area) return Float is
     ((if Item.Single then Line_Padding else Padding) * Item.Density);

   function Lead_Room (Item : Text_Area) return Float is
     (if Item.Single then Float'Rounding (Item.Lead * Item.Density)
      else 0.0);
   --  Before a single line, in pixels: see Set_Lead.

   function Trail_Room (Item : Text_Area) return Float is
     (if Item.Single then Float'Rounding (Item.Trail * Item.Density)
      else 0.0);
   --  After a single line, in pixels: see Set_Trail.

   function Has_Toolbar (Item : Text_Area) return Boolean is
     (Item.Toolbar and then not Item.Single and then not Item.Read_Only);

   function Toolbar_Room (Item : Text_Area) return Float is
     (if Has_Toolbar (Item) then Toolbar_Points * Item.Density else 0.0);
   --  In pixels: the toolbar is in the top of the text area, above the
   --  padding, and the text is below it.

   function Top_Room (Item : Text_Area) return Float is
     (Toolbar_Room (Item) + Inset (Item));
   --  From the top of the text area to its text, in pixels.

   function Text_Top (Item : Text_Area) return Float is
     (if Item.Single
      then Item.Top + Float'Max
             (Inset (Item),
              (Item.Height - Layouts.Line_Height (Item.Laid) * Scale (Item))
              / 2.0)
      else Item.Top + Top_Room (Item));
   --  A line for one line is in the middle of its height.

   function Side (Item : Text_Area) return Float is
     (Inset (Item) + (if Item.Single then 0.0 else Item.Indent * Item.Density));
   --  From the side of the text area to its text, in pixels.

   function Text_Width (Item : Text_Area) return Float is
     (Float'Max
        (0.0,
         Item.Width - 2.0 * Side (Item) - Lead_Room (Item)
         - Trail_Room (Item)));

   function Text_Height (Item : Text_Area) return Float is
     (Float'Max (0.0, Item.Height - Inset (Item) - Top_Room (Item)));

   function Column (Item : Text_Area) return Float is
     (if Item.Single then Item.Measure
      else Float'Max
        (1.0, Float'Min (Item.Measure, Text_Width (Item) / Scale (Item))));
   --  How wide its lines may be, in layout units.

   function Column_Left (Item : Text_Area) return Float is
     (if Item.Single
      then Item.Left + Inset (Item) + Lead_Room (Item) - Item.Across_Scroll
      else Item.Left + Side (Item)
      + Float'Max
          (0.0, (Text_Width (Item) - Column (Item) * Scale (Item)) / 2.0));
   --  Where its lines start, in pixels.

   function Extent (Item : Text_Area) return Float is
     (Text_Height (Item) / Scale (Item));
   --  How much of the text is shown, in layout units.

   function View_Top (Item : Text_Area) return Float is
     (Layouts.Top (Item.Laid, Item.Anchor) + Item.Offset);
   --  Of what is shown, down the text, in layout units.

   --  The document

   function Is_Position (Item : Text_Area; At_Point : Position)
      return Boolean is
     (Docs.Is_Position (Item.Doc.all, At_Point));

   function Paragraph_End (Item : Text_Area; Para : Positive)
      return Position is
     (Docs.Paragraph_End (Item.Doc.all, Para));

   function Text_End (Item : Text_Area) return Position is
     (Docs.Text_End (Item.Doc.all));

   function Byte_Length (Item : Text_Area; Para : Positive) return Natural is
     (Docs.Byte_Length (Item.Doc.all, Para));

   function Count (Item : Text_Area) return Positive is
     (Docs.Count (Item.Doc.all));

   function Units (Item : Text_Area; At_Point : Position) return Natural is
     (Docs.Units_Before (Item.Doc.all, At_Point.Paragraph, At_Point.Index));
   --  Where At_Point is in its paragraph's lines.

   function Composed_End (Item : Text_Area) return Position is
     ((Item.Composed.Paragraph,
       Item.Composed.Index + Item.Composed_Length));

   procedure Restart_Blink (Item : in out Text_Area);
   --  Show the caret, for a period from now.

   procedure Restart_Blink (Item : in out Text_Area) is
   begin
      Item.Since := Item.Now;
      Item.Caret_On := True;
   end Restart_Blink;

   procedure Catch_Up (Item : in out Text_Area);
   --  Bring the caret, the selection and what is shown along with the
   --  document's changes since they were last seen, and lay it out.

   procedure Catch_Up (Item : in out Text_Area) is
      Seen : Docs.Version renames Item.Seen;
   begin
      if Item.Serial /= Docs.Serial (Item.Doc.all)
        or else Seen < Docs.Oldest (Item.Doc.all)
      then
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
               Done : constant Docs.Change :=
                 Docs.Change_After (Item.Doc.all, Seen);
               Old_Anchor : constant Position := (Item.Anchor, 1);
               Moved_To   : constant Position :=
                 Docs.Map (Done, Old_Anchor);
            begin
               Seen := Seen + 1;
               Item.At_Caret := Docs.Map (Done, Item.At_Caret);
               Item.At_Mark := Docs.Map (Done, Item.At_Mark);
               if Item.Composing
                 and then not Done.Kind_Only and then not Done.Formats_Only
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
               if Moved_To = Done.From and then Old_Anchor /= Done.From
                 and then Item.Anchor <= Layouts.Count (Item.Laid)
               then
                  Item.Offset := Item.Offset
                    + Layouts.Top (Item.Laid, Item.Anchor)
                    - Layouts.Top (Item.Laid, Done.From.Paragraph);
               end if;
               Item.Anchor := Moved_To.Paragraph;
            end;
         end loop;
      end if;
      Seen := Docs.Current (Item.Doc.all);
      Layouts.Sync (Item.Laid, Item.Doc.all);
      Item.Anchor := Positive'Min (Item.Anchor, Count (Item));
      pragma Assert (Is_Position (Item, Item.At_Caret));
      pragma Assert (Is_Position (Item, Item.At_Mark));
   end Catch_Up;

   function Line_Of
     (Item : in out Text_Area; At_Point : Position) return Positive;
   --  The line At_Point is on, of its paragraph, laid out.

   function Line_Of
     (Item : in out Text_Area; At_Point : Position) return Positive
   is
      At_Units : constant Natural := Units (Item, At_Point);
   begin
      Layouts.Lay_Out_To
        (Item.Laid, Item.Doc.all, At_Point.Paragraph, At_Units);
      return Layouts.Line_At (Item.Laid, At_Point.Paragraph, At_Units);
   end Line_Of;

   --  Setting up

   procedure Configure
     (Item    : in out Text_Area;
      Family  : String;
      Size    : Float;
      Measure : Float;
      Spacing : Float := 0.0) is
   begin
      Item.Measure := Measure;
      Item.Caret_Kept := False;
      Layouts.Configure (Item.Laid, Family, Size, Measure, Spacing);
   end Configure;

   function Is_Configured (Item : Text_Area) return Boolean is
     (Layouts.Is_Configured (Item.Laid));

   procedure Set_Shared
     (Item   : in out Text_Area;
      Shared : not null Shared_Access) is
   begin
      Views.Set_Shared (Item.View, Shared);
   end Set_Shared;

   procedure Set_Single_Line (Item : in out Text_Area; To : Boolean := True)
   is
   begin
      Item.Single := To;
      Item.Across_Scroll := 0.0;
      Item.Returned := False;
      Item.Caret_Kept := False;
   end Set_Single_Line;

   function Is_Single_Line (Item : Text_Area) return Boolean is
     (Item.Single);

   procedure Set_Read_Only (Item : in out Text_Area; To : Boolean := True) is
   begin
      Item.Read_Only := To;
   end Set_Read_Only;

   function Is_Read_Only (Item : Text_Area) return Boolean is
     (Item.Read_Only);

   procedure Set_Lead (Item : in out Text_Area; Points : Float) is
   begin
      Item.Lead := Points;
   end Set_Lead;

   procedure Set_Trail (Item : in out Text_Area; Points : Float) is
   begin
      Item.Trail := Points;
   end Set_Trail;

   function Lead_Left (Item : Text_Area) return Float is
     (Item.Left + Inset (Item));

   function Line_Left (Item : Text_Area) return Float is
     (Column_Left (Item));

   function Line_Middle (Item : Text_Area) return Float is
     (Text_Top (Item) + Layouts.Line_Height (Item.Laid) * Scale (Item) / 2.0);

   procedure Set_Toolbar (Item : in out Text_Area; To : Boolean := True) is
   begin
      Item.Toolbar := To;
   end Set_Toolbar;

   procedure Set_Radius (Item : in out Text_Area; Points : Float) is
   begin
      Item.Radius := Points;
   end Set_Radius;

   procedure Set_Indent (Item : in out Text_Area; Points : Float) is
   begin
      Item.Indent := Points;
   end Set_Indent;

   procedure Set_Grows (Item : in out Text_Area; To : Boolean := True) is
   begin
      Item.Grows := To;
      Item.Anchor := 1;
      Item.Offset := 0.0;
   end Set_Grows;

   function Is_Growing (Item : Text_Area) return Boolean is (Item.Grows);

   function Content_Height (Item : in out Text_Area) return Float is
   begin
      Catch_Up (Item);
      for Para in 1 .. Layouts.Count (Item.Laid) loop
         if not Layouts.Is_Complete (Item.Laid, Para) then
            Layouts.Lay_Out (Item.Laid, Item.Doc.all, Para);
         end if;
      end loop;
      return Layouts.Total_Height (Item.Laid) * Item.Zoom
        + 2.0 * Padding + (if Has_Toolbar (Item) then Toolbar_Points else 0.0);
   end Content_Height;

   function Return_Pending (Item : Text_Area) return Boolean is (Item.Returned);

   procedure Take_Return (Item : in out Text_Area; Pressed : out Boolean) is
   begin
      Pressed := Item.Returned;
      Item.Returned := False;
   end Take_Return;

   procedure Attach (Item : in out Text_Area; Doc : not null Document_Access)
   is
   begin
      Item.Doc := Doc;
      Item.Explicit_Formats := False;
      Clear_Highlights (Item);
      Item.Serial := 0;  --  start again
      Item.Caret_Kept := False;
      Catch_Up (Item);
      Restart_Blink (Item);
   end Attach;

   function Is_Attached (Item : Text_Area) return Boolean is
     (Item.Doc /= null);

   function Document (Item : Text_Area) return Document_Access is
     (Item.Doc);

   procedure Reveal (Item : in out Text_Area);
   --  Scroll as little as brings the caret's line into view, and, for one
   --  line, across to it.

   procedure Place
     (Item    : in out Text_Area;
      Left, Top, Width, Height : Float;
      Density : Float;
      Zoom    : Float := 1.0) is
   begin
      Item.Left := Left;
      Item.Top := Top;
      Item.Width := Width;
      Item.Height := Height;
      Item.Density := Density;
      Item.Zoom := Zoom;
      if Layouts.Width (Item.Laid) /= Column (Item) then
         Layouts.Set_Width (Item.Laid, Column (Item));
      end if;
      if Item.Single and then Item.Doc /= null then
         Catch_Up (Item);
         Reveal (Item);
      end if;
   end Place;

   function Contains (Item : Text_Area; X, Y : Float) return Boolean is
     (X >= Item.Left and then X < Item.Left + Item.Width
      and then Y >= Item.Top and then Y < Item.Top + Item.Height);

   function Is_Focused (Item : Text_Area) return Boolean is (Item.Focused);

   function Updated (Item : Text_Area; At_Point : Position) return Position;
   --  Where At_Point, as the text area last saw the document, is now:
   --  another view may have changed it since.

   function Updated (Item : Text_Area; At_Point : Position) return Position
   is
      Result : Position := At_Point;
   begin
      if Item.Serial /= Docs.Serial (Item.Doc.all)
        or else Item.Seen < Docs.Oldest (Item.Doc.all)
      then
         return (1, 1);  --  as Catch_Up will have it
      end if;
      for Seen in Item.Seen .. Docs.Current (Item.Doc.all) - 1 loop
         Result := Docs.Map (Docs.Change_After (Item.Doc.all, Seen), Result);
      end loop;
      return Result;
   end Updated;

   function Caret (Item : Text_Area) return Position is
     (Updated (Item, Item.At_Caret));

   function Mark (Item : Text_Area) return Position is
     (Updated (Item, Item.At_Mark));

   function Has_Selection (Item : Text_Area) return Boolean is
     (Mark (Item) /= Caret (Item));

   function Selection_First (Item : Text_Area) return Position is
     (if Mark (Item) < Caret (Item) then Mark (Item) else Caret (Item));

   function Selection_Last (Item : Text_Area) return Position is
     (if Mark (Item) < Caret (Item) then Caret (Item) else Mark (Item));

   function Selected_Text (Item : Text_Area) return String is
     (Docs.Between
        (Item.Doc.all, Selection_First (Item), Selection_Last (Item)));

   --  Scrolling

   procedure Scroll (Item : in out Text_Area; By : Float) is
   begin
      Catch_Up (Item);
      if Item.Grows then
         return;  --  its owner scrolls
      end if;
      Layouts.Scroll (Item.Laid, Item.Anchor, Item.Offset, By, Extent (Item));
   end Scroll;

   function Scroll_Top (Item : Text_Area) return Float is (View_Top (Item));

   procedure Scroll_To (Item : in out Text_Area; Top : Float) is
   begin
      Catch_Up (Item);
      if Item.Grows then
         return;
      end if;
      Item.Anchor := 1;
      Item.Offset := 0.0;
      Layouts.Scroll (Item.Laid, Item.Anchor, Item.Offset, Top, Extent (Item));
   end Scroll_To;

   procedure Reveal (Item : in out Text_Area) is
      Para     : constant Positive := Item.At_Caret.Paragraph;
      Number   : constant Positive := Line_Of (Item, Item.At_Caret);
      High     : constant Float := Layouts.Line_Height (Item.Laid, Para);
      Line_Top : constant Float :=
        Layouts.Top (Item.Laid, Para) + Float (Number - 1) * High;
      Shown    : constant Float := View_Top (Item);
   begin
      if Line_Top < Shown or else Extent (Item) < High then
         Scroll (Item, Line_Top - Shown);
      elsif Line_Top + High > Shown + Extent (Item) then
         Scroll (Item, Line_Top + High - (Shown + Extent (Item)));
      end if;

      --  Once it has a place.
      if Item.Single and then Item.Width > 0.0 then
         declare
            X, Y, Wide, Tall : Float;
            Least : constant Float :=
              Item.Left + Inset (Item) + Lead_Room (Item);
            Most  : constant Float :=
              Item.Left + Item.Width - Inset (Item) - Trail_Room (Item);
         begin
            Caret_Box (Item, X, Y, Wide, Tall);
            if X < Least then
               Item.Across_Scroll :=
                 Float'Max (0.0, Item.Across_Scroll - (Least - X));
            elsif X + Wide > Most then
               Item.Across_Scroll := Item.Across_Scroll + (X + Wide - Most);
            end if;
         end;
      end if;
   end Reveal;

   procedure Moved (Item : in out Text_Area);
   --  The caret or the text changed: show the caret, and bring it into
   --  view.

   procedure Moved (Item : in out Text_Area) is
   begin
      pragma Assert (Is_Position (Item, Item.At_Caret));
      pragma Assert (Is_Position (Item, Item.At_Mark));
      Restart_Blink (Item);
      Reveal (Item);
   end Moved;

   --  Changing the text

   procedure Change
     (Item     : in out Text_Area;
      From, To : Position;
      By       : String;
      Undo_As  : Docs.Edit_Kind := Docs.Other;
      Recorded : Boolean := True)
     with Pre => Is_Position (Item, From) and then Is_Position (Item, To)
                 and then not (To < From);
   --  Replace the text from From to To with By, and put the caret after
   --  it, with nothing selected.

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
      Docs.Replace (Item.Doc.all, From, To, By, Undo_As, Recorded,
                    Explicit_Formats => Item.Explicit_Formats, Formats => Item.Pending_Formats,
                    Sizing => Item.Pending_Size,
                    Facing => Ada.Strings.Unbounded.To_String (Item.Pending_Family));
      Catch_Up (Item);
      Item.At_Caret := Texts.End_After (From, By);
      Item.At_Mark := Item.At_Caret;
   end Change;

   procedure Edit
     (Item     : in out Text_Area;
      From, To : Position;
      By       : String;
      Undo_As  : Docs.Edit_Kind)
     with Pre => Is_Position (Item, From) and then Is_Position (Item, To)
                 and then not (To < From);
   --  Replace the text from From to To with By, to undo, with the caret
   --  after it, and bring it into view.

   procedure Edit
     (Item     : in out Text_Area;
      From, To : Position;
      By       : String;
      Undo_As  : Docs.Edit_Kind) is
   begin
      Item.Has_Goal := False;
      if From /= To or else By /= "" then
         Change (Item, From, To, By, Undo_As);
      end if;
      Moved (Item);
   end Edit;

   function Without_Returns (Raw : String) return String;
   --  Raw without carriage returns, as from CR LF line ends.

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

   --  Input methods' text

   function Is_Composing (Item : Text_Area) return Boolean is
     (Item.Composing);

   procedure Drop_Composition (Item : in out Text_Area);
   --  Take the input method's text away, leaving the caret where it was.

   procedure Drop_Composition (Item : in out Text_Area) is
   begin
      Catch_Up (Item);
      if Item.Composing then
         Item.Composing := False;
         Change (Item, Item.Composed, Composed_End (Item), "",
                 Recorded => False);
      end if;
   end Drop_Composition;

   procedure Finish_Composition (Item : in out Text_Area);
   --  Keep the input method's text as if it were typed: before anything
   --  else is done.

   procedure Finish_Composition (Item : in out Text_Area) is
   begin
      Catch_Up (Item);
      if Item.Composing then
         declare
            Composed : constant String :=
              Docs.Between (Item.Doc.all, Item.Composed, Composed_End (Item));
            From     : constant Position := Item.Composed;
         begin
            Drop_Composition (Item);
            Change (Item, From, From, Composed);
         end;
      end if;
   end Finish_Composition;

   procedure Compose
     (Item   : in out Text_Area;
      Shown  : String;
      Cursor : Natural)
   is
      Clean : String := Without_Returns (Shown);
   begin
      if Item.Read_Only then
         return;
      end if;
      Catch_Up (Item);
      for C of Clean loop
         if C = ASCII.LF then
            C := ' ';
         end if;
      end loop;

      if not Item.Composing and then Clean /= "" then
         if Has_Selection (Item) then
            Edit (Item, Selection_First (Item), Selection_Last (Item), "",
                  Docs.Other);
         end if;
         Item.Composed := Item.At_Caret;
      elsif Item.Composing then
         Drop_Composition (Item);
      end if;

      if Clean /= "" then
         Change (Item, Item.Composed, Item.Composed, Clean,
                 Recorded => False);
         Item.Composing := True;
         Item.Composed_Length := Clean'Length;

         --  The caret after Cursor characters.
         declare
            Byte : Positive := Item.Composed.Index;
            Seen : Natural := 0;
         begin
            while Seen < Cursor and then Byte < Composed_End (Item).Index
            loop
               Byte := Layouts.Next_Character
                 (Item.Doc.all, Item.Composed.Paragraph, Byte);
               Seen := Seen + 1;
            end loop;
            Item.At_Caret := (Item.Composed.Paragraph, Byte);
            Item.At_Mark := Item.At_Caret;
         end;
      end if;
      Item.Has_Goal := False;
      Moved (Item);
   end Compose;

   --  Focus

   procedure Set_Focus (Item : in out Text_Area; Focused : Boolean) is
   begin
      if not Focused then
         Finish_Composition (Item);
         Item.Dragging := False;
      elsif not Item.Focused then
         Restart_Blink (Item);
      end if;
      Item.Focused := Focused;
   end Set_Focus;

   --  Moving

   procedure Select_Range (Item : in out Text_Area; From, To : Position) is
   begin
      Item.Explicit_Formats := False;
      Finish_Composition (Item);
      Item.At_Mark := From;
      Item.At_Caret := To;
      Item.Has_Goal := False;
      Docs.Seal (Item.Doc.all);
      Moved (Item);
   end Select_Range;

   procedure Select_All (Item : in out Text_Area) is
   begin
      Catch_Up (Item);
      Select_Range (Item, (1, 1), Text_End (Item));
   end Select_All;

   function Step
     (Item : in out Text_Area;
      From : Position;
      By   : Motion) return Position
     with Pre => By not in Previous_Line | Next_Line;
   --  Where the caret goes from From.

   function Step
     (Item : in out Text_Area;
      From : Position;
      By   : Motion) return Position
   is
      Doc_Of   : Docs.Document renames Item.Doc.all;
      Para     : constant Positive := From.Paragraph;
      Byte     : constant Positive := From.Index;
      At_Start : constant Boolean := Byte = 1;
      At_End   : constant Boolean := Byte > Byte_Length (Item, Para);
   begin
      case By is
         when Previous_Character | Previous_Word =>
            if not At_Start then
               return
                 (Para,
                  (if By = Previous_Word
                   then Layouts.Previous_Word (Doc_Of, Para, Byte)
                   else Layouts.Previous_Character (Doc_Of, Para, Byte)));
            elsif Para > 1 then
               return Paragraph_End (Item, Para - 1);
            end if;

         when Next_Character | Next_Word =>
            if not At_End then
               return
                 (Para,
                  (if By = Next_Word
                   then Layouts.Next_Word (Doc_Of, Para, Byte)
                   else Layouts.Next_Character (Doc_Of, Para, Byte)));
            elsif Para < Count (Item) then
               return (Para + 1, 1);
            end if;

         when Line_Start =>
            declare
               Number : constant Positive := Line_Of (Item, From);
            begin
               return
                 (Para,
                  Docs.Index_Of
                    (Doc_Of, Para,
                     Layouts.Line (Item.Laid, Para, Number).First));
            end;

         when Line_End =>
            declare
               Number : constant Positive := Line_Of (Item, From);
            begin
               if Layouts.Line (Item.Laid, Para, Number).Stop
                 < Docs.Length (Doc_Of, Para)
               then
                  --  Before the space the line breaks after.
                  return
                    (Para,
                     Docs.Index_Of
                       (Doc_Of, Para,
                        Layouts.Units_At_Offset
                          (Item.Laid, Doc_Of, Para, Number, Float'Last)));
               end if;
               return Paragraph_End (Item, Para);
            end;

         when Paragraph_Start =>
            if not At_Start then
               return (Para, 1);
            elsif Para > 1 then
               return (Para - 1, 1);
            end if;

         when Paragraph_End =>
            if not At_End then
               return Paragraph_End (Item, Para);
            elsif Para < Count (Item) then
               return Paragraph_End (Item, Para + 1);
            end if;

         when Text_Start =>
            return (1, 1);

         when Text_End =>
            return Text_End (Item);

         when Previous_Line | Next_Line =>
            raise Program_Error;
      end case;
      return From;
   end Step;

   function Line_Position
     (Item   : in out Text_Area;
      Para   : Positive;
      Number : Positive;
      X      : Float) return Position;
   --  The position on line Number of paragraph Para, laid out, nearest X
   --  layout units across.

   function Line_Position
     (Item   : in out Text_Area;
      Para   : Positive;
      Number : Positive;
      X      : Float) return Position is
   begin
      return
        (Para,
         Docs.Index_Of
           (Item.Doc.all, Para,
            Layouts.Units_At_Offset
              (Item.Laid, Item.Doc.all, Para, Number, X)));
   end Line_Position;

   function Vertical_Step
     (Item : in out Text_Area;
      By   : Motion) return Position
     with Pre => By in Previous_Line | Next_Line;
   --  Where the caret goes a line up or down, as near the goal as can
   --  be.

   function Vertical_Step
     (Item : in out Text_Area;
      By   : Motion) return Position
   is
      Para   : constant Positive := Item.At_Caret.Paragraph;
      Number : constant Positive := Line_Of (Item, Item.At_Caret);
   begin
      if not Item.Has_Goal then
         Item.Goal := Layouts.Caret_Offset
           (Item.Laid, Item.Doc.all, Para, Number,
            Units (Item, Item.At_Caret));
         Item.Has_Goal := True;
      end if;

      if By = Previous_Line then
         if Number > 1 then
            return Line_Position (Item, Para, Number - 1, Item.Goal);
         elsif Para > 1 then
            Layouts.Lay_Out (Item.Laid, Item.Doc.all, Para - 1);
            return Line_Position
              (Item, Para - 1, Layouts.Line_Count (Item.Laid, Para - 1),
               Item.Goal);
         end if;
         return (1, 1);
      end if;

      Layouts.Lay_Out (Item.Laid, Item.Doc.all, Para, Number + 1);
      if Number < Layouts.Line_Count (Item.Laid, Para) then
         return Line_Position (Item, Para, Number + 1, Item.Goal);
      elsif Para < Count (Item) then
         Layouts.Lay_Out (Item.Laid, Item.Doc.all, Para + 1, 1);
         return Line_Position (Item, Para + 1, 1, Item.Goal);
      end if;
      return Text_End (Item);
   end Vertical_Step;

   procedure Move
     (Item   : in out Text_Area;
      By     : Motion;
      Extend : Boolean := False) is
   begin
      Item.Explicit_Formats := False;
      Finish_Composition (Item);
      Docs.Seal (Item.Doc.all);
      if By not in Previous_Line | Next_Line then
         Item.Has_Goal := False;
      end if;

      if not Extend and then Has_Selection (Item)
        and then By in Previous_Character | Next_Character
      then
         Item.At_Caret :=
           (if By = Previous_Character then Selection_First (Item)
            else Selection_Last (Item));
      elsif By in Previous_Line | Next_Line then
         Item.At_Caret := Vertical_Step (Item, By);
      else
         Item.At_Caret := Step (Item, Item.At_Caret, By);
      end if;

      if not Extend then
         Item.At_Mark := Item.At_Caret;
      end if;
      Moved (Item);
   end Move;

   --  The mouse

   function Point_At (Item : in out Text_Area; X, Y : Float)
      return Position;
   --  The position nearest pixel X, Y.

   function Point_At (Item : in out Text_Area; X, Y : Float)
      return Position
   is
      Depth : constant Float :=
        View_Top (Item) + (Y - Text_Top (Item)) / Scale (Item);
      Para  : constant Positive := Layouts.Paragraph_At (Item.Laid, Depth);
      High : constant Float := Layouts.Line_Height (Item.Laid, Para);
      Within : constant Float :=
        Float'Max (0.0, Depth - Layouts.Top (Item.Laid, Para)) / High;
      Wanted : constant Positive :=
        (if Within >= Float (Most_Lines) then Most_Lines
         else Natural (Float'Floor (Within)) + 1);
   begin
      Layouts.Lay_Out (Item.Laid, Item.Doc.all, Para, Wanted);
      return Line_Position
        (Item, Para,
         Positive'Min (Wanted, Layouts.Line_Count (Item.Laid, Para)),
         (X - Column_Left (Item)) / Scale (Item));
   end Point_At;

   function Is_Over_Selection
     (Item : in out Text_Area; X, Y : Float) return Boolean is
   begin
      if not Has_Selection (Item) then
         return False;
      end if;
      Catch_Up (Item);
      declare
         Point : constant Position := Point_At (Item, X, Y);
         First : constant Position :=
           (if Item.At_Caret < Item.At_Mark then Item.At_Caret
            else Item.At_Mark);
         Last  : constant Position :=
           (if Item.At_Caret < Item.At_Mark then Item.At_Mark
            else Item.At_Caret);
      begin
         return not (Point < First) and then Point < Last;
      end;
   end Is_Over_Selection;

   function Is_Over_Range
     (Item : in out Text_Area; From, To : Position; X, Y : Float) return Boolean
   is
   begin
      if not Contains (Item, X, Y) then
         return False;
      end if;
      Catch_Up (Item);
      declare
         Depth : constant Float := View_Top (Item) + (Y - Text_Top (Item)) / Scale (Item);
         Para : constant Positive := Layouts.Paragraph_At (Item.Laid, Depth);
         High : constant Float := Layouts.Line_Height (Item.Laid, Para);
         Within : constant Float := (Depth - Layouts.Top (Item.Laid, Para)) / High;
      begin
         if Para not in From.Paragraph .. To.Paragraph or else Within < 0.0
           or else Within >= Float (Most_Lines)
         then
            return False;
         end if;
         declare
            Number : constant Positive := Natural (Float'Floor (Within)) + 1;
         begin
            Layouts.Lay_Out (Item.Laid, Item.Doc.all, Para, Number);
            if Number > Layouts.Line_Count (Item.Laid, Para) then
               return False;
            end if;
            declare
               Line : constant CoreText.Wrapping.Span := Layouts.Line (Item.Laid, Para, Number);
               First : constant Natural := Natural'Max
                 (Line.First, (if Para = From.Paragraph then Units (Item, From) else 0));
               Last : constant Natural := Natural'Min
                 (Line.Stop, (if Para = To.Paragraph then Units (Item, To) else Line.Stop));
            begin
               if First >= Last then
                  return False;
               end if;
               declare
                  Left : constant Float := Column_Left (Item) + Scale (Item)
                    * Layouts.Caret_Offset (Item.Laid, Item.Doc.all, Para, Number, First);
                  Right : constant Float := Column_Left (Item) + Scale (Item)
                    * Layouts.Caret_Offset (Item.Laid, Item.Doc.all, Para, Number, Last);
               begin
                  return X >= Float'Min (Left, Right) and then X < Float'Max (Left, Right);
               end;
            end;
         end;
      end;
   end Is_Over_Range;

   procedure Click
     (Item   : in out Text_Area;
      X, Y   : Float;
      Clicks : Positive := 1;
      Extend : Boolean := False)
   is
      Point : Position;
   begin
      Item.Explicit_Formats := False;
      Finish_Composition (Item);
      Docs.Seal (Item.Doc.all);
      Point := Point_At (Item, X, Y);
      Item.Focused := True;
      Item.Dragging := True;
      Item.Drag_Words := Clicks = 2 and then not Extend;
      Item.Has_Goal := False;

      if Clicks = 1 or else Extend then
         Item.At_Caret := Point;
         if not Extend then
            Item.At_Mark := Point;
         end if;
      elsif Clicks = 2 then
         declare
            First, Stop : Positive;
         begin
            Layouts.Word_At
              (Item.Doc.all, Point.Paragraph, Point.Index, First, Stop);
            --  Not on a word: the character there.
            if First = Stop
              and then Point.Index <= Byte_Length (Item, Point.Paragraph)
            then
               Stop := Layouts.Next_Character
                 (Item.Doc.all, Point.Paragraph, Point.Index);
            end if;
            Item.At_Mark := (Point.Paragraph, First);
            Item.At_Caret := (Point.Paragraph, Stop);
         end;
      else
         Item.At_Mark := (Point.Paragraph, 1);
         Item.At_Caret := Paragraph_End (Item, Point.Paragraph);
      end if;
      Item.Drag_First := Item.At_Mark;
      Item.Drag_Stop := Item.At_Caret;
      Moved (Item);
   end Click;

   procedure Drag (Item : in out Text_Area; X, Y : Float) is
   begin
      Catch_Up (Item);
      if Item.Dragging then
         declare
            Point : constant Position := Point_At (Item, X, Y);
            First, Stop : Positive;
         begin
            if Item.Drag_Words then
               pragma Assert (not (Item.Drag_Stop < Item.Drag_First));
               Layouts.Word_At (Item.Doc.all, Point.Paragraph, Point.Index, First, Stop);
               if Point < Item.Drag_First then
                  Item.At_Mark := Item.Drag_Stop;
                  Item.At_Caret := (Point.Paragraph, First);
               else
                  Item.At_Mark := Item.Drag_First;
                  Item.At_Caret := (if Point < Item.Drag_Stop then Item.Drag_Stop else (Point.Paragraph, Stop));
               end if;
            else
               Item.At_Caret := Point;
            end if;
         end;
         Moved (Item);
      end if;
   end Drag;

   procedure Release (Item : in out Text_Area) is
   begin
      Item.Dragging := False;
   end Release;

   function Is_Dragging (Item : Text_Area) return Boolean is
     (Item.Dragging);

   --  Editing

   function Fitted (Item : Text_Area; Raw : String) return String;
   --  What of Raw to put in the text: without carriage returns, and for
   --  one line, with spaces for line feeds.

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

   function Format_Active (Item : Text_Area; Style : Docs.Format) return Boolean is
      From : Position := Selection_First (Item);
   begin
      if Item.Explicit_Formats and then not Has_Selection (Item) then
         return Item.Pending_Formats (Style);
      end if;
      if not Has_Selection (Item) and then From.Index > 1 then
         From.Index := From.Index - 1;
         while not Docs.Is_Boundary (Item.Doc.all, From.Paragraph, From.Index) loop
            From.Index := From.Index - 1;
         end loop;
      end if;
      return Docs.Has_Format (Item.Doc.all, From, Selection_Last (Item), Style);
   end Format_Active;

   procedure Start_Pending (Item : in out Text_Area);
   --  Have the formats of the text at the caret be what is typed next, to change.

   procedure Toggle_Format (Item : in out Text_Area; Style : Docs.Format) is
   begin
      if Item.Single or else Item.Read_Only then
         return;
      end if;
      Finish_Composition (Item);
      if Has_Selection (Item) then
         Docs.Set_Format (Item.Doc.all, Selection_First (Item), Selection_Last (Item), Style,
                          not Format_Active (Item, Style));
         Catch_Up (Item);
         Reveal (Item);
      else
         Start_Pending (Item);
         Item.Pending_Formats (Style) := not Item.Pending_Formats (Style);
         Docs.Seal (Item.Doc.all);
      end if;
   end Toggle_Format;

   Bullet_Mark : constant String := [Standard.Character'Val (16#E2#), Standard.Character'Val (16#80#),
      Standard.Character'Val (16#A2#), ' '];

   type Marker is record
      Lead   : Natural := 0;  --  spaces before it
      Length : Natural := 0;  --  bytes of the mark; 0 if there is none
      Which  : Block := Bullets;
   end record;

   function Marker_Of (Item : Text_Area; Para : Positive) return Marker is
      Stop  : constant Positive := Natural'Min (Docs.Byte_Length (Item.Doc.all, Para), 48) + 1;
      Text  : constant String := Docs.Slice (Item.Doc.all, Para, 1, Stop);
      Lead  : Natural := 0;
   begin
      while Lead < Text'Length and then Text (Text'First + Lead) = ' ' loop
         Lead := Lead + 1;
      end loop;
      declare
         Rest   : constant String := Text (Text'First + Lead .. Text'Last);
         Figures : Natural := 0;
      begin
         if Rest'Length >= Bullet_Mark'Length
           and then Rest (Rest'First .. Rest'First + Bullet_Mark'Length - 1) = Bullet_Mark
         then
            return (Lead, Bullet_Mark'Length, Bullets);
         end if;
         while Figures < Rest'Length and then Rest (Rest'First + Figures) in '0' .. '9' loop
            Figures := Figures + 1;
         end loop;
         if Figures > 0 and then Rest'Length >= Figures + 2
           and then Rest (Rest'First + Figures .. Rest'First + Figures + 1) = ". "
         then
            return (Lead, Figures + 2, Numbers);
         end if;
         return (Lead, 0, Bullets);
      end;
   end Marker_Of;

   --  Where the text of list item Para starts, after its lead and mark.
   function Mark_End (Item : Text_Area; Para : Positive) return Position is
      Found : constant Marker := Marker_Of (Item, Para);
   begin
      return (Para, Found.Lead + Found.Length + 1);
   end Mark_End;

   procedure Paragraph_Range (Item : Text_Area; First, Last : out Positive) is
      From : constant Position := Selection_First (Item);
      To   : constant Position := Selection_Last (Item);
   begin
      First := From.Paragraph;
      Last := (if To.Paragraph > From.Paragraph and then To.Index = 1 then To.Paragraph - 1 else To.Paragraph);
   end Paragraph_Range;

   function Size_Here (Item : Text_Area) return Natural is
     (if Item.Explicit_Formats and then not Has_Selection (Item) then Item.Pending_Size
      else Docs.Size_At (Item.Doc.all, Selection_First (Item), Selection_Last (Item)));

   function Family_Here (Item : Text_Area) return String is
     (if Item.Explicit_Formats and then not Has_Selection (Item)
      then Ada.Strings.Unbounded.To_String (Item.Pending_Family)
      else Docs.Family_At (Item.Doc.all, Selection_First (Item), Selection_Last (Item)));

   procedure Start_Pending (Item : in out Text_Area) is
   begin
      if not Item.Explicit_Formats then
         Item.Pending_Size := Size_Here (Item);
         Item.Pending_Family := Ada.Strings.Unbounded.To_Unbounded_String (Family_Here (Item));
         for F in Docs.Format loop
            Item.Pending_Formats (F) := Format_Active (Item, F);
         end loop;
         Item.Explicit_Formats := True;
      end if;
   end Start_Pending;

   procedure Set_Size (Item : in out Text_Area; Points : Natural) is
   begin
      if Item.Single or else Item.Read_Only then
         return;
      end if;
      Finish_Composition (Item);
      if Has_Selection (Item) then
         Docs.Set_Size (Item.Doc.all, Selection_First (Item), Selection_Last (Item), Points);
         Catch_Up (Item);
         Reveal (Item);
      else
         Start_Pending (Item);
         Item.Pending_Size := Points;
         Item.Pending_Formats (Docs.Sized) := Points > 0;
         Docs.Seal (Item.Doc.all);
      end if;
   end Set_Size;

   procedure Set_Family (Item : in out Text_Area; Name : String) is
   begin
      if Item.Single or else Item.Read_Only then
         return;
      end if;
      Finish_Composition (Item);
      if Has_Selection (Item) then
         Docs.Set_Family (Item.Doc.all, Selection_First (Item), Selection_Last (Item), Name);
         Catch_Up (Item);
         Reveal (Item);
      else
         Start_Pending (Item);
         Item.Pending_Family := Ada.Strings.Unbounded.To_Unbounded_String (Name);
         Item.Pending_Formats (Docs.Faced) := Name /= "";
         Docs.Seal (Item.Doc.all);
      end if;
   end Set_Family;

   function Block_Active (Item : Text_Area; Which : Block) return Boolean is
      Found : constant Marker := Marker_Of (Item, Caret (Item).Paragraph);
   begin
      if Which = Quote then
         return Docs.Inset (Item.Doc.all, Caret (Item).Paragraph).Quoted;
      end if;
      return Found.Length > 0 and then Found.Which = Which;
   end Block_Active;

   function Paragraph_Style (Item : Text_Area) return Texts.Paragraph_Kind is
     (Docs.Kind (Item.Doc.all, Caret (Item).Paragraph));

   --  Numbers the run of numbered paragraphs (alike in their lead) that Para is in, from 1.
   procedure Renumber_Run (Item : in out Text_Area; Para : Positive) is
      First : Positive := Para;
      Last  : Positive := Para;
      Lead  : Natural;

      function Joins (Other : Positive) return Boolean is
        (Marker_Of (Item, Other).Which = Numbers and then Marker_Of (Item, Other).Length > 0
         and then Marker_Of (Item, Other).Lead = Lead);
   begin
      if Marker_Of (Item, Para).Length = 0 or else Marker_Of (Item, Para).Which /= Numbers then
         return;
      end if;
      Lead := Marker_Of (Item, Para).Lead;
      while First > 1 and then Joins (First - 1) loop
         First := First - 1;
      end loop;
      while Last < Docs.Count (Item.Doc.all) and then Joins (Last + 1) loop
         Last := Last + 1;
      end loop;
      for Each in First .. Last loop
         declare
            Found : constant Marker := Marker_Of (Item, Each);
            Wanted : constant String :=
              Ada.Strings.Fixed.Trim (Natural'Image (Each - First + 1), Ada.Strings.Left) & ". ";
            Old   : constant String := Docs.Slice (Item.Doc.all, Each, Found.Lead + 1, Found.Lead + Found.Length + 1);
         begin
            if Old /= Wanted then
               Replace_Range (Item, (Each, Found.Lead + 1), (Each, Found.Lead + Found.Length + 1), Wanted);
            end if;
         end;
      end loop;
   end Renumber_Run;

   --  Numbers again the runs that touch paragraphs First .. Last (clipped to the document) and keeps
   --  the selection where it was in its paragraphs, whatever the new marks take.
   procedure Renumber_Around (Item : in out Text_Area; First, Last : Integer) is
      From : constant Position := Selection_First (Item);
      To   : constant Position := Selection_Last (Item);
      From_Tail : constant Natural := Docs.Byte_Length (Item.Doc.all, From.Paragraph) + 1 - From.Index;
      To_Tail   : constant Natural := Docs.Byte_Length (Item.Doc.all, To.Paragraph) + 1 - To.Index;
   begin
      for Para in Integer'Max (1, First) .. Integer'Min (Docs.Count (Item.Doc.all), Last) loop
         Renumber_Run (Item, Para);
      end loop;
      Select_Range
        (Item, (From.Paragraph, Docs.Byte_Length (Item.Doc.all, From.Paragraph) + 1 - From_Tail),
         (To.Paragraph, Docs.Byte_Length (Item.Doc.all, To.Paragraph) + 1 - To_Tail));
   end Renumber_Around;

   procedure Toggle_Block (Item : in out Text_Area; Which : Block) is
      First, Last : Positive;
      Every  : Boolean := True;
      Number : Natural := 0;
   begin
      if Item.Single or else Item.Read_Only then
         return;
      end if;
      Finish_Composition (Item);
      Paragraph_Range (Item, First, Last);
      if Which = Quote then
         Every := (for all Para in First .. Last => Docs.Inset (Item.Doc.all, Para).Quoted);
         Docs.Seal (Item.Doc.all);
         Docs.Begin_Step (Item.Doc.all);
         for Para in First .. Last loop
            Docs.Set_Inset (Item.Doc.all, Para, (Docs.Inset (Item.Doc.all, Para) with delta Quoted => not Every));
         end loop;
         Docs.End_Step (Item.Doc.all);
         Docs.Seal (Item.Doc.all);
         Catch_Up (Item);
         Reveal (Item);
         return;
      end if;
      for Para in First .. Last loop
         declare
            Found : constant Marker := Marker_Of (Item, Para);
         begin
            Every := Every and then Found.Length > 0 and then Found.Which = Which;
         end;
      end loop;
      Docs.Seal (Item.Doc.all);
      Docs.Begin_Step (Item.Doc.all);
      for Para in First .. Last loop
         declare
            Found : constant Marker := Marker_Of (Item, Para);
         begin
            Number := Number + 1;
            Docs.Replace
              (Item.Doc.all, (Para, Found.Lead + 1), (Para, Found.Lead + 1 + Found.Length),
               (if Every then ""
                else (case Which is
                         when Bullets => Bullet_Mark,
                         when Quote   => raise Program_Error,
                         when Numbers => Ada.Strings.Fixed.Trim (Natural'Image (Number), Ada.Strings.Left) & ". ")));
         end;
      end loop;
      Docs.End_Step (Item.Doc.all);
      Docs.Seal (Item.Doc.all);
      Renumber_Around (Item, First - 1, Last + 1);
      Catch_Up (Item);
      Reveal (Item);
   end Toggle_Block;

   --  Return in a list item starts the next one, or ends the list on an empty item; Continue is False
   --  (Shift+Return) for a new plain paragraph after the item.
   procedure Split_Line (Item : in out Text_Area; Continue : Boolean) is
      Para  : constant Positive := Caret (Item).Paragraph;
      Found : constant Marker := Marker_Of (Item, Para);
      Empty : constant Boolean :=
        Found.Length > 0 and then Docs.Byte_Length (Item.Doc.all, Para) = Found.Lead + Found.Length;
   begin
      if Found.Length = 0 or else Has_Selection (Item) then
         Insert (Item, [ASCII.LF]);
      elsif Empty then
         Finish_Composition (Item);
         Replace_Range (Item, (Para, 1), (Para, Found.Lead + Found.Length + 1), "");
         if not Continue then
            Insert (Item, [ASCII.LF]);
         end if;
      elsif not Continue then
         Insert (Item, [ASCII.LF]);
      else
         declare
            Lead : constant String := [1 .. Found.Lead => ' '];
            Prefix : constant String :=
              Docs.Slice (Item.Doc.all, Para, Found.Lead + 1, Found.Lead + Found.Length + 1);
            Next : constant String :=
              (if Found.Which = Bullets then Bullet_Mark
               else Ada.Strings.Fixed.Trim
                      (Natural'Image (Natural'Value (Prefix (Prefix'First .. Prefix'Last - 2)) + 1), Ada.Strings.Left)
                    & ". ");
         begin
            Insert (Item, ASCII.LF & Lead & Next);
         end;
      end if;
   end Split_Line;

   procedure Break_Line (Item : in out Text_Area; Continue : Boolean) is
   begin
      Split_Line (Item, Continue);
      Renumber_Around (Item, Caret (Item).Paragraph - 1, Caret (Item).Paragraph + 1);
   end Break_Line;

   procedure Shift_Indent (Item : in out Text_Area; Outward : Boolean) is
      First, Last : Positive;
   begin
      if Item.Single or else Item.Read_Only then
         return;
      end if;
      Finish_Composition (Item);
      Paragraph_Range (Item, First, Last);
      Docs.Seal (Item.Doc.all);
      Docs.Begin_Step (Item.Doc.all);
      for Para in First .. Last loop
         declare
            Was : constant Texts.Paragraph_Inset := Docs.Inset (Item.Doc.all, Para);
         begin
            if not Outward then
               Docs.Set_Inset (Item.Doc.all, Para, (Was with delta Indent => Was.Indent + 1));
            elsif Was.Indent > 0 then
               Docs.Set_Inset (Item.Doc.all, Para, (Was with delta Indent => Was.Indent - 1));
            end if;
         end;
      end loop;
      Docs.End_Step (Item.Doc.all);
      Docs.Seal (Item.Doc.all);
      Catch_Up (Item);
      Reveal (Item);
   end Shift_Indent;

   procedure Set_Style (Item : in out Text_Area; To : Texts.Paragraph_Kind) is
      First, Last : Positive;
   begin
      if Item.Single or else Item.Read_Only then
         return;
      end if;
      Finish_Composition (Item);
      Paragraph_Range (Item, First, Last);
      Docs.Seal (Item.Doc.all);
      Docs.Begin_Step (Item.Doc.all);
      for Para in First .. Last loop
         if Docs.Kind (Item.Doc.all, Para) /= To then
            Docs.Set_Kind (Item.Doc.all, Para, To);
         end if;
      end loop;
      Docs.End_Step (Item.Doc.all);
      Docs.Seal (Item.Doc.all);
      Catch_Up (Item);
      Reveal (Item);
   end Set_Style;

   --  Text typed or pasted into the lead or mark of a list item goes after the mark: the mark stays first.
   procedure Clear_Of_Mark (Item : in out Text_Area; Typed : String) is
      Where : constant Position := Item.At_Caret;
   begin
      if Has_Selection (Item) or else (Typed'Length > 0 and then Typed (Typed'First) = ASCII.LF)
        or else Marker_Of (Item, Where.Paragraph).Length = 0
        or else Where.Index > Mark_End (Item, Where.Paragraph).Index
      then
         return;
      end if;
      Select_Range (Item, Mark_End (Item, Where.Paragraph), Mark_End (Item, Where.Paragraph));
   end Clear_Of_Mark;

   procedure Insert (Item : in out Text_Area; Typed : String) is
   begin
      Drop_Composition (Item);  --  Typed is what it became
      Clear_Of_Mark (Item, Typed);
      Edit (Item, Selection_First (Item), Selection_Last (Item),
            Fitted (Item, Typed), Docs.Typing);
   end Insert;

   procedure Replace_Range (Item : in out Text_Area; From, To : Position; By : String) is
   begin
      Catch_Up (Item);
      Docs.Seal (Item.Doc.all);
      Edit (Item, From, To, By, Docs.Other);
      Docs.Seal (Item.Doc.all);
   end Replace_Range;

   procedure Add_Version (Item : in out Text_Area; From, To : Position; Words : String) is
   begin
      Finish_Composition (Item);
      Catch_Up (Item);
      Docs.Seal (Item.Doc.all);
      Docs.Add_Version (Item.Doc.all, From, To, Words);
      Docs.Seal (Item.Doc.all);
      Catch_Up (Item);
      Item.At_Caret := Docs.Run (Item.Doc.all, Docs.Version_At (Item.Doc.all, From)).To;
      Item.At_Mark := Item.At_Caret;
      Item.Has_Goal := False;
      Moved (Item);
   end Add_Version;

   procedure Choose_Version (Item : in out Text_Area; Index : Positive; Choice : Positive) is
      Where : constant Position := Docs.Run (Item.Doc.all, Index).From;
   begin
      Finish_Composition (Item);
      Catch_Up (Item);
      Docs.Seal (Item.Doc.all);
      Docs.Choose_Version (Item.Doc.all, Index, Choice);
      Docs.Seal (Item.Doc.all);
      Catch_Up (Item);
      Item.At_Caret := Docs.Run (Item.Doc.all, Docs.Version_At (Item.Doc.all, Where)).To;
      Item.At_Mark := Item.At_Caret;
      Item.Has_Goal := False;
      Moved (Item);
   end Choose_Version;

   function Deletion_Motion (By : Deletion; Forward : Boolean) return Motion
   is (case By is
          when Character =>
             (if Forward then Next_Character else Previous_Character),
          when Word => (if Forward then Next_Word else Previous_Word),
          when Line_Part => (if Forward then Line_End else Line_Start));

   --  Numbers again the runs around the caret after text was removed.
   procedure Renumber_Caret (Item : in out Text_Area) is
      Para : constant Positive := Caret (Item).Paragraph;
   begin
      --  Plain text is left alone so that runs of deleting still undo together.
      if (for some Near in Integer'Max (1, Para - 1) .. Integer'Min (Docs.Count (Item.Doc.all), Para + 1) =>
            Marker_Of (Item, Near).Length > 0)
      then
         Renumber_Around (Item, Para - 1, Para + 1);
      end if;
   end Renumber_Caret;

   procedure Delete_Backward
     (Item : in out Text_Area; By : Deletion := Character) is
   begin
      Finish_Composition (Item);
      if Has_Selection (Item) then
         Edit (Item, Selection_First (Item), Selection_Last (Item), "",
               Docs.Other);
         Renumber_Caret (Item);
         return;
      end if;
      declare
         At_Para : constant Positive := Item.At_Caret.Paragraph;
         Found   : constant Marker := Marker_Of (Item, At_Para);
         From    : Position := Step (Item, Item.At_Caret, Deletion_Motion (By, False));
      begin
         if Found.Length > 0 and then Item.At_Caret = Mark_End (Item, At_Para) then
            --  Just after the mark: the mark goes, not a piece of it.
            Replace_Range (Item, (At_Para, 1), Item.At_Caret, "");
         elsif Found.Length > 0 and then Item.At_Caret.Index = 1 and then At_Para > 1
           and then Docs.Byte_Length (Item.Doc.all, At_Para - 1) > 0
         then
            --  Joining onto text above: the item gives up its mark.
            Replace_Range (Item, (At_Para - 1, Docs.Byte_Length (Item.Doc.all, At_Para - 1) + 1),
                           Mark_End (Item, At_Para), "");
         else
            --  At the start of a line, its part is the break before it.
            if From = Item.At_Caret then
               From := Step (Item, Item.At_Caret, Previous_Character);
            end if;
            Edit (Item, From, Item.At_Caret, "", Docs.Deleting_Back);
         end if;
         Renumber_Caret (Item);
      end;
   end Delete_Backward;

   procedure Delete_Forward
     (Item : in out Text_Area; By : Deletion := Character) is
   begin
      Finish_Composition (Item);
      if Has_Selection (Item) then
         Edit (Item, Selection_First (Item), Selection_Last (Item), "",
               Docs.Other);
         Renumber_Caret (Item);
         return;
      end if;
      declare
         Para : constant Positive := Item.At_Caret.Paragraph;
         To   : Position := Step (Item, Item.At_Caret, Deletion_Motion (By, True));
      begin
         if Para < Docs.Count (Item.Doc.all) and then Marker_Of (Item, Para + 1).Length > 0
           and then Item.At_Caret.Index = Docs.Byte_Length (Item.Doc.all, Para) + 1
           and then Item.At_Caret.Index > 1
         then
            --  Pulling a list item up onto this text: it gives up its mark.
            Replace_Range (Item, Item.At_Caret, Mark_End (Item, Para + 1), "");
         else
            if To = Item.At_Caret then
               To := Step (Item, Item.At_Caret, Next_Character);
            end if;
            Edit (Item, Item.At_Caret, To, "", Docs.Deleting_Forward);
         end if;
         Renumber_Caret (Item);
      end;
   end Delete_Forward;

   procedure Copy
     (Item  : in out Text_Area;
      Board : in out Clipboards.Clipboard'Class) is
   begin
      Finish_Composition (Item);
      if Has_Selection (Item) then
         Board.Set_Text (Selected_Text (Item));
      end if;
   end Copy;

   procedure Cut
     (Item  : in out Text_Area;
      Board : in out Clipboards.Clipboard'Class) is
   begin
      Copy (Item, Board);
      if Has_Selection (Item) then
         Edit (Item, Selection_First (Item), Selection_Last (Item), "",
               Docs.Other);
         Renumber_Caret (Item);
      end if;
   end Cut;

   procedure Paste
     (Item  : in out Text_Area;
      Board : in out Clipboards.Clipboard'Class) is
   begin
      Finish_Composition (Item);
      Clear_Of_Mark (Item, Board.Text);
      Edit (Item, Selection_First (Item), Selection_Last (Item),
            Fitted (Item, Board.Text), Docs.Other);
   end Paste;

   --  Undoing

   procedure Undo (Item : in out Text_Area) is
      From, To : Position;
   begin
      Finish_Composition (Item);
      if not Item.Read_Only and then Docs.Can_Undo (Item.Doc.all)
        and then not Docs.In_Step (Item.Doc.all)
      then
         Docs.Undo (Item.Doc.all, From, To);
         Catch_Up (Item);
         Item.At_Mark := From;
         Item.At_Caret := To;
         Item.Has_Goal := False;
         Moved (Item);
      end if;
   end Undo;

   procedure Redo (Item : in out Text_Area) is
      From, To : Position;
   begin
      Finish_Composition (Item);
      if not Item.Read_Only and then Docs.Can_Redo (Item.Doc.all)
        and then not Docs.In_Step (Item.Doc.all)
      then
         Docs.Redo (Item.Doc.all, From, To);
         Catch_Up (Item);
         Item.At_Mark := To;
         Item.At_Caret := To;
         Item.Has_Goal := False;
         Moved (Item);
      end if;
   end Redo;

   --  Blinking

   procedure Tick
     (Item    : in out Text_Area;
      Now     : SDL3.Events.Milliseconds;
      Changed : out Boolean)
   is
      On : Boolean;
   begin
      Item.Now := SDL3.Events.Milliseconds'Max (Item.Now, Now);
      On := (Item.Now - Item.Since) / Blink_Period mod 2 = 0;
      Changed := Item.Caret_Visible and then Item.Focused and then On /= Item.Caret_On;
      Item.Caret_On := On;
   end Tick;

   procedure Set_Keyboard_Navigation (Item : in out Text_Area; To : Boolean := True) is
   begin
      Item.Keyboard_Navigation := To;
   end Set_Keyboard_Navigation;

   procedure Set_Caret_Visible (Item : in out Text_Area; To : Boolean := True) is
   begin
      Item.Caret_Visible := To;
   end Set_Caret_Visible;

   function Is_Caret_Shown (Item : Text_Area) return Boolean is
     (Item.Caret_Visible and then Item.Focused and then Item.Caret_On);

   function Until_Blink (Item : Text_Area) return SDL3.Events.Milliseconds
   is (Blink_Period - (Item.Now - Item.Since) mod Blink_Period);

   --  Events

   procedure Handle_Key
     (Item    : in out Text_Area;
      Event   : Events.Event;
      Board   : in out Clipboards.Clipboard'Class;
      Handled : out Boolean);

   procedure Handle_Key
     (Item    : in out Text_Area;
      Event   : Events.Event;
      Board   : in out Clipboards.Clipboard'Class;
      Handled : out Boolean)
   is
      Key     : constant Events.Key_Code := Event.Key;
      Command : constant Boolean := Event.Command;
      Option  : constant Boolean := Event.Option;
      Shift   : constant Boolean := Event.Shift;
      Control_Motion : constant Boolean :=
        Event.Control and then not Command and then not Option
        and then Key in Events.Key_A | Events.Key_E | Events.Key_B
                      | Events.Key_F | Events.Key_P | Events.Key_N;
      High    : constant Float := Layouts.Line_Height (Item.Laid);

      function Deleting return Deletion is
        (if Command then Line_Part elsif Option then Word else Character);
   begin
      Handled := True;
      if not Item.Keyboard_Navigation
        and then (Control_Motion or else Key in Events.Key_Left_Arrow | Events.Key_Right_Arrow
                      | Events.Key_Up_Arrow | Events.Key_Down_Arrow
                      | Events.Key_Home | Events.Key_End | Events.Key_Page_Up | Events.Key_Page_Down)
      then
         return;
      end if;
      if not Item.Focused then
         null;
      elsif Control_Motion then
         Move (Item,
               (case Key is
                   when Events.Key_A => Line_Start,
                   when Events.Key_E => Line_End,
                   when Events.Key_B => Previous_Character,
                   when Events.Key_F => Next_Character,
                   when Events.Key_P => Previous_Line,
                   when Events.Key_N => Next_Line,
                   when others => raise Program_Error),
               Extend => Shift);
         if Key = Events.Key_A and then Marker_Of (Item, Item.At_Caret.Paragraph).Length > 0
           and then Item.At_Caret < Mark_End (Item, Item.At_Caret.Paragraph)
         then
            Item.At_Caret := Mark_End (Item, Item.At_Caret.Paragraph);
            if not Shift then
               Item.At_Mark := Item.At_Caret;
            end if;
            Moved (Item);
         end if;
         return;
      elsif Command and then not Item.Single and then not Item.Read_Only
        and then (Key = Events.Key_B or else Key = Events.Key_I or else Key = Events.Key_U
                  or else (Shift and then Key = Events.Key_S))
      then
         Toggle_Format (Item, (if Key = Events.Key_B then Docs.Bold elsif Key = Events.Key_I then Docs.Italic
                              elsif Key = Events.Key_U then Docs.Underline else Docs.Strikethrough));
         return;
      elsif Command and then Key = Events.Key_A then
         Select_All (Item);
         return;
      elsif Command and then Key = Events.Key_C then
         Copy (Item, Board);
         return;
      elsif Command and then Key = Events.Key_X then
         Cut (Item, Board);
         return;
      elsif Command and then Key = Events.Key_V then
         Paste (Item, Board);
         return;
      elsif Command and then Key = Events.Key_Z then
         if Shift then
            Redo (Item);
         else
            Undo (Item);
         end if;
         return;
      elsif Key = Events.Key_Left_Arrow then
         Move (Item,
               (if Command then Line_Start
                elsif Option then Previous_Word
                else Previous_Character),
               Extend => Shift);
         return;
      elsif Key = Events.Key_Right_Arrow then
         Move (Item,
               (if Command then Line_End
                elsif Option then Next_Word
                else Next_Character),
               Extend => Shift);
         return;
      elsif Key = Events.Key_Up_Arrow then
         Move (Item,
               (if Command then Text_Start
                elsif Option then Paragraph_Start
                else Previous_Line),
               Extend => Shift);
         return;
      elsif Key = Events.Key_Down_Arrow then
         Move (Item,
               (if Command then Text_End
                elsif Option then Paragraph_End
                else Next_Line),
               Extend => Shift);
         return;
      elsif Key = Events.Key_Backspace then
         Delete_Backward (Item, Deleting);
         return;
      elsif Key = Events.Key_Delete then
         Delete_Forward (Item, Deleting);
         return;
      elsif Key = Events.Key_Return then
         if Item.Single then
            Item.Returned := True;
         else
            Break_Line (Item, Continue => not Shift);
         end if;
         return;
      elsif Key = Events.Key_Escape then
         Set_Focus (Item, False);
         return;
      end if;

      --  Scrolling, focused or not
      if Key = Events.Key_Down_Arrow then
         Scroll (Item, High);
      elsif Key = Events.Key_Up_Arrow then
         Scroll (Item, -High);
      elsif Key = Events.Key_Page_Down then
         Scroll (Item, Page_Fraction * Extent (Item));
      elsif Key = Events.Key_Page_Up then
         Scroll (Item, -Page_Fraction * Extent (Item));
      elsif Key = Events.Key_Home then
         Scroll (Item, -Layouts.Total_Height (Item.Laid));
      elsif Key = Events.Key_End then
         Scroll (Item, Layouts.Total_Height (Item.Laid));
      else
         Handled := False;
      end if;
   end Handle_Key;

   function Bar_Metrics (Item : Text_Area) return Scrollbars.Metrics is
      Edge : constant Float :=
        (if Item.Focused then Focus_Outline else Outline) * Item.Density;
   begin
      return
        (Left    => Float (Integer (Item.Left + Edge)),
         Top     => Float (Integer (Item.Top + Edge + Toolbar_Room (Item))),
         Width   => Float'Max
                      (0.0, Float (Integer (Item.Left + Item.Width - Edge))
                            - Float (Integer (Item.Left + Edge))),
         Height  => Float'Max
                      (0.0, Float (Integer (Item.Top + Item.Height - Edge))
                            - Float (Integer (Item.Top + Edge + Toolbar_Room (Item)))),
         Density => Item.Density,
         Start   => View_Top (Item),
         Shown   => Extent (Item),
         Total   => Layouts.Total_Height (Item.Laid),
         Horizontal => False);
   end Bar_Metrics;

   procedure Set_Faint (Item : in out Text_Area; From, To : Position) is
   begin
      Item.Faint_On := From < To;
      Item.Faint_From := From;
      Item.Faint_To := To;
      Item.Faint_Version := Docs.Current (Item.Doc.all);
   end Set_Faint;

   procedure Clear_Faint (Item : in out Text_Area) is
   begin
      Item.Faint_On := False;
   end Clear_Faint;

   procedure Clear_Highlights (Item : in out Text_Area) is
   begin
      Item.Highlight_Total := 0;
   end Clear_Highlights;

   function Highlight_Count (Item : Text_Area) return Natural is
     (if Item.Doc /= null and then Item.Highlight_Serial = Docs.Serial (Item.Doc.all)
        and then Item.Highlight_Version = Docs.Current (Item.Doc.all)
      then Item.Highlight_Total else 0);

   procedure Add_Highlight
     (Item : in out Text_Area; From, To : Position; Fill, Ink : Themes.Color) is
   begin
      Item.Highlight_Total := Highlight_Count (Item) + 1;
      Item.Highlights (Item.Highlight_Total) := (From, To, Fill, Ink);
      Item.Highlight_Version := Docs.Current (Item.Doc.all);
      Item.Highlight_Serial := Docs.Serial (Item.Doc.all);
   end Add_Highlight;

   procedure Set_Hovered (Item : in out Text_Area; Hovered : Boolean) is
   begin
      Scrollbars.Set_Pane (Item.Bar, Hovered);
   end Set_Hovered;

   procedure Take_Bar_Change
     (Item : in out Text_Area; Changed : out Boolean) is
   begin
      Changed := Item.Bar_Dirty;
      Item.Bar_Dirty := False;
   end Take_Bar_Change;

   procedure Handle
     (Item    : in out Text_Area;
      Event   : Events.Event;
      Board   : in out Clipboards.Clipboard'Class;
      Handled : out Boolean)
   is
      X : constant Float := Event.Mouse_X * Item.Density;
      Y : constant Float := Event.Mouse_Y * Item.Density;
   begin
      Catch_Up (Item);
      Item.Now := SDL3.Events.Milliseconds'Max (Item.Now, Event.Time);
      Handled := False;
      if not Item.Single and then not Item.Grows
        and then Event.Kind in Events.Mouse_Down | Events.Mouse_Move
                             | Events.Mouse_Up
      then
         declare
            Dragged, Changed : Boolean;
            To : Float;
            Before : constant Boolean := Scrollbars.Is_Shown (Item.Bar);
         begin
            if Event.Kind = Events.Mouse_Move then
               Scrollbars.Set_Pane (Item.Bar, Contains (Item, X, Y));
            end if;
            Scrollbars.Handle
              (Item.Bar, Event, Bar_Metrics (Item), Handled, Dragged, To,
               Changed);
            if Dragged then
               Scroll (Item, To - View_Top (Item));
            end if;
            if Changed or else Dragged
              or else Before /= Scrollbars.Is_Shown (Item.Bar)
            then
               Item.Bar_Dirty := True;
            end if;
            if Handled then
               return;
            end if;
         end;
      end if;
      case Event.Kind is
         when Events.Mouse_Down =>
            if Event.Button = 1 and then Contains (Item, X, Y) then
               if Y < Item.Top + Toolbar_Room (Item) then
                  null;  --  the toolbar's, whose buttons take their own clicks
               else
                  Item.Explicit_Formats := False;
                  Click (Item, X, Y, Natural'Max (1, Event.Clicks), Extend => Event.Shift);
               end if;
               Handled := True;
            end if;
         when Events.Mouse_Move =>
            if Item.Dragging and then Event.Left_Held then
               Drag (Item, X, Y);
               Handled := True;
            elsif Item.Dragging then
               Release (Item);  --  let go where it was not seen
            end if;
         when Events.Mouse_Up =>
            if Event.Button = 1 then
               Release (Item);
            end if;
         when Events.Mouse_Wheel =>
            if not Item.Grows and then not Event.Command
              and then Contains (Item, X, Y)
            then
               declare
                  Before : constant Float := View_Top (Item);
               begin
                  Scroll
                    (Item,
                     -Event.Wheel_Y * Lines_Per_Notch
                      * Layouts.Line_Height (Item.Laid));
                  --  At either end it still holds the wheel, if there is a bar
                  --  to scroll, so the canvas under it does not pan instead.
                  Handled := View_Top (Item) /= Before
                    or else Layouts.Total_Height (Item.Laid) > Extent (Item);
               end;
            end if;
         when Events.Text_Input =>
            if Item.Focused then
               Insert (Item, Events.Typed (Event));
               Handled := True;
            end if;
         when Events.Text_Editing =>
            if Item.Focused then
               Compose (Item, Events.Typed (Event), Event.Cursor);
               Handled := True;
            end if;
         when Events.Key_Down =>
            if not Item.Composing then
               Handle_Key (Item, Event, Board, Handled);
            end if;
         when Events.Quit | Events.Pinch | Events.Redraw
            | Events.Theme_Changed | Events.Other =>
            null;
      end case;
   end Handle;

   --  Drawing

   Faint_Alpha : constant SDL3.Windows.Renderers.Color_Component := 150;
   --  How much of the page's colour covers text that is not settled.
   Faded_Alpha : constant SDL3.Windows.Renderers.Color_Component := 128;
   --  How much of it covers text chosen to be faded.

   procedure Draw_Range
     (Item        : in out Text_Area;
      Target      : SDL3.Painters.Painter'Class;
      From, To    : Position;
      First, Last : Positive;
      Value       : SDL3.Windows.Renderers.Color;
      Underlined  : Boolean;
      Rows_From, Rows_To : Float;
      Marking : Boolean := False; Strike : Boolean := False);
   --  Mark the text from From to To, in paragraphs First to Last, which
   --  are laid out: fill behind it, or underline it. Lines wholly outside
   --  the rows of the target Rows_From to Rows_To are left.

   procedure Draw_Range
     (Item        : in out Text_Area;
      Target      : SDL3.Painters.Painter'Class;
      From, To    : Position;
      First, Last : Positive;
      Value       : SDL3.Windows.Renderers.Color;
      Underlined  : Boolean;
      Rows_From, Rows_To : Float;
      Marking : Boolean := False; Strike : Boolean := False)
   is
      Shown : constant Float := View_Top (Item);
      Right : constant Float := Column (Item);
   begin
      for Para in Positive'Max (First, From.Paragraph)
                  .. Positive'Min (Last, To.Paragraph)
      loop
         declare
            High : constant Float := Layouts.Line_Height (Item.Laid, Para);
            Range_First : constant Natural :=
              (if Para = From.Paragraph then Units (Item, From) else 0);
            Range_Stop  : constant Natural :=
              (if Para = To.Paragraph then Units (Item, To)
               else Natural'Last);  --  on past the paragraph's end
            Para_Top    : constant Float := Layouts.Top (Item.Laid, Para);
            Lines       : constant Positive :=
              Layouts.Line_Count (Item.Laid, Para);
         begin
            for Number in 1 .. Lines loop
               declare
                  Line : constant CoreText.Wrapping.Span :=
                    Layouts.Line (Item.Laid, Para, Number);
                  A    : constant Natural :=
                    Natural'Max (Range_First, Line.First);
                  B    : constant Natural :=
                    Natural'Min (Range_Stop, Line.Stop);
                  Runs_On : constant Boolean := Range_Stop > Line.Stop;
                  --  On past the line's end: to the column's.
                  Y    : constant Float :=
                    Text_Top (Item)
                    + (Para_Top + Float (Number - 1) * High - Shown)
                      * Scale (Item);
                  --  Where the line ends, or the space after the
                  --  paragraph that a mark running on fills; a little
                  --  more, for an underline.
                  Line_Bottom : constant Float :=
                    (if Number = Lines
                       and then Layouts.Is_Complete (Item.Laid, Para)
                     then Text_Top (Item)
                          + (Para_Top + Layouts.Height (Item.Laid, Para)
                             - Shown) * Scale (Item)
                     else Y + High * Scale (Item))
                    + Underline_Gap * Item.Density;
               begin
                  if Line_Bottom >= Rows_From and then Y <= Rows_To
                    and then A <= Line.Stop
                    and then (if Underlined then A < B
                              else A < B or else Runs_On)
                  then
                     declare
                        X_A : constant Float := Layouts.Caret_Offset
                          (Item.Laid, Item.Doc.all, Para, Number, A);
                        X_B : constant Float :=
                          (if Runs_On and then not Underlined and then not Marking
                           then Float'Max (Right, X_A)
                           else Layouts.Caret_Offset
                                  (Item.Laid, Item.Doc.all, Para, Number,
                                   B));
                        Left : constant Float :=
                          Column_Left (Item) + X_A * Scale (Item);
                        Wide : constant Float := (X_B - X_A) * Scale (Item);
                     begin
                        if Underlined then
                           declare
                              Top : constant Float := Float'Rounding
                                (if Strike then Y + Layouts.Ascent (Item.Laid, Para) * 0.6 * Scale (Item)
                                 elsif Marking then Y + High * Scale (Item) - 2.0 * Item.Density
                                 else Y + Layouts.Ascent (Item.Laid, Para) * Scale (Item)
                                      + Underline_Gap * Item.Density);
                              Stroke_Width : constant Float := Float'Max
                                (1.0, Float'Rounding
                                   ((if Marking then 2.0 else Underline) * Item.Density));
                           begin
                              SDL3.Painters.Fill_Rect
                                (Target, Value, Left, Top, Wide, Stroke_Width);
                           end;
                        else
                           declare
                              --  Down over the space after the paragraph
                              --  too, if it runs on to the next.
                              Bottom : constant Float :=
                                (if Runs_On and then not Marking and then Number = Lines
                                   and then Layouts.Is_Complete
                                              (Item.Laid, Para)
                                 then Text_Top (Item)
                                      + (Para_Top
                                         + Layouts.Height (Item.Laid, Para)
                                         - Shown) * Scale (Item)
                                 else Y + High * Scale (Item));
                              Row    : constant Float := Float'Floor (Y);
                           begin
                              --  On whole pixels: rows meet, not overlap
                              --  or leave a gap.
                              SDL3.Painters.Fill_Rect
                                (Target, Value, Left, Row, Wide,
                                 Float'Floor (Bottom) - Row);
                           end;
                        end if;
                     end;
                  end if;
               end;
            end loop;
         end;
      end loop;
   end Draw_Range;

   procedure Caret_Box
     (Item : in out Text_Area;
      X, Y, Width, Height : out Float) is
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
         Item.Caret_Across := Layouts.Caret_Offset
           (Item.Laid, Item.Doc.all, Item.At_Caret.Paragraph,
            Item.Caret_Line, Units (Item, Item.At_Caret));
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
         Line_Top : constant Float :=
           Layouts.Top (Item.Laid, Para) + Float (Number - 1) * High;
         Across   : constant Float := Item.Caret_Across;
      begin
         Width := Caret_Width * Item.Density;
         X := Column_Left (Item) + Across * Scale (Item) - Width / 2.0;
         Y := Text_Top (Item) + (Line_Top - View_Top (Item)) * Scale (Item);
         Height := High * Scale (Item);
      end;
   end Caret_Box;

   function Lines_Drawn (Item : Text_Area) return Natural is
     (Views.Lines_Drawn (Item.View));

   function Caret_Measures (Item : Text_Area) return Natural is
     (Item.Caret_Worked);

   procedure Draw
     (Item      : in out Text_Area;
      Target    : SDL3.Painters.Painter'Class;
      Colors    : Themes.Theme;
      Settled   : Boolean := True;
      Rows_From : Float := Float'First;
      Rows_To   : Float := Float'Last)
   is
      use SDL3.Windows.Renderers;
      use all type SDL3.Painters.Painter;
      Edge : constant Float :=
        (if Item.Grows then 0.0
         elsif Item.Focused then Focus_Outline else Outline) * Item.Density;
      --  A page has no outline.
      Inner_Left   : constant Integer := Integer (Item.Left + Edge);
      Inner_Top    : constant Integer := Integer (Item.Top + Edge);
      Inner_Right  : constant Integer :=
        Integer (Item.Left + Item.Width - Edge);
      Inner_Bottom : constant Integer :=
        Integer (Item.Top + Item.Height - Edge);
      Lead         : constant Integer := Integer (Lead_Room (Item));
      Trail        : constant Integer := Integer (Trail_Room (Item));
      First, Last  : Positive;
      Outer_Clip   : constant Clip := Current_Clip (Target);
      --  The owner's, to go back to.
      Round : constant Float :=
        (if Item.Grows or else Colors (Themes.Border) = Colors (Themes.Background) then 0.0
         else Pomarine.Boxes.Corner (Item.Radius, Item.Density));
      Inner_Round : constant Float := Float'Max (0.0, Round - Edge);
      --  Of the corners of the outline, and of what it holds, which is the
      --  less round by the width of the outline. A page, or a field whose
      --  outline is the colour of its ground, has none to round.
   begin
      Catch_Up (Item);
      Pomarine.Boxes.Fill_Round
        (Target, (if Item.Focused then Colors (Themes.Focus) else Colors (Themes.Border)),
         Item.Left, Item.Top, Item.Width, Item.Height, Round);
      Pomarine.Boxes.Fill_Round
        (Target, Colors (Themes.Background),
         Float (Inner_Left), Float (Inner_Top),
         Float (Integer'Max (0, Inner_Right - Inner_Left)),
         Float (Integer'Max (0, Inner_Bottom - Inner_Top)), Inner_Round);
      if Has_Toolbar (Item) then
         --  The toolbar's band, set apart from the text under it by its
         --  tint and a line.
         declare
            Band : constant Float := Float'Min (Toolbar_Room (Item), Float (Inner_Bottom - Inner_Top));
         begin
            Pomarine.Boxes.Fill_Round
              (Target, Colors (Themes.Strip),
               Float (Inner_Left), Float (Inner_Top),
               Float (Integer'Max (0, Inner_Right - Inner_Left)), Band, Inner_Round,
               Pomarine.Boxes.Top_Corners);
            Fill_Rect
              (Target, Colors (Themes.Border),
               Float (Inner_Left), Float (Inner_Top) + Band - Item.Density,
               Float (Integer'Max (0, Inner_Right - Inner_Left)), Item.Density);
         end;
      end if;

      --  Lines part in view run into the padding, but not the outline,
      --  nor what is before a single line, nor the toolbar.
      declare
         Clip_Top : constant Integer := Integer'Max (Inner_Top, Integer (Item.Top + Toolbar_Room (Item)));
      begin
         Narrow_Clip
           (Target, Inner_Left + Lead, Clip_Top,
            Integer'Max (0, Inner_Right - Inner_Left - Lead - Trail),
            Integer'Max (0, Inner_Bottom - Clip_Top));
      end;

      --  What is shown, laid out, as the view will draw it.
      Layouts.Visible
        (Item.Laid, Item.Doc.all, Item.Anchor, Item.Offset, Extent (Item),
         First, Last);

      for Index in 1 .. Highlight_Count (Item) loop
         declare
            Decoration : Highlight renames Item.Highlights (Index);
         begin
            Draw_Range
              (Item, Target, Decoration.From, Decoration.To, First, Last, Decoration.Fill, False,
               Rows_From, Rows_To, Marking => True);
            Draw_Range
              (Item, Target, Decoration.From, Decoration.To, First, Last, Decoration.Ink, True,
               Rows_From, Rows_To, Marking => True);
         end;
      end loop;

      for I in 1 .. Docs.Run_Count (Item.Doc.all) loop
         declare
            R : constant Docs.Format_Run := Docs.Run (Item.Doc.all, I);
            use type Docs.Format;
            Ink : constant Themes.Color := Themes.Mix (Colors (Themes.Foreground), Colors (Themes.Background), 0.55);
         begin
            --  Text with versions, in the grey of neither a kind of grammar's mark.
            if R.Style = Docs.Versioned then
               Draw_Range
                 (Item, Target, R.From, R.To, First, Last, (Ink with delta Alpha => 40), False,
                  Rows_From, Rows_To, Marking => True);
               Draw_Range
                 (Item, Target, R.From, R.To, First, Last, Ink, True,
                  Rows_From, Rows_To, Marking => True);
            end if;
         end;
      end loop;

      if Has_Selection (Item) then
         Draw_Range
           (Item, Target, Selection_First (Item), Selection_Last (Item),
            First, Last,
            (if Item.Focused then Colors (Themes.Selection)
             else Themes.Inactive_Selection (Colors)),
            Underlined => False,
            Rows_From => Rows_From, Rows_To => Rows_To);
      end if;

      --  The rule beside each quoted paragraph, down its height so that quoted paragraphs together have one.
      for Para in First .. Last loop
         if Layouts.Is_Quoted (Item.Laid, Para) then
            declare
               Rule_Top : constant Float := Float'Floor
                 (Text_Top (Item) + (Layouts.Top (Item.Laid, Para) - View_Top (Item)) * Scale (Item));
               Rule_Bottom : constant Float := Float'Floor
                 (Text_Top (Item)
                  + (Layouts.Top (Item.Laid, Para) + Layouts.Height (Item.Laid, Para) - View_Top (Item))
                    * Scale (Item));
            begin
               SDL3.Painters.Fill_Rect
                 (Target, Themes.Mix (Colors (Themes.Foreground), Colors (Themes.Background), 0.6),
                  Float'Rounding (Column_Left (Item) + Layouts.Rule_Offset (Item.Laid, Para) * Scale (Item)),
                  Rule_Top, Float'Max (1.0, Float'Rounding (Layouts.Rule_Width * Item.Density)),
                  Rule_Bottom - Rule_Top);
            end;
         end if;
      end loop;

      Views.Draw
        (Item.View, Item.Laid, Item.Doc.all, Target, Colors (Themes.Foreground),
         Item.Anchor, Item.Offset,
         Left    => Column_Left (Item),
         Top     => Text_Top (Item),
         Width   => Natural (Float'Floor (Text_Width (Item))),
         Height  => Natural (Float'Floor (Text_Height (Item))),
         Scale   => Scale (Item),
         Settled => Settled,
         Rows_From => Rows_From, Rows_To => Rows_To);

      for I in 1 .. Docs.Run_Count (Item.Doc.all) loop
         declare
            R : constant Docs.Format_Run := Docs.Run (Item.Doc.all, I);
            use type Docs.Format;
         begin
            if R.Style = Docs.Underline or else R.Style = Docs.Strikethrough then
               Draw_Range (Item, Target, R.From, R.To, First, Last, Colors (Themes.Foreground), True,
                           Rows_From, Rows_To, Strike => R.Style = Docs.Strikethrough);
            end if;
         end;
      end loop;

      --  Faded runs: laid over with the page's own colour, part see-through.
      for I in 1 .. Docs.Run_Count (Item.Doc.all) loop
         declare
            R : constant Docs.Format_Run := Docs.Run (Item.Doc.all, I);
            use type Docs.Format;
         begin
            if R.Style = Docs.Faded then
               Draw_Range
                 (Item, Target, R.From, R.To, First, Last,
                  (Colors (Themes.Background) with delta Alpha => Faded_Alpha),
                  Underlined => False,
                  Rows_From => Rows_From, Rows_To => Rows_To);
            end if;
         end;
      end loop;

      if Item.Faint_On
        and then Item.Faint_Version = Docs.Current (Item.Doc.all)
      then
         --  Text laid over with the page's own colour, part see-through,
         --  is text part faded.
         Draw_Range
           (Item, Target, Item.Faint_From, Item.Faint_To, First, Last,
            (Colors (Themes.Background) with delta Alpha => Faint_Alpha),
            Underlined => False,
            Rows_From => Rows_From, Rows_To => Rows_To);
      end if;

      if Item.Composing then
         Draw_Range
           (Item, Target, Item.Composed, Composed_End (Item), First, Last,
            Colors (Themes.Foreground), Underlined => True,
            Rows_From => Rows_From, Rows_To => Rows_To);
      end if;

      if Is_Caret_Shown (Item) and then not Has_Selection (Item) then
         declare
            X, Y, Wide, High : Float;
         begin
            Caret_Box (Item, X, Y, Wide, High);
            Fill_Rect (Target, Colors (Themes.Accent), X, Y, Wide, High);
         end;
      end if;

      if not Item.Single then
         Scrollbars.Draw (Item.Bar, Target, Colors, Bar_Metrics (Item));
      end if;

      Restore_Clip (Target, Outer_Clip);
   end Draw;

end Pomarine.Text_Areas;
