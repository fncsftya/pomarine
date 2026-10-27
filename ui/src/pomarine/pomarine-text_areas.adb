with Pomarine.Text_Areas.Blocks;
with Pomarine.Text_Areas.Core;
with Pomarine.Text_Areas.Drawing;
with Pomarine.Text_Areas.Finding;
with Pomarine.Text_Areas.Geometry;
with Pomarine.Text_Areas.Keys;
with Pomarine.Text_Areas.Moving;
with CoreText.Wrapping;

package body Pomarine.Text_Areas is

   package Docs renames Texts.Documents;
   package Layouts renames Typeset.Layouts;
   package Views renames Typeset.Views;

   use Blocks;
   use Core;
   use Finding;
   use Geometry;
   use Moving;
   use type Events.Event_Kind;
   use type Docs.Version;
   use type Texts.Position;
   use type Docs.Document_Access;

   --  The document

   function Is_Position (Item : Text_Area; At_Point : Position) return Boolean
   is (Docs.Is_Position (Item.Doc.all, At_Point));

   --  Setting up

   procedure Configure (Item : in out Text_Area; Family : String; Size : Float; Measure : Float; Spacing : Float := 0.0)
   is
   begin
      Item.Measure := Measure;
      Item.Caret_Kept := False;
      Layouts.Configure (Item.Laid, Family, Size, Measure, Spacing);
   end Configure;

   function Is_Configured (Item : Text_Area) return Boolean
   is (Layouts.Is_Configured (Item.Laid));

   procedure Set_Shared (Item : in out Text_Area; Shared : not null Shared_Access) is
   begin
      Views.Set_Shared (Item.View, Shared);
   end Set_Shared;

   procedure Set_Single_Line (Item : in out Text_Area; To : Boolean := True) is
   begin
      Item.Single := To;
      Item.Across_Scroll := 0.0;
      Item.Returned := False;
      Item.Caret_Kept := False;
   end Set_Single_Line;

   function Is_Single_Line (Item : Text_Area) return Boolean
   is (Item.Single);

   procedure Set_Read_Only (Item : in out Text_Area; To : Boolean := True) is
   begin
      Item.Read_Only := To;
   end Set_Read_Only;

   function Is_Read_Only (Item : Text_Area) return Boolean
   is (Item.Read_Only);

   procedure Set_Lead (Item : in out Text_Area; Points : Float) is
   begin
      Item.Lead := Points;
   end Set_Lead;

   procedure Set_Trail (Item : in out Text_Area; Points : Float) is
   begin
      Item.Trail := Points;
   end Set_Trail;

   function Lead_Left (Item : Text_Area) return Float
   is (Item.Left + Inset (Item));

   function Line_Left (Item : Text_Area) return Float
   is (Column_Left (Item));

   function Line_Middle (Item : Text_Area) return Float
   is (Text_Top (Item) + Layouts.Line_Height (Item.Laid) * Scale (Item) / 2.0);

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

   function Is_Growing (Item : Text_Area) return Boolean
   is (Item.Grows);

   function Content_Height (Item : in out Text_Area) return Float is
   begin
      Catch_Up (Item);
      for Para in 1 .. Layouts.Count (Item.Laid) loop
         if not Layouts.Is_Complete (Item.Laid, Para) then
            Layouts.Lay_Out (Item.Laid, Item.Doc.all, Para);
         end if;
      end loop;
      return
        Layouts.Total_Height (Item.Laid)
        * Item.Zoom
        + 2.0 * Padding
        + (if Has_Toolbar (Item) then Toolbar_Points else 0.0);
   end Content_Height;

   function Return_Pending (Item : Text_Area) return Boolean
   is (Item.Returned);

   procedure Clear_Return (Item : in out Text_Area) is
   begin
      Item.Returned := False;
   end Clear_Return;

   procedure Attach (Item : in out Text_Area; Doc : not null Document_Access) is
   begin
      Item.Doc := Doc;
      Item.Explicit_Formats := False;
      Clear_Highlights (Item);
      Pomarine.Searches.Clear (Item.Found);
      Item.Search_Term := Ada.Strings.Unbounded.Null_Unbounded_String;
      Item.Serial := 0;  --  start again
      Item.Caret_Kept := False;
      Catch_Up (Item);
      Restart_Blink (Item);
   end Attach;

   function Is_Attached (Item : Text_Area) return Boolean
   is (Item.Doc /= null);

   function Document (Item : Text_Area) return Document_Access
   is (Item.Doc);

   procedure Place (Item : in out Text_Area; Left, Top, Width, Height : Float; Density : Float; Zoom : Float := 1.0) is
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

   function Contains (Item : Text_Area; X, Y : Float) return Boolean
   is (X >= Item.Left and then X < Item.Left + Item.Width and then Y >= Item.Top and then Y < Item.Top + Item.Height);

   function Is_Focused (Item : Text_Area) return Boolean
   is (Item.Focused);

   function Caret (Item : Text_Area) return Position
   is (Updated (Item, Item.At_Caret));

   function Mark (Item : Text_Area) return Position
   is (Updated (Item, Item.At_Mark));

   function Has_Selection (Item : Text_Area) return Boolean
   is (Mark (Item) /= Caret (Item));

   function Selected_Text (Item : Text_Area) return String
   is (Docs.Between (Item.Doc.all, Selection_First (Item), Selection_Last (Item)));

   --  Scrolling

   procedure Scroll (Item : in out Text_Area; By : Float) is
   begin
      Scroll_By (Item, By);
   end Scroll;

   function Scroll_Top (Item : Text_Area) return Float
   is (View_Top (Item));

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

   --  Input methods' text

   function Is_Composing (Item : Text_Area) return Boolean
   is (Item.Composing);

   procedure Compose (Item : in out Text_Area; Shown : String; Cursor : Natural) is
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
            Edit (Item, Selection_First (Item), Selection_Last (Item), "", Docs.Other);
         end if;
         Item.Composed := Item.At_Caret;
      elsif Item.Composing then
         Drop_Composition (Item);
      end if;

      if Clean /= "" then
         Change (Item, Item.Composed, Item.Composed, Clean, Recorded => False);
         Item.Composing := True;
         Item.Composed_Length := Clean'Length;

         --  The caret after Cursor characters.
         declare
            Byte : Positive := Item.Composed.Index;
            Seen : Natural := 0;
         begin
            while Seen < Cursor and then Byte < Composed_End (Item).Index loop
               Byte := Layouts.Next_Character (Item.Doc.all, Item.Composed.Paragraph, Byte);
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

   procedure Search (Item : in out Text_Area; Term : String) is
   begin
      Finding.Refresh (Item, Term);
   end Search;

   procedure Search_Step (Item : in out Text_Area; Backwards : Boolean := False) is
   begin
      Catch_Up (Item);
      Pomarine.Searches.Step (Item.Found, Backwards);
      if Item.Found.Current > 0 then
         declare
            M     : constant Pomarine.Searches.Match := Item.Found.Matches (Item.Found.Current);
            Saved : constant Position := Item.At_Caret;
         begin
            Item.At_Caret := Search_Position (Item, M.First);
            Reveal (Item);
            Item.At_Caret := Saved;
         end;
      end if;
   end Search_Step;

   procedure Search_Choose (Item : in out Text_Area; Index : Natural) is
   begin
      Item.Found.Current := Index;
   end Search_Choose;

   procedure Search_Box (Item : in out Text_Area; X, Y, Width, Height : out Float) is
      Saved : constant Position := Item.At_Caret;
      M     : constant Pomarine.Searches.Match := Item.Found.Matches (Item.Found.Current);
   begin
      Item.At_Caret := Search_Position (Item, M.First);
      Caret_Box (Item, X, Y, Width, Height);
      Item.At_Caret := Saved;
   end Search_Box;

   function Search_Count (Item : Text_Area) return Natural
   is (Natural (Item.Found.Matches.Length));
   function Search_Current (Item : Text_Area) return Natural
   is (Item.Found.Current);

   procedure Select_All (Item : in out Text_Area) is
   begin
      Catch_Up (Item);
      Select_Range (Item, (1, 1), Last_Position (Item));
   end Select_All;

   procedure Move (Item : in out Text_Area; By : Motion; Extend : Boolean := False) is
   begin
      Item.Explicit_Formats := False;
      Finish_Composition (Item);
      Docs.Seal (Item.Doc.all);
      if By not in Previous_Line | Next_Line then
         Item.Has_Goal := False;
      end if;

      if not Extend and then Has_Selection (Item) and then By in Previous_Character | Next_Character then
         Item.At_Caret := (if By = Previous_Character then Selection_First (Item) else Selection_Last (Item));
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

   function Is_Over_Selection (Item : in out Text_Area; X, Y : Float) return Boolean is
   begin
      if not Has_Selection (Item) then
         return False;
      end if;
      Catch_Up (Item);
      declare
         Point : constant Position := Point_At (Item, X, Y);
         First : constant Position := (if Item.At_Caret < Item.At_Mark then Item.At_Caret else Item.At_Mark);
         Last  : constant Position := (if Item.At_Caret < Item.At_Mark then Item.At_Mark else Item.At_Caret);
      begin
         return not (Point < First) and then Point < Last;
      end;
   end Is_Over_Selection;

   function Is_Over_Range (Item : in out Text_Area; From, To : Position; X, Y : Float) return Boolean is
   begin
      if not Contains (Item, X, Y) then
         return False;
      end if;
      Catch_Up (Item);
      declare
         Depth  : constant Float := View_Top (Item) + (Y - Text_Top (Item)) / Scale (Item);
         Para   : constant Positive := Layouts.Paragraph_At (Item.Laid, Depth);
         High   : constant Float := Layouts.Line_Height (Item.Laid, Para);
         Within : constant Float := (Depth - Layouts.Top (Item.Laid, Para)) / High;
      begin
         if Para not in From.Paragraph .. To.Paragraph or else Within < 0.0 or else Within >= Float (Most_Lines) then
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
               Line  : constant CoreText.Wrapping.Span := Layouts.Line (Item.Laid, Para, Number);
               First : constant Natural :=
                 Natural'Max (Line.First, (if Para = From.Paragraph then Units (Item, From) else 0));
               Last  : constant Natural :=
                 Natural'Min (Line.Stop, (if Para = To.Paragraph then Units (Item, To) else Line.Stop));
            begin
               if First >= Last then
                  return False;
               end if;
               declare
                  Left  : constant Float :=
                    Column_Left (Item)
                    + Scale (Item) * Layouts.Caret_Offset (Item.Laid, Item.Doc.all, Para, Number, First);
                  Right : constant Float :=
                    Column_Left (Item)
                    + Scale (Item) * Layouts.Caret_Offset (Item.Laid, Item.Doc.all, Para, Number, Last);
               begin
                  return X >= Float'Min (Left, Right) and then X < Float'Max (Left, Right);
               end;
            end;
         end;
      end;
   end Is_Over_Range;

   procedure Click (Item : in out Text_Area; X, Y : Float; Clicks : Positive := 1; Extend : Boolean := False) is
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
            Layouts.Word_At (Item.Doc.all, Point.Paragraph, Point.Index, First, Stop);
            --  Not on a word: the character there.
            if First = Stop and then Point.Index <= Byte_Length (Item, Point.Paragraph) then
               Stop := Layouts.Next_Character (Item.Doc.all, Point.Paragraph, Point.Index);
            end if;
            Item.At_Mark := (Point.Paragraph, First);
            Item.At_Caret := (Point.Paragraph, Stop);
         end;
      else
         Item.At_Mark := (Point.Paragraph, 1);
         Item.At_Caret := Para_End (Item, Point.Paragraph);
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
            Point       : constant Position := Point_At (Item, X, Y);
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

   function Is_Dragging (Item : Text_Area) return Boolean
   is (Item.Dragging);

   --  Editing

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
         Docs.Set_Format
           (Item.Doc.all, Selection_First (Item), Selection_Last (Item), Style, not Format_Active (Item, Style));
         Catch_Up (Item);
         Reveal (Item);
      else
         Start_Pending (Item);
         Item.Pending_Formats (Style) := not Item.Pending_Formats (Style);
         Docs.Seal (Item.Doc.all);
      end if;
   end Toggle_Format;

   function Size_Here (Item : Text_Area) return Natural
   is (if Item.Explicit_Formats and then not Has_Selection (Item)
       then Item.Pending_Size
       else Docs.Size_At (Item.Doc.all, Selection_First (Item), Selection_Last (Item)));

   function Family_Here (Item : Text_Area) return String
   is (if Item.Explicit_Formats and then not Has_Selection (Item)
       then Ada.Strings.Unbounded.To_String (Item.Pending_Family)
       else Docs.Family_At (Item.Doc.all, Selection_First (Item), Selection_Last (Item)));

   function Is_Address (Words : String) return Boolean
   is (Docs.Is_Address (Words));

   function Link_Here (Item : Text_Area) return String
   is (Docs.Link_At (Item.Doc.all, Selection_First (Item), Selection_Last (Item)));

   procedure Set_Link (Item : in out Text_Area; Address : String) is
   begin
      if Item.Single or else Item.Read_Only or else not Has_Selection (Item) then
         return;
      end if;
      Finish_Composition (Item);
      Docs.Set_Link (Item.Doc.all, Selection_First (Item), Selection_Last (Item), Address);
      Catch_Up (Item);
      Reveal (Item);
   end Set_Link;

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

   function Paragraph_Style (Item : Text_Area) return Texts.Paragraph_Kind
   is (Docs.Kind (Item.Doc.all, Caret (Item).Paragraph));

   procedure Toggle_Block (Item : in out Text_Area; Which : Block) is
   begin
      Blocks.Toggle (Item, Which);
   end Toggle_Block;

   procedure Shift_Indent (Item : in out Text_Area; Outward : Boolean) is
   begin
      Blocks.Indent (Item, Outward);
   end Shift_Indent;

   procedure Set_Style (Item : in out Text_Area; To : Texts.Paragraph_Kind) is
   begin
      Blocks.Style_Paragraphs (Item, To);
   end Set_Style;

   procedure Insert (Item : in out Text_Area; Typed : String) is
   begin
      Drop_Composition (Item);  --  Typed is what it became
      Clear_Of_Mark (Item, Typed);
      Edit (Item, Selection_First (Item), Selection_Last (Item), Fitted (Item, Typed), Docs.Typing);
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
         when Character => (if Forward then Next_Character else Previous_Character),
         when Word      => (if Forward then Next_Word else Previous_Word),
         when Line_Part => (if Forward then Line_End else Line_Start));

   procedure Delete_Backward (Item : in out Text_Area; By : Deletion := Character) is
   begin
      Finish_Composition (Item);
      if Has_Selection (Item) then
         Edit (Item, Selection_First (Item), Selection_Last (Item), "", Docs.Other);
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
         elsif Found.Length > 0
           and then Item.At_Caret.Index = 1
           and then At_Para > 1
           and then Docs.Byte_Length (Item.Doc.all, At_Para - 1) > 0
         then
            --  Joining onto text above: the item gives up its mark.
            Replace_Range
              (Item, (At_Para - 1, Docs.Byte_Length (Item.Doc.all, At_Para - 1) + 1), Mark_End (Item, At_Para), "");
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

   procedure Delete_Forward (Item : in out Text_Area; By : Deletion := Character) is
   begin
      Finish_Composition (Item);
      if Has_Selection (Item) then
         Edit (Item, Selection_First (Item), Selection_Last (Item), "", Docs.Other);
         Renumber_Caret (Item);
         return;
      end if;
      declare
         Para : constant Positive := Item.At_Caret.Paragraph;
         To   : Position := Step (Item, Item.At_Caret, Deletion_Motion (By, True));
      begin
         if Para < Docs.Count (Item.Doc.all)
           and then Marker_Of (Item, Para + 1).Length > 0
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

   procedure Copy (Item : in out Text_Area; Board : in out Clipboards.Clipboard'Class) is
   begin
      Finish_Composition (Item);
      if Has_Selection (Item) then
         Board.Set_Text (Selected_Text (Item));
      end if;
   end Copy;

   procedure Cut (Item : in out Text_Area; Board : in out Clipboards.Clipboard'Class) is
   begin
      Copy (Item, Board);
      if Has_Selection (Item) then
         Edit (Item, Selection_First (Item), Selection_Last (Item), "", Docs.Other);
         Renumber_Caret (Item);
      end if;
   end Cut;

   procedure Paste (Item : in out Text_Area; Board : in out Clipboards.Clipboard'Class) is
   begin
      Finish_Composition (Item);
      Clear_Of_Mark (Item, Board.Text);
      Edit (Item, Selection_First (Item), Selection_Last (Item), Fitted (Item, Board.Text), Docs.Other);
   end Paste;

   --  Undoing

   procedure Undo (Item : in out Text_Area) is
      From, To : Position;
   begin
      Finish_Composition (Item);
      if not Item.Read_Only and then Docs.Can_Undo (Item.Doc.all) and then not Docs.In_Step (Item.Doc.all) then
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
      if not Item.Read_Only and then Docs.Can_Redo (Item.Doc.all) and then not Docs.In_Step (Item.Doc.all) then
         Docs.Redo (Item.Doc.all, From, To);
         Catch_Up (Item);
         Item.At_Mark := To;
         Item.At_Caret := To;
         Item.Has_Goal := False;
         Moved (Item);
      end if;
   end Redo;

   --  Blinking

   procedure Tick (Item : in out Text_Area; Now : Pomarine.Events.Milliseconds; Changed : out Boolean) is
      On : Boolean;
   begin
      Item.Now := Pomarine.Events.Milliseconds'Max (Item.Now, Now);
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

   function Is_Caret_Shown (Item : Text_Area) return Boolean
   is (Item.Caret_Visible and then Item.Focused and then Item.Caret_On);

   function Until_Blink (Item : Text_Area) return Pomarine.Events.Milliseconds
   is (Blink_Period - (Item.Now - Item.Since) mod Blink_Period);

   --  Events

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

   function Highlight_Count (Item : Text_Area) return Natural
   is (if Item.Doc /= null
         and then Item.Highlight_Serial = Docs.Serial (Item.Doc.all)
         and then Item.Highlight_Version = Docs.Current (Item.Doc.all)
       then Item.Highlight_Total
       else 0);

   procedure Add_Highlight (Item : in out Text_Area; From, To : Position; Fill, Ink : Themes.Color) is
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

   procedure Take_Bar_Change (Item : in out Text_Area; Changed : out Boolean) is
   begin
      Changed := Item.Bar_Dirty;
      Item.Bar_Dirty := False;
   end Take_Bar_Change;

   procedure Handle
     (Item : in out Text_Area; Event : Events.Event; Board : in out Clipboards.Clipboard'Class; Handled : out Boolean)
   is
      X : constant Float := Event.Mouse_X * Item.Density;
      Y : constant Float := Event.Mouse_Y * Item.Density;
   begin
      Catch_Up (Item);
      Item.Now := Pomarine.Events.Milliseconds'Max (Item.Now, Event.Time);
      Handled := False;
      if not Item.Single
        and then not Item.Grows
        and then Event.Kind in Events.Mouse_Down | Events.Mouse_Move | Events.Mouse_Up
      then
         declare
            Dragged, Changed : Boolean;
            To               : Float;
            Before           : constant Boolean := Scrollbars.Is_Showing (Item.Bar);
         begin
            if Event.Kind = Events.Mouse_Move then
               Scrollbars.Set_Pane (Item.Bar, Contains (Item, X, Y));
            end if;
            Scrollbars.Handle (Item.Bar, Event, Drawing.Bar_Metrics (Item), Handled, Dragged, To, Changed);
            if Dragged then
               Scroll (Item, To - View_Top (Item));
            end if;
            if Changed or else Dragged or else Before /= Scrollbars.Is_Showing (Item.Bar) then
               Item.Bar_Dirty := True;
            end if;
            if Handled then
               return;
            end if;
         end;
      end if;
      case Event.Kind is
         when Events.Mouse_Down                                                                                =>
            if Event.Button = 1 and then Contains (Item, X, Y) then
               if Y < Item.Top + Toolbar_Room (Item) then
                  null;  --  the toolbar's, whose buttons take their own clicks

               else
                  Item.Explicit_Formats := False;
                  Click (Item, X, Y, Natural'Max (1, Event.Clicks), Extend => Event.Shift);
               end if;
               Handled := True;
            end if;

         when Events.Mouse_Move                                                                                =>
            if Item.Dragging and then Event.Left_Held then
               Drag (Item, X, Y);
               Handled := True;
            elsif Item.Dragging then
               Release (Item);  --  let go where it was not seen
            end if;

         when Events.Mouse_Up                                                                                  =>
            if Event.Button = 1 then
               Release (Item);
            end if;

         when Events.Mouse_Wheel                                                                               =>
            if not Item.Grows and then not Event.Command and then Contains (Item, X, Y) then
               declare
                  Before : constant Float := View_Top (Item);
               begin
                  Scroll (Item, -Event.Wheel_Y * Lines_Per_Notch * Layouts.Line_Height (Item.Laid));
                  --  At either end it still holds the wheel, if there is a bar
                  --  to scroll, so the canvas under it does not pan instead.
                  Handled := View_Top (Item) /= Before or else Layouts.Total_Height (Item.Laid) > Extent (Item);
               end;
            end if;

         when Events.Text_Input                                                                                =>
            if Item.Focused then
               Insert (Item, Events.Typed (Event));
               Handled := True;
            end if;

         when Events.Text_Editing                                                                              =>
            if Item.Focused then
               Compose (Item, Events.Typed (Event), Event.Cursor);
               Handled := True;
            end if;

         when Events.Key_Down                                                                                  =>
            if not Item.Composing then
               Keys.Handle_Key (Item, Event, Board, Handled);
            end if;

         when Events.Quit | Events.Pinch | Events.Redraw | Events.Theme_Changed | Events.Key_Up | Events.Other =>
            null;
      end case;
   end Handle;

   procedure Caret_Box (Item : in out Text_Area; X, Y, Width, Height : out Float) is
   begin
      Measure_Caret (Item, X, Y, Width, Height);
   end Caret_Box;
   function Lines_Drawn (Item : Text_Area) return Natural
   is (Views.Lines_Drawn (Item.View));

   function Caret_Measures (Item : Text_Area) return Natural
   is (Item.Caret_Worked);

   procedure Draw
     (Item      : in out Text_Area;
      Target    : SDL3.Painters.Painter'Class;
      Colors    : Themes.Theme;
      Settled   : Boolean := True;
      Rows_From : Float := Float'First;
      Rows_To   : Float := Float'Last) is
   begin
      Drawing.Render (Item, Target, Colors, Settled, Rows_From, Rows_To);
   end Draw;

end Pomarine.Text_Areas;
