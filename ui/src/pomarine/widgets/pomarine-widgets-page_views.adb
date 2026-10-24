with Pomarine.Marks.Drawing;
with Pomarine.Mark_Paths;
with Ada.Unchecked_Deallocation;
with Pomarine.Line_Texts;
with Pomarine.Themes;
with Pomarine.Words;
with SDL3.Windows.Renderers;

package body Pomarine.Widgets.Page_Views is

   package Tex renames SDL3.Windows.Renderers.Textures;

   Poll : constant := 10;
   --  Milliseconds between frames while pages are still to be made.

   use type Semantics.Role;
   use type Pomarine.Events.Event_Kind;
   use type Pomarine.Events.Key_Code;
   use type Pomarine.Pages.Page_Access;
   use type Pomarine.Page_Builds.Result_Access;

   procedure Free is new Ada.Unchecked_Deallocation (Pomarine.Words.Result, Result_Access);
   procedure Free is new Ada.Unchecked_Deallocation (Float_Array, Float_Array_Access);

   function Clamped_Mark (Left, Right, Y : Float; Page : Positive) return Mark is
      function Unit (Value : Float) return Float is
        (Float'Min (1.0, Float'Max (0.0, Value)));
      Low : constant Float := Unit (Left);
   begin
      return (Left => Low, Right => Float'Max (Low, Unit (Right)), Y => Unit (Y), Page => Page, Trace => <>);
   end Clamped_Mark;

   --  Where things are

   function Count (Item : Page_View) return Natural is
     (if Item.Sizes = null then 0 else Item.Sizes'Length);

   function Wide_Of (Item : Page_View) return Float is
     (Width_Of (Item) * Item.Zoomed);

   function Gap_Px (Item : Page_View) return Float is
     (Page_Gap * Density (Item));

   function Offset (Item : Page_View; Index : Positive) return Float is
     (Wide_Of (Item) * Item.Ratios (Index) + Float (Index - 1) * Gap_Px (Item));
   --  Pixels from the top of the document to the top of the page; of one
   --  past the last, to where a gap after it would end.

   function Total_Of (Item : Page_View) return Float is
     (if Count (Item) = 0 then 0.0
      else Offset (Item, Count (Item) + 1) - Gap_Px (Item));

   function Page_Height (Item : Page_View; Index : Positive) return Float is
     (Wide_Of (Item) * (Item.Ratios (Index + 1) - Item.Ratios (Index)));

   function Content_Top (Item : Page_View) return Float is
     (Top_Of (Item) - Item.Down * Total_Of (Item));

   function Page_Top (Item : Page_View; Index : Positive) return Float is
     (Content_Top (Item) + Offset (Item, Index));

   function Origin_X (Item : Page_View) return Float is
     (Left_Of (Item)
      - Item.Across * Float'Max (0.0, Wide_Of (Item) - Width_Of (Item)));

   function Page_At (Item : Page_View; Y : Float) return Positive is
      Low  : Positive := 1;
      High : Positive := Count (Item);
      Mid  : Positive;
      Down : constant Float := Y - Content_Top (Item);
   begin
      --  The last page that starts at or above Y.
      while Low < High loop
         Mid := (Low + High + 1) / 2;
         if Offset (Item, Mid) <= Down then
            Low := Mid;
         else
            High := Mid - 1;
         end if;
      end loop;
      return Low;
   end Page_At;

   function Slot_Of (Item : Page_View; Index : Positive) return Natural is
   begin
      for Each in Item.Cached'Range loop
         if Item.Cached (Each).Index = Index then
            return Each;
         end if;
      end loop;
      return 0;
   end Slot_Of;

   function Words_Of (Item : Page_View; Index : Natural) return Result_Access is
   begin
      if Index = 0 then
         return null;
      end if;
      declare
         Which : constant Natural := Slot_Of (Item, Index);
      begin
         return (if Which = 0 or else Item.Cached (Which).Content = null
                 then null else Item.Cached (Which).Found);
      end;
   end Words_Of;

   --  Document

   procedure Release_Slot (Each : in out Slot) is
   begin
      if Each.Job /= 0 then
         Pomarine.Page_Builds.Cancel (Each.Job);
         Each.Job := 0;
      end if;
      Pomarine.Pages.Free (Each.Content);
      for Shown of Each.Images loop
         Tex.Release (Shown);
      end loop;
      if Each.Found /= null then
         Each.Found.Count := 0;
         Each.Found.Length := 0;
      end if;
      Each.Index := 0;
   end Release_Slot;

   procedure Unload (Item : in out Page_View) is
   begin
      for Each of Item.Cached loop
         Release_Slot (Each);
      end loop;
      Item.Held := False;
      Item.Anchor := 0;
      Item.Head := 0;
      Item.Sel_Page := 0;
      Item.Pending := False;
   end Unload;

   procedure Clear_Marks (Item : in out Page_View) is
   begin
      Item.Past := Pomarine.Marks.Empty_History;
      if Item.Marks > 0 or else Item.Marking then
         Item.Marks := 0;
         Item.Marking := False;
         if Is_Attached (Item) then
            Invalidate (Item);
         end if;
      end if;
   end Clear_Marks;

   procedure Fill_Ratios (Item : in out Page_View) is
      Sizes : Pomarine.Pages.Size_Array renames Item.Sizes.all;
   begin
      Item.Ratios (1) := 0.0;
      for Index in Sizes'Range loop
         Item.Ratios (Index + 1) :=
           Item.Ratios (Index) + Sizes (Index).Height / Float'Max (1.0, Sizes (Index).Width);
      end loop;
   end Fill_Ratios;

   procedure Clear_Document (Item : in out Page_View) is
   begin
      Search (Item, "");
      if Item.Measuring /= 0 then
         Pomarine.Page_Builds.Cancel (Item.Measuring);
         Item.Measuring := 0;
      end if;
      Unload (Item);
      for Each of Item.Cached loop
         Free (Each.Found);
      end loop;
      Free (Item.Ratios);
      Item.Sizes := null;
      Item.Source := null;
      Item.Down := 0.0;
      Item.Across := 0.0;
      Item.Wanted := 0;
      Clear_Marks (Item);
      if Is_Attached (Item) then
         Invalidate (Item);
      end if;
   end Clear_Document;

   procedure Set_Document
     (Item   : in out Page_View;
      Sizes  : Pomarine.Pages.Size_Array_Access;
      Source : Pomarine.Pages.Source_Access;
      Guess  : Boolean := False) is
   begin
      Clear_Document (Item);
      Item.Sizes := Sizes;
      Item.Source := Source;
      Item.Ratios := new Float_Array (1 .. Sizes'Length + 1);
      Fill_Ratios (Item);
      if Guess then
         Pomarine.Page_Builds.Request_Sizes (Source, Sizes'Length, Item.Measuring);
         Item.Pending := True;
      end if;
      if Is_Attached (Item) then
         Invalidate (Item);
      end if;
   end Set_Document;

   function Has_Document (Item : Page_View) return Boolean is (Item.Sizes /= null);

   function Page_Count (Item : Page_View) return Natural is (Count (Item));

   function Is_Settled (Item : Page_View) return Boolean is
     (Item.Wanted = 0 and then Width_Of (Item) > 0.0);

   function Current_Page (Item : Page_View) return Natural is
   begin
      if Count (Item) = 0 then
         return 0;
      end if;
      return Page_At (Item, Top_Of (Item) + 0.3 * Height_Of (Item));
   end Current_Page;

   function Scrolled (Item : Page_View) return Float is (Item.Down);

   function Scrolled_Across (Item : Page_View) return Float is (Item.Across);

   function Zoom (Item : Page_View) return Float is (Item.Zoomed);

   function Furthest (Item : Page_View; High : Float) return Float is
      Total : constant Float := Total_Of (Item);
   begin
      return (if Total <= 0.0 then 1.0
              elsif High > 0.0 and then Total > High then 1.0 - High / Total
              else 0.0);
   end Furthest;
   --  The most Down can be, for a box High pixels high, so that the end of
   --  the document is at the box's.

   procedure Scroll_To (Item : in out Page_View; To : Float) is
      --  Before it is laid out how far it can go is not known: keep To, which
      --  the first draw clamps.
      Wanted : constant Float :=
        (if Height_Of (Item) <= 0.0 or else Width_Of (Item) <= 0.0
         then Float'Min (To, 1.0)
         else Float'Min (To, Furthest (Item, Height_Of (Item))));
   begin
      Item.Wanted := 0;
      if Wanted /= Item.Down then
         Item.Down := Wanted;
         Invalidate (Item);
      end if;
   end Scroll_To;

   procedure Show_Page (Item : in out Page_View; Page : Positive) is
      Total : constant Float := Total_Of (Item);
   begin
      if Width_Of (Item) <= 0.0 or else Total <= 0.0 then
         --  Not laid out: how far down it is is not known yet.
         Item.Wanted := Page;
      else
         Scroll_To (Item, Float'Min (1.0, Offset (Item, Page) / Total));
      end if;
   end Show_Page;

   procedure Scroll_Across_To (Item : in out Page_View; To : Float) is
   begin
      if To /= Item.Across then
         Item.Across := To;
         Invalidate (Item);
      end if;
   end Scroll_Across_To;

   procedure Set_Zoom (Item : in out Page_View; To : Float) is
   begin
      if To /= Item.Zoomed then
         Item.Zoomed := To;
         if Is_Attached (Item) then
            Invalidate (Item);
         end if;
      end if;
   end Set_Zoom;

   --  Highlights

   function Tool (Item : Page_View) return Tools is (Item.Chosen);

   function Is_Marking (Item : Page_View) return Boolean is (Item.Marking);

   function Mark_Count (Item : Page_View) return Natural is (Item.Marks);

   function Mark_At (Item : Page_View; Index : Positive) return Mark is
     (Item.Marked.Data (Index));

   function Marks_Version (Item : Page_View) return Natural is (Item.Version);

   procedure Set_Tool (Item : in out Page_View; To : Tools) is
   begin
      Item.Chosen := To;
      Item.Marking := False;
      Item.Held := False;
      if Is_Attached (Item) then
         Invalidate (Item);
      end if;
   end Set_Tool;

   function History_Of (Item : Page_View) return Pomarine.Marks.History is (Item.Past);
   function Can_Undo (Item : Page_View) return Boolean is (Pomarine.Marks.Can_Undo (Item.Past));
   function Can_Redo (Item : Page_View) return Boolean is (Pomarine.Marks.Can_Redo (Item.Past));

   procedure Undo (Item : in out Page_View) is
   begin
      if Item.Marking then
         Item.Marking := False;
      elsif Can_Undo (Item) then
         Pomarine.Marks.Undo (Item.Past, Item.Marked, Item.Marks);
         Item.Version := Item.Version + 1;
      else
         return;
      end if;
      if Is_Attached (Item) then
         Invalidate (Item);
      end if;
   end Undo;

   procedure Redo (Item : in out Page_View) is
   begin
      if Item.Marking or else not Can_Redo (Item) then
         return;
      end if;
      Pomarine.Marks.Redo (Item.Past, Item.Marked, Item.Marks);
      Item.Version := Item.Version + 1;
      if Is_Attached (Item) then
         Invalidate (Item);
      end if;
   end Redo;

   overriding procedure Handle_Command
     (Item : in out Page_View; Tag : Integer; Done : out Boolean) is
   begin
      Done := True;
      if Tag = Edit_Undo then
         Undo (Item);
      elsif Tag = Edit_Redo then
         Redo (Item);
      else
         Done := False;
      end if;
   end Handle_Command;

   procedure Set_Marks
     (Item : in out Page_View; To : Mark_Array;
      Past : Pomarine.Marks.History := Pomarine.Marks.Empty_History) is
   begin
      Item.Past := Past;
      Item.Marks := To'Length;
      Pomarine.Marks.Reserve (Item.Marked, To'Length + 1);
      Item.Marking := False;
      Item.Marked.Data (1 .. To'Length) := To;
      if Is_Attached (Item) then
         Invalidate (Item);
      end if;
   end Set_Marks;

   --  Text

   function Has_Words (Item : Page_View) return Boolean is
     (Words_Of (Item, Current_Page (Item)) /= null);

   function Word_Count (Item : Page_View) return Natural is
      Found : constant Result_Access := Words_Of (Item, Current_Page (Item));
   begin
      return (if Found = null then 0 else Found.Count);
   end Word_Count;

   function Has_Selection (Item : Page_View) return Boolean is
     (Item.Anchor > 0 and then Item.Head > 0);

   function First_Selected (Item : Page_View) return Natural is
     (Natural'Min (Item.Anchor, Item.Head));

   function Last_Selected (Item : Page_View) return Natural is
     (Natural'Max (Item.Anchor, Item.Head));

   function Selected_Text (Item : Page_View) return String is
      Found  : constant Result_Access := Words_Of (Item, Item.Sel_Page);
      Result : Ada.Strings.Unbounded.Unbounded_String;

      procedure Append (Text : String) is
      begin
         Ada.Strings.Unbounded.Append (Result, Text);
      end Append;
   begin
      if not Has_Selection (Item) or else Found = null then
         return "";
      end if;
      for Index in First_Selected (Item) .. Last_Selected (Item) loop
         if Index > First_Selected (Item) then
            Append
              (if Found.Words (Index).Line = Found.Words (Index - 1).Line
               then " " else [ASCII.LF]);
         end if;
         Append (Pomarine.Words.Image (Found.Words (Index), Found.all));
      end loop;
      return Ada.Strings.Unbounded.To_String (Result);
   end Selected_Text;

   procedure Select_Range (Item : in out Page_View; Page, From, To : Natural) is
   begin
      if Item.Sel_Page /= Page or else Item.Anchor /= From or else Item.Head /= To then
         Item.Sel_Page := Page;
         Item.Anchor := From;
         Item.Head := To;
         if Is_Attached (Item) then
            Invalidate (Item);
         end if;
      end if;
   end Select_Range;

   procedure Clear_Selection (Item : in out Page_View) is
   begin
      Select_Range (Item, 0, 0, 0);
   end Clear_Selection;

   procedure Select_All (Item : in out Page_View) is
      Page  : constant Natural := Current_Page (Item);
      Found : constant Result_Access := Words_Of (Item, Page);
   begin
      if Found /= null and then Found.Count > 0 then
         Select_Range (Item, Page, 1, Found.Count);
      end if;
   end Select_All;

   function Gap (From, To, At_Point : Float) return Float is
     (if At_Point < From then From - At_Point
      elsif At_Point > To then At_Point - To else 0.0);
   --  How far a point is from the span From .. To.

   function Word_At
     (Item : Page_View; Page : Positive; X, Y : Float; Nearest : Boolean) return Natural
   is
      Found    : constant Result_Access := Words_Of (Item, Page);
      Best     : Natural := 0;
      Best_Gap : Float := Float'Last;
      Wide     : constant Float := Wide_Of (Item);
      High     : constant Float := Page_Height (Item, Page);
      Left     : constant Float := Origin_X (Item);
      Top      : constant Float := Page_Top (Item, Page);
   begin
      if Found = null then
         return 0;
      end if;
      for Index in 1 .. Found.Count loop
         declare
            Each   : Pomarine.Words.Word renames Found.Words (Index);
            Across : constant Float :=
              Gap (Left + Each.Left * Wide, Left + (Each.Left + Each.Width) * Wide, X);
            Down   : constant Float :=
              Gap (Top + Each.Top * High, Top + (Each.Top + Each.Height) * High, Y);
            --  Down counts for more: the nearest on its line is the one
            --  wanted, before one above or below.
            Away   : constant Float := Across + 4.0 * Down;
         begin
            if Away < Best_Gap then
               Best_Gap := Away;
               Best := Index;
            end if;
         end;
      end loop;
      return (if Nearest or else Best_Gap = 0.0 then Best else 0);
   end Word_At;

   function Is_Over_Selection (Item : Page_View; X, Y : Float) return Boolean is
   begin
      if not Has_Selection (Item) or else Count (Item) = 0 then
         return False;
      end if;
      declare
         Under : constant Natural :=
           Word_At (Item, Page_At (Item, Y), X, Y, Nearest => False);
      begin
         return Under > 0 and then Page_At (Item, Y) = Item.Sel_Page
           and then Under in First_Selected (Item) .. Last_Selected (Item);
      end;
   end Is_Over_Selection;

   procedure Copy (Item : Page_View) is
   begin
      if Has_Selection (Item) and then Clipboard (Item) /= null then
         Clipboard (Item).Set_Text (Selected_Text (Item));
      end if;
   end Copy;

   procedure Select_Line (Item : in out Page_View; Page, Index : Positive) is
      Found : constant Result_Access := Words_Of (Item, Page);
      Line  : constant Natural := Found.Words (Index).Line;
      First : Positive := Index;
      Last  : Positive := Index;
   begin
      while First > 1 and then Found.Words (First - 1).Line = Line loop
         First := First - 1;
      end loop;
      while Last < Found.Count and then Found.Words (Last + 1).Line = Line loop
         Last := Last + 1;
      end loop;
      Select_Range (Item, Page, First, Last);
   end Select_Line;

   function Down_Metrics (Item : Page_View) return Scrollbars.Metrics is
     (Left    => Left_Of (Item), Top => Top_Of (Item),
      Width   => Width_Of (Item), Height => Height_Of (Item),
      Density => Density (Item),
      Start   => Item.Down * Total_Of (Item),
      Shown   => Height_Of (Item),
      Total   => Total_Of (Item),
      Horizontal => False);

   function Across_Metrics (Item : Page_View) return Scrollbars.Metrics is
     (Left    => Left_Of (Item), Top => Top_Of (Item),
      Width   => Width_Of (Item), Height => Height_Of (Item),
      Density => Density (Item),
      Start   => Item.Across * Float'Max (0.0, Wide_Of (Item) - Width_Of (Item)),
      Shown   => Width_Of (Item),
      Total   => Wide_Of (Item),
      Horizontal => True);

   --  Marking

   function Along (Item : Page_View; X : Float) return Float is
     (Float'Min (1.0, Float'Max (0.0, (X - Origin_X (Item)) / Wide_Of (Item))));
   --  How far across the pages the pixel X is, clamped to them.

   function Down_Of (Item : Page_View; Page : Positive; Y : Float) return Float is
     (Float'Min (1.0, Float'Max (0.0, (Y - Page_Top (Item, Page)) / Page_Height (Item, Page))));

   procedure Extend_Mark (Item : in out Page_View; X, Y : Float) is
      Each : Mark renames Item.Marked.Data (Item.Marks + 1);
   begin
      Mark_Paths.Append (Each.Trace, Along (Item, X), Down_Of (Item, Each.Page, Y));
   end Extend_Mark;

   function Mark_Under (Item : Page_View; X, Y : Float) return Natural is
      Across : constant Float := Along (Item, X);
      Half   : constant Float := Mark_Height * Wide_Of (Item) / 2.0;
   begin
      for Index in reverse 1 .. Item.Marks loop
         declare
            Each : Mark renames Item.Marked.Data (Index);
         begin
            if Each.Page <= Count (Item)
              and then ((Each.Trace.Count > 0 and then
                Mark_Paths.Contains (Each.Trace, X - Origin_X (Item), Y - Page_Top (Item, Each.Page),
                                     Wide_Of (Item), Page_Height (Item, Each.Page), Half))
              or else (Each.Trace.Count = 0 and then Across in Each.Left .. Each.Right
              and then abs (Y - (Page_Top (Item, Each.Page)
                                 + Each.Y * Page_Height (Item, Each.Page))) <= Half))
            then
               return Index;
            end if;
         end;
      end loop;
      return 0;
   end Mark_Under;

   procedure Handle_Marking
     (Item    : in out Page_View;
      Event   : Pomarine.Events.Event;
      Handled : out Boolean)
   is
      X : constant Float := Event.Mouse_X * Density (Item);
      Y : constant Float := Event.Mouse_Y * Density (Item);
   begin
      Handled := False;
      case Event.Kind is
         when Pomarine.Events.Mouse_Down =>
            if Event.Button = 1 and then Contains (Item, X, Y)
              and then Item.Chosen = Pictures.Eraser
            then
               declare
                  Under : constant Natural := Mark_Under (Item, X, Y);
               begin
                  if Under > 0 then
                     Pomarine.Marks.Record_Remove (Item.Past, Item.Marked.Data (Under), Under);
                     Item.Marked.Data (Under .. Item.Marks - 1) :=
                       Item.Marked.Data (Under + 1 .. Item.Marks);
                     Item.Marks := Item.Marks - 1;
                     Item.Version := Item.Version + 1;
                     Invalidate (Item);
                  end if;
                  Handled := True;
               end;
            elsif Event.Button = 1 and then Contains (Item, X, Y) then
               declare
                  Page : constant Positive := Page_At (Item, Y);
               begin
                  Item.Marking := True;
                  Item.Started := Along (Item, X);
                  Pomarine.Marks.Reserve (Item.Marked, Item.Marks + 2);
                  Item.Marked.Data (Item.Marks + 1) :=
                    (Left | Right => Item.Started, Y => Down_Of (Item, Page, Y), Page => Page, Trace => <>);
                  Extend_Mark (Item, X, Y);
                  Clear_Selection (Item);
                  Invalidate (Item);
                  Handled := True;
               end;
            end if;
         when Pomarine.Events.Mouse_Move =>
            if Item.Marking then
               Extend_Mark (Item, X, Y);
               Invalidate (Item);
               Handled := True;
            end if;
         when Pomarine.Events.Mouse_Up =>
            if Item.Marking and then Event.Button = 1 then
               Item.Marking := False;
               Extend_Mark (Item, X, Y);
               --  A click, that went nowhere, marks nothing.
               if Item.Marked.Data (Item.Marks + 1).Trace.Count > 1
               then
                  Item.Marks := Item.Marks + 1;
                  Pomarine.Marks.Record_Add (Item.Past, Item.Marked.Data (Item.Marks), Item.Marks);
                  Item.Version := Item.Version + 1;
               end if;
               Invalidate (Item);
               Handled := True;
            end if;
         when others =>
            null;
      end case;
   end Handle_Marking;

   overriding function Cursor (Item : Page_View) return SDL3.Cursors.Kind is
     (case Item.Chosen is
         when Pictures.Highlighter => SDL3.Cursors.Crosshair,
         when Pictures.Eraser      => SDL3.Cursors.Pointer,
         when Pictures.Pointer     => SDL3.Cursors.Default);

   overriding function Accepts_Focus (Item : Page_View) return Boolean is
     (Has_Document (Item));

   overriding procedure Focus_Changed (Item : in out Page_View; Focused : Boolean) is
      pragma Unreferenced (Focused);
   begin
      if Has_Selection (Item) then
         Invalidate (Item);
      end if;
   end Focus_Changed;

   --  Drawing

   procedure Make_Page
     (Item  : in out Page_View;
      Index : Positive;
      Which : Positive)
   is
      Each : Slot renames Item.Cached (Which);
   begin
      Release_Slot (Each);
      Each.Index := Index;
      Pomarine.Page_Builds.Request (Item.Source, Index, Each.Job);
   exception
      when Program_Error =>
         --  Too many being made: it is asked for again at the next draw.
         Release_Slot (Each);
   end Make_Page;
   --  Ask for the page to be made in the background; it is shown when it is.

   procedure Collect_Page (Item : in out Page_View; Which : Positive) is
      Each : Slot renames Item.Cached (Which);
   begin
      case Pomarine.Page_Builds.State (Each.Job) is
         when Pomarine.Page_Builds.Working =>
            Item.Pending := True;
         when Pomarine.Page_Builds.Done =>
            Free (Each.Found);
            Pomarine.Page_Builds.Take (Each.Job, Each.Content, Each.Found);
            Each.Job := 0;
         when Pomarine.Page_Builds.Failed =>
            Pomarine.Page_Builds.Cancel (Each.Job);
            Each.Job := 0;
            if Each.Found = null then
               Each.Found := new Pomarine.Words.Result;
            end if;
            Each.Found.Count := 0;
      end case;
   end Collect_Page;
   --  Take the page if it has been made. A page that could not be made is
   --  left with no Content, as it is shown.

   procedure Collect_Sizes (Item : in out Page_View) is
      Fresh : Pomarine.Pages.Size_Array_Access;
   begin
      case Pomarine.Page_Builds.State (Item.Measuring) is
         when Pomarine.Page_Builds.Working =>
            Item.Pending := True;
         when Pomarine.Page_Builds.Failed =>
            --  The guess stays.
            Pomarine.Page_Builds.Cancel (Item.Measuring);
            Item.Measuring := 0;
         when Pomarine.Page_Builds.Done =>
            Pomarine.Page_Builds.Take_Sizes (Item.Measuring, Fresh);
            Item.Measuring := 0;
            if Fresh'Length = Item.Sizes'Length then
               declare
                  --  What is at the top of the view stays there.
                  First  : constant Positive := Page_At (Item, Top_Of (Item));
                  Inside : constant Float :=
                    (Top_Of (Item) - Page_Top (Item, First)) / Float'Max (1.0, Wide_Of (Item));
               begin
                  Item.Sizes.all := Fresh.all;
                  Fill_Ratios (Item);
                  if Total_Of (Item) > 0.0 then
                     Item.Down :=
                       Float'Min (1.0, (Offset (Item, First) + Inside * Wide_Of (Item)) / Total_Of (Item));
                  end if;
               end;
            end if;
            Pomarine.Pages.Free (Fresh);
      end case;
   end Collect_Sizes;
   --  Take the sizes of the pages, if they have come.

   function Free_Slot
     (Item : Page_View; First_In_View, Last_In_View : Positive) return Natural
   is
      Best : Natural := 0;
   begin
      for Each in Item.Cached'Range loop
         if Item.Cached (Each).Index = 0 then
            return Each;
         elsif (Item.Cached (Each).Index < First_In_View
                or else Item.Cached (Each).Index > Last_In_View)
           and then Item.Cached (Each).Index /= Item.Sel_Page
           and then (Best = 0 or else Item.Cached (Each).Stamp < Item.Cached (Best).Stamp)
         then
            Best := Each;
         end if;
      end loop;
      return Best;
   end Free_Slot;
   --  A slot to make a page in: one not used, else the one least lately in
   --  view that is not in view now; 0 if all are.

   procedure Draw_Page_Content
     (Item   : in out Page_View;
      Target : SDL3.Painters.Painter'Class;
      Each   : in out Slot;
      Left   : Float;
      Top    : Float;
      Scale  : Float)
   is
      use type Pomarine.Pages.Kinds;
      Content : Pomarine.Pages.Page renames Each.Content.all;
      View_L  : constant Float := Left_Of (Item);
      View_T  : constant Float := Top_Of (Item);
      View_R  : constant Float := View_L + Width_Of (Item);
      View_B  : constant Float := View_T + Height_Of (Item);
      Base    : constant SDL3.Painters.Clip := Target.Current_Clip;
      Lines   : Pomarine.Line_Texts.Drawer renames Text_Lines (Item).all;
      Clipped : Natural := 0;
      Batched : Boolean := False;
      --  Whether characters are waiting to be drawn.

      function X_Of (Value : Float) return Float is (Left + Value * Scale);
      function Y_Of (Value : Float) return Float is (Top + Value * Scale);

      function Tint (Value : Pomarine.Pages.RGBA) return SDL3.Windows.Renderers.Color is
        ((Red   => SDL3.Windows.Renderers.Color_Component (Value.Red),
          Green => SDL3.Windows.Renderers.Color_Component (Value.Green),
          Blue  => SDL3.Windows.Renderers.Color_Component (Value.Blue),
          Alpha => SDL3.Windows.Renderers.Color_Component (Value.Alpha)));

      procedure Set_Clip (To : Natural) is
      begin
         if To = Clipped then
            return;
         end if;
         if Batched then
            Pomarine.Line_Texts.Flush (Lines, Target);
            Batched := False;
         end if;
         Target.Restore_Clip (Base);
         if To /= 0 then
            declare
               Box : Pomarine.Pages.Rect renames Content.Clip (To);
               L   : constant Integer := Integer (Float'Floor (X_Of (Box.Left)));
               T   : constant Integer := Integer (Float'Floor (Y_Of (Box.Top)));
               R   : constant Integer := Integer (Float'Ceiling (X_Of (Box.Right)));
               B   : constant Integer := Integer (Float'Ceiling (Y_Of (Box.Bottom)));
            begin
               Target.Narrow_Clip (L, T, Integer'Max (0, R - L), Integer'Max (0, B - T));
            end;
         end if;
         Clipped := To;
      end Set_Clip;

      procedure Fill (Op : Pomarine.Pages.Operation) is
         Batch  : constant := 3_000;
         Points : SDL3.Painters.Point_Array (1 .. Batch);
         Done   : Natural := 0;
         Total  : constant Natural := 3 * Op.Count;
      begin
         while Done < Total loop
            declare
               Held : constant Natural := Natural'Min (Batch, Total - Done);
            begin
               for K in 1 .. Held loop
                  Points (K) :=
                    (X => X_Of (Content.Corner (Op.First + Done + K - 1).X),
                     Y => Y_Of (Content.Corner (Op.First + Done + K - 1).Y));
               end loop;
               Target.Fill_Triangles (Tint (Op.Color), Points (1 .. Held), Held / 3);
               Done := Done + Held;
            end;
         end loop;
      end Fill;

      procedure Stroke (Op : Pomarine.Pages.Operation) is
         Edge  : constant Boolean := Op.Width < 0.0;
         --  The smoothing of the edge of a fill: a pixel, whatever the zoom.
         Thick : constant Float := (if Edge then 1.0 else Float'Max (1.0, Op.Width * Scale));
         Color : SDL3.Windows.Renderers.Color := Tint (Op.Color);
      begin
         --  A line thinner than a pixel is a pixel, as it is in any viewer.
         if not Edge and then Op.Width * Scale < 1.0 then
            Color.Alpha := SDL3.Windows.Renderers.Color_Component
              (Float (Color.Alpha) * Float'Max (0.7, Op.Width * Scale));
         end if;
         for K in 0 .. Op.Count - 1 loop
            declare
               A : Pomarine.Pages.Point renames Content.Corner (Op.First + 2 * K);
               B : Pomarine.Pages.Point renames Content.Corner (Op.First + 2 * K + 1);
            begin
               Target.Draw_Line (Color, X_Of (A.X), Y_Of (A.Y), X_Of (B.X), Y_Of (B.Y), Thick);
               --  A line of one ending where the next begins is joined to it
               --  by a round join, or there is a notch between them.
               if not Edge and then Thick >= 2.0 and then K + 1 < Op.Count
                 and then Content.Corner (Op.First + 2 * K + 2).X = B.X
                 and then Content.Corner (Op.First + 2 * K + 2).Y = B.Y
               then
                  Target.Fill_Circle (Color, X_Of (B.X), Y_Of (B.Y), Thick / 2.0);
               end if;
            end;
         end loop;
      end Stroke;

      procedure Show_Text (Op : Pomarine.Pages.Operation) is
         Name   : Pomarine.Pages.Face_Name renames Content.Fonts (Op.Face);
         Pixels : Float;
      begin
         for K in Op.First .. Op.First + Op.Count - 1 loop
            Pixels := Content.Letters (K).Size * Scale;
            if Pixels >= 1.0 then
               Pomarine.Line_Texts.Draw_Character
                 (Lines, Target, Tint (Op.Color),
                  Name.Name (1 .. Name.Last), Content.Letters (K).Code,
                  X_Of (Content.Letters (K).X), Y_Of (Content.Letters (K).Y),
                  Pixels);
            end if;
         end loop;
         Batched := True;
      end Show_Text;

      procedure Show_Picture (Op : Pomarine.Pages.Operation) is
         Which : constant Positive := Op.First;
      begin
         if Which > Max_Page_Images then
            return;
         end if;
         if Tex.Is_Empty (Each.Images (Which)) then
            declare
               Source : Pomarine.Pages.Image renames Content.Pictures (Which);
            begin
               Tex.Create_Premultiplied_RGBA
                 (Each.Images (Which), Target.Device.all,
                  Source.Width, Source.Height,
                  Content.Pixels (Source.First)'Address, 4 * Source.Width);
            end;
         end if;
         SDL3.Painters.Draw_Scaled
           (Target, Each.Images (Which),
            X_Of (Op.Box.Left), Y_Of (Op.Box.Top),
            (Op.Box.Right - Op.Box.Left) * Scale,
            (Op.Box.Bottom - Op.Box.Top) * Scale);
      end Show_Picture;
   begin
      for Op of Content.Op loop
         if X_Of (Op.Box.Right) >= View_L and then X_Of (Op.Box.Left) <= View_R
           and then Y_Of (Op.Box.Bottom) >= View_T and then Y_Of (Op.Box.Top) <= View_B
         then
            Set_Clip (Op.Clip);
            if Op.Kind /= Pomarine.Pages.Text and then Batched then
               Pomarine.Line_Texts.Flush (Lines, Target);
               Batched := False;
            end if;
            case Op.Kind is
               when Pomarine.Pages.Fill    => Fill (Op);
               when Pomarine.Pages.Stroke  => Stroke (Op);
               when Pomarine.Pages.Text    => Show_Text (Op);
               when Pomarine.Pages.Picture => Show_Picture (Op);
            end case;
         end if;
      end loop;
      if Batched then
         Pomarine.Line_Texts.Flush (Lines, Target);
      end if;
      Target.Restore_Clip (Base);
   end Draw_Page_Content;

   procedure Search (Item : in out Page_View; Term : String) is
   begin
      if Item.Search_Job /= 0 then
         Pomarine.Page_Builds.Cancel (Item.Search_Job);
         Item.Search_Job := 0;
      end if;
      Pomarine.Searches.Clear (Item.Search_Found);
      Item.Search_Term := Ada.Strings.Unbounded.To_Unbounded_String (Term);
      Item.Search_Page := 0;
      if Term /= "" and then Has_Document (Item) then
         Item.Search_Page := 1;
      end if;
      Invalidate (Item);
   end Search;

   procedure Search_Step (Item : in out Page_View; Backwards : Boolean := False) is
   begin
      Pomarine.Searches.Step (Item.Search_Found, Backwards);
      for B of Item.Search_Found.Boxes loop
         if B.Hit = Item.Search_Found.Current then
            Item.Wanted := 0;
            if Total_Of (Item) > 0.0 then
               Scroll_To (Item, Float'Min (1.0,
                 (Offset (Item, B.Page) + B.Top * Page_Height (Item, B.Page)) / Total_Of (Item)));
            end if;
            if Wide_Of (Item) > Width_Of (Item) then
               Scroll_Across_To (Item, Float'Min (1.0,
                 B.Left * Wide_Of (Item) / (Wide_Of (Item) - Width_Of (Item))));
            end if;
            exit;
         end if;
      end loop;
      Invalidate (Item);
   end Search_Step;

   function Search_Busy (Item : Page_View) return Boolean is (Item.Search_Page /= 0);
   function Search_Count (Item : Page_View) return Natural is (Natural (Item.Search_Found.Matches.Length));
   function Search_Current (Item : Page_View) return Natural is (Item.Search_Found.Current);

   procedure Search_Update (Item : in out Page_View) is
      use type Pomarine.Page_Builds.States;
      Content : Pomarine.Pages.Page_Access;
      Found : Result_Access;
      Job : Pomarine.Page_Builds.Ticket;
   begin
      if Item.Search_Page = 0 then
         return;
      end if;
      if Item.Search_Job /= 0 then
         if Pomarine.Page_Builds.State (Item.Search_Job) = Pomarine.Page_Builds.Working then
            return;
         elsif Pomarine.Page_Builds.State (Item.Search_Job) = Pomarine.Page_Builds.Done then
            Pomarine.Page_Builds.Take (Item.Search_Job, Content, Found);
            if Found /= null then
               Pomarine.Searches.Find_Words
                 (Item.Search_Found, Found.all, Ada.Strings.Unbounded.To_String (Item.Search_Term), Item.Search_Page);
            end if;
            Pomarine.Pages.Free (Content);
            Free (Found);
         else
            Pomarine.Page_Builds.Cancel (Item.Search_Job);
         end if;
         Item.Search_Job := 0;
         if Item.Search_Found.Current = 0 and then not Item.Search_Found.Matches.Is_Empty then
            Search_Step (Item);
         end if;
         Item.Search_Page := @ + 1;
         Invalidate (Item);
      end if;
      if Item.Search_Page <= Count (Item) then
         Pomarine.Page_Builds.Request (Item.Source, Item.Search_Page, Job);
         Item.Search_Job := Job;
      else
         Item.Search_Page := 0;
      end if;
   end Search_Update;

   overriding procedure Draw
     (Item   : in out Page_View;
      Target : SDL3.Painters.Painter'Class;
      Colors : Themes.Theme)
   is
      Box   : constant Float := Width_Of (Item);
      Wide  : constant Float := Wide_Of (Item);
      Left  : constant Float := Origin_X (Item);
      View_B : constant Float := Top_Of (Item) + Height_Of (Item);
      First, Last : Natural := 0;
   begin
      SDL3.Painters.Fill_Rect
        (Target, Colors (Themes.Background),
         Left_Of (Item), Top_Of (Item), Box, Height_Of (Item));
      if Count (Item) = 0 or else Wide <= 0.0 then
         return;
      end if;
      if Item.Wanted > 0 then
         Show_Page (Item, Natural'Min (Item.Wanted, Count (Item)));
      end if;
      Item.Down := Float'Min (Item.Down, Furthest (Item, Height_Of (Item)));
      Item.Across := Float'Min (Item.Across, 1.0);
      Item.Clock := Item.Clock + 1;
      Item.Pending := False;
      if Item.Measuring /= 0 then
         Collect_Sizes (Item);
      end if;

      --  The pages in view.
      First := Page_At (Item, Top_Of (Item));
      Last := First;
      while Last < Count (Item) and then Page_Top (Item, Last + 1) < View_B loop
         Last := Last + 1;
      end loop;

      for Index in First .. Last loop
         declare
            Top   : constant Float := Page_Top (Item, Index);
            High  : constant Float := Page_Height (Item, Index);
            Which : Natural := Slot_Of (Item, Index);
            Scale : constant Float := Wide / Item.Sizes (Index).Width;
         begin
            --  The page's paper, which is what shows until it is made.
            SDL3.Painters.Fill_Rect (Target, Themes.Paper, Left, Top, Wide, High);
            if Which = 0 and then Index - First < Cache_Size then
               Which := Free_Slot (Item, First, Last);
               if Which /= 0 then
                  Make_Page (Item, Index, Which);
                  if Item.Cached (Which).Index /= Index then
                     Which := 0;
                  end if;
               end if;
               if Which = 0 then
                  Item.Pending := True;
               end if;
            end if;
            if Which /= 0 and then Item.Cached (Which).Job /= 0 then
               Collect_Page (Item, Which);
            end if;
            if Which /= 0 then
               Item.Cached (Which).Stamp := Item.Clock;
               if Item.Cached (Which).Content /= null then
                  Draw_Page_Content
                    (Item, Target, Item.Cached (Which), Left, Top, Scale);
               end if;
            end if;
         end;
      end loop;

      for Page in First .. Last loop
         Pomarine.Searches.Draw
           (Item.Search_Found, Target, Page, Left, Page_Top (Item, Page), Wide, Page_Height (Item, Page));
      end loop;
      --  Marks and the selection, over the pages.
      declare
         High : constant Float := Mark_Height * Wide;
      begin
         if Item.Marks > 0 or else Item.Marking then
            for Page in First .. Last loop
               Pomarine.Marks.Drawing.Draw
                 (Item.Marked.Data (1 .. Item.Marks + (if Item.Marking then 1 else 0)), Page,
                  Target, Colors (Themes.Marker), SDL3.Windows.Renderers.Multiply,
                  Left, Page_Top (Item, Page), Wide, Page_Height (Item, Page), High / 2.0);
            end loop;
         end if;
      end;
      if Has_Selection (Item) and then Item.Sel_Page in First .. Last then
         declare
            Found : constant Result_Access := Words_Of (Item, Item.Sel_Page);
            Tint  : SDL3.Windows.Renderers.Color :=
              (if Has_Focus (Item) then Colors (Themes.Selection)
               else Themes.Inactive_Selection (Colors));
            Top   : constant Float := Page_Top (Item, Item.Sel_Page);
            High  : constant Float := Page_Height (Item, Item.Sel_Page);
         begin
            Tint.Alpha := 110;
            if Found /= null then
               for Index in First_Selected (Item) .. Last_Selected (Item) loop
                  declare
                     Each : Pomarine.Words.Word renames Found.Words (Index);
                  begin
                     SDL3.Painters.Fill_Rect
                       (Target, Tint,
                        Left + Each.Left * Wide, Top + Each.Top * High,
                        Each.Width * Wide, Each.Height * High);
                  end;
               end loop;
            end if;
         end;
      end if;
      Scrollbars.Draw (Item.Down_Bar, Target, Colors, Down_Metrics (Item));
      Scrollbars.Draw (Item.Across_Bar, Target, Colors, Across_Metrics (Item));
   end Draw;

   overriding procedure Update
     (Item : in out Page_View; Now : Pomarine.Events.Milliseconds)
   is
      pragma Unreferenced (Now);
   begin
      Search_Update (Item);
      if Item.Pending then
         Invalidate (Item);
      end if;
   end Update;

   overriding function Until_Update (Item : Page_View) return Integer is
     (if Item.Pending or else Item.Search_Page /= 0 then Poll else -1);

   overriding procedure Hover_Changed (Item : in out Page_View; Hovered : Boolean) is
   begin
      Scrollbars.Set_Pane (Item.Down_Bar, Hovered);
      Scrollbars.Set_Pane (Item.Across_Bar, Hovered);
      Invalidate (Item);
   end Hover_Changed;

   procedure Handle_Bars
     (Item    : in out Page_View;
      Event   : Pomarine.Events.Event;
      Handled : out Boolean)
   is
      Moved, Changed, Other_Changed : Boolean;
      Other_Taken, Other_Moved : Boolean;
      To, Other_To : Float;
   begin
      Scrollbars.Handle
        (Item.Down_Bar, Event, Down_Metrics (Item), Handled, Moved, To, Changed);
      if Moved then
         Scroll_To (Item, Float'Min (1.0, Float'Max (0.0, To / Total_Of (Item))));
      end if;
      Scrollbars.Handle
        (Item.Across_Bar, Event, Across_Metrics (Item), Other_Taken,
         Other_Moved, Other_To, Other_Changed);
      if Other_Moved then
         Item.Across :=
           Float'Min (1.0, Float'Max (0.0, Other_To / (Wide_Of (Item) - Width_Of (Item))));
      end if;
      Handled := Handled or else Other_Taken;
      if Changed or else Moved or else Other_Changed or else Other_Moved then
         Invalidate (Item);
      end if;
   end Handle_Bars;

   overriding procedure Handle
     (Item    : in out Page_View;
      Event   : Pomarine.Events.Event;
      Handled : out Boolean) is
   begin
      Handled := False;
      if Event.Kind = Pomarine.Events.Key_Down and then Event.Command and then not Event.Option
        and then Event.Key = Pomarine.Events.Key_Z
      then
         Handle_Command (Item, (if Event.Shift then Edit_Redo else Edit_Undo), Handled);
         return;
      end if;
      if Count (Item) = 0 then
         return;
      end if;
      if Event.Kind in Pomarine.Events.Mouse_Down | Pomarine.Events.Mouse_Move | Pomarine.Events.Mouse_Up
      then
         Handle_Bars (Item, Event, Handled);
         if Handled then
            return;
         end if;
      end if;
      if Item.Chosen /= Pictures.Pointer then
         Handle_Marking (Item, Event, Handled);
         if Handled then
            return;
         end if;
      end if;
      case Event.Kind is
         when Pomarine.Events.Mouse_Down =>
            if Event.Button = 1
              and then Contains (Item, Event.Mouse_X * Density (Item), Event.Mouse_Y * Density (Item))
            then
               declare
                  X     : constant Float := Event.Mouse_X * Density (Item);
                  Y     : constant Float := Event.Mouse_Y * Density (Item);
                  Page  : constant Positive := Page_At (Item, Y);
                  Under : constant Natural := Word_At (Item, Page, X, Y, Nearest => False);
               begin
                  if Under = 0 then
                     Clear_Selection (Item);
                  elsif Event.Clicks >= 3 then
                     Select_Line (Item, Page, Under);
                     Handled := True;
                  elsif Event.Clicks = 2 then
                     Select_Range (Item, Page, Under, Under);
                     Item.Held := True;
                     Item.Drag_Words := True;
                     Handled := True;
                  else
                     Select_Range (Item, Page, Under, 0);
                     Item.Drag_Words := False;
                     Item.Held := True;
                     Handled := True;
                  end if;
               end;
            end if;
         when Pomarine.Events.Mouse_Move =>
            if Item.Held and then Item.Sel_Page > 0 then
               declare
                  Under : constant Natural :=
                    Word_At (Item, Item.Sel_Page, Event.Mouse_X * Density (Item),
                             Event.Mouse_Y * Density (Item), Nearest => True);
               begin
                  Select_Range
                    (Item, Item.Sel_Page, Item.Anchor,
                     (if Under = Item.Anchor and then not Item.Drag_Words then 0 else Under));
                  Handled := True;
               end;
            end if;
         when Pomarine.Events.Mouse_Up =>
            if Item.Held and then Event.Button = 1 then
               Item.Held := False;
               Handled := True;
            end if;
         when Pomarine.Events.Key_Down =>
            if Event.Command and then Event.Key = Pomarine.Events.Key_C and then Has_Selection (Item)
              and then Clipboard (Item) /= null
            then
               Clipboard (Item).Set_Text (Selected_Text (Item));
               Handled := True;
            elsif Event.Command and then Event.Key = Pomarine.Events.Key_A then
               Select_All (Item);
               Handled := True;
            end if;
         when Pomarine.Events.Mouse_Wheel =>
            if Item.Zoomed > 1.0 and then Event.Wheel_X /= 0.0 then
               Item.Across :=
                 Float'Min
                   (1.0,
                    Float'Max
                      (0.0,
                       Item.Across
                       - Event.Wheel_X * Points_Per_Notch * Density (Item)
                         / (Width_Of (Item) * (Item.Zoomed - 1.0))));
               Invalidate (Item);
            end if;
            Scroll_To
              (Item,
               Float'Min
                 (1.0,
                  Float'Max
                    (0.0,
                     Item.Down
                     - Event.Wheel_Y * Points_Per_Notch * Density (Item) / Total_Of (Item))));
            Handled := True;
         when others =>
            null;
      end case;
   end Handle;

   overriding procedure Describe
     (Item  : Page_View;
      Facts : in out Semantics.Description)
   is
      pragma Unreferenced (Item);
   begin
      if Facts.Kind = Semantics.Unknown then
         Facts.Kind := Semantics.Image;
      end if;
   end Describe;

end Pomarine.Widgets.Page_Views;
