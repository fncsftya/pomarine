with Pomarine.Marks;
with Pomarine.Page_Builds;
with Pomarine.Pages;
with Pomarine.Scrollbars;
with Pomarine.Semantics;
with Pomarine.Widgets.Pictures;
with SDL3.Cursors;
with SDL3.Events;
with SDL3.Painters;
with SDL3.Windows.Renderers.Textures;

--  The pages of a document, one under another, as wide as the box (times
--  the zoom), scrolled with the wheel (or a trackpad's two fingers), and by
--  Show_Page. Each page is drawn from what is drawn on it, not as pixels
--  (see Pomarine.Pages), so it is sharp at any zoom.
--
--  Only the pages in view are made, by the document's Source, when they
--  first come into view, one to a frame; a few are kept, and the least
--  lately in view is let go. Until a page is there it is drawn blank, of
--  the size it will be, so nothing moves when it arrives.
--
--  Words of a page's text can be selected, by dragging from one to another
--  (in the page the drag began in), a double click for a word, a triple for
--  a line, Command with A for all of the page in view and Command with C
--  to copy. With the highlighter (Set_Tool) a drag draws a freehand stroke on a page,
--  as on a Picture; marks are of a page and fractions of its size, and so
--  follow the zoom and can be kept elsewhere.
package Pomarine.Widgets.Page_Views is

   use type Pomarine.Pages.Size_Array_Access;
   use type Pomarine.Pages.Source_Access;
   use type Pictures.Tools;

   Points_Per_Notch : constant Float := 48.0;
   --  How far a notch of the wheel scrolls.

   Page_Gap : constant Float := 10.0;
   --  Points between pages.

   Cache_Size : constant := 8;
   --  How many pages are kept made.

   Max_Page_Images : constant := 64;
   --  Of the pictures on a page, the first are drawn.

   subtype Tools is Pictures.Tools;
   --  Pointer, Highlighter, Eraser: as of a Picture.

   Max_Marks : constant := Pomarine.Marks.Max_Marks;

   Mark_Height : constant Float := 0.024;
   --  How tall a mark is, as a fraction of the page's width.

   subtype Mark is Pomarine.Marks.Mark;
   subtype Mark_Array is Pomarine.Marks.Mark_Array;

   function Clamped_Mark (Left, Right, Y : Float; Page : Positive) return Mark;
   --  A mark kept from elsewhere, made fit the page.

   type Page_View is new Widget with private;

   procedure Set_Document
     (Item   : in out Page_View;
      Sizes  : Pomarine.Pages.Size_Array_Access;
      Source : Pomarine.Pages.Source_Access;
      Guess  : Boolean := False)
     with Pre => Sizes /= null and then Source /= null;
   --  Show the document, of Sizes'Length pages, those Source makes. Both
   --  must be there as long as it is shown. The first page is shown. The
   --  marks and selection are cleared. If Guess, Sizes are only a guess:
   --  Source is asked, in the background, how big the pages are, and they
   --  are changed (in Sizes, which is not to be used until it is
   --  cleared) when it has said.

   procedure Clear_Document (Item : in out Page_View)
     with Post => not Has_Document (Item);
   --  Show nothing, and give back the pages.

   function Has_Document (Item : Page_View) return Boolean;

   function Page_Count (Item : Page_View) return Natural;

   function Is_Settled (Item : Page_View) return Boolean;
   --  Whether it is laid out and where it was asked to be: not hidden, nor
   --  with a page to scroll to once it is laid out (Show_Page) waiting. What
   --  page is being read is only known if it is.

   function Current_Page (Item : Page_View) return Natural;
   --  The page the top of the view is in, or a little way down it, as the
   --  page being read; 0 if there is no document.

   procedure Show_Page (Item : in out Page_View; Page : Positive)
     with Pre => Has_Document (Item) and then Page <= Page_Count (Item);
   --  Scroll to the top of the page, or as near as the end allows.

   function Scrolled (Item : Page_View) return Float;
   --  How far down the document the top of the box is, from 0.0 to 1.0,
   --  of its height (as of the last draw).

   procedure Scroll_To (Item : in out Page_View; To : Float)
     with Pre => To in 0.0 .. 1.0;

   function Scrolled_Across (Item : Page_View) return Float;

   procedure Scroll_Across_To (Item : in out Page_View; To : Float)
     with Pre => To in 0.0 .. 1.0;

   procedure Set_Zoom (Item : in out Page_View; To : Float)
     with Pre => To > 0.0, Post => Zoom (Item) = To;
   --  Show the pages To times as wide as the box (1.0 to begin with).

   function Zoom (Item : Page_View) return Float;

   procedure Unload (Item : in out Page_View);
   --  Give back the pages made, and their pictures' memory: they are
   --  made again when drawn.

   --  Highlights

   function Tool (Item : Page_View) return Tools;

   procedure Set_Tool (Item : in out Page_View; To : Tools)
     with Post => Tool (Item) = To and then not Is_Marking (Item);

   function Is_Marking (Item : Page_View) return Boolean;

   function Mark_Count (Item : Page_View) return Natural;

   function Mark_At (Item : Page_View; Index : Positive) return Mark
     with Pre => Index <= Mark_Count (Item);

   function Marks_Version (Item : Page_View) return Natural;
   --  Changes on making, erasing, undoing or redoing marks; not by Set_Marks.

   function History_Of (Item : Page_View) return Pomarine.Marks.History;
   function Can_Undo (Item : Page_View) return Boolean;
   function Can_Redo (Item : Page_View) return Boolean;
   procedure Undo (Item : in out Page_View);
   procedure Redo (Item : in out Page_View);
   --  One stroke or erasure per step. Undo during a drag cancels the preview.

   procedure Set_Marks
     (Item : in out Page_View; To : Mark_Array;
      Past : Pomarine.Marks.History := Pomarine.Marks.Empty_History)
     with Pre => To'Length <= Max_Marks, Post => Mark_Count (Item) = To'Length;
   --  Past must belong to To; omit it to start with no history.

   procedure Clear_Marks (Item : in out Page_View)
     with Post => Mark_Count (Item) = 0;

   --  Text

   function Has_Words (Item : Page_View) return Boolean;
   --  Whether the page being read has words (it has been made).

   function Word_Count (Item : Page_View) return Natural;
   --  Of the page being read.

   function Has_Selection (Item : Page_View) return Boolean;

   function Selected_Text (Item : Page_View) return String;
   --  The selected words, a space between those of a line and a line break
   --  between lines; "" if none.

   procedure Select_All (Item : in out Page_View);
   --  All the words of the page being read.

   procedure Clear_Selection (Item : in out Page_View)
     with Post => not Has_Selection (Item);

   function Is_Over_Selection (Item : Page_View; X, Y : Float) return Boolean;
   --  Whether pixel X, Y is over a selected word.

   procedure Copy (Item : Page_View);
   --  Put the selected words on the tree's clipboard, if there are any.

   overriding procedure Draw
     (Item   : in out Page_View;
      Target : SDL3.Painters.Painter'Class;
      Colors : Themes.Theme);

   overriding procedure Update
     (Item : in out Page_View; Now : SDL3.Events.Milliseconds);

   overriding function Until_Update (Item : Page_View) return Integer;

   overriding procedure Handle_Command
     (Item : in out Page_View; Tag : Integer; Done : out Boolean);

   overriding procedure Handle
     (Item    : in out Page_View;
      Event   : SDL3.Events.Event;
      Handled : out Boolean);

   overriding function Cursor (Item : Page_View) return SDL3.Cursors.Kind;

   overriding function Accepts_Focus (Item : Page_View) return Boolean;

   overriding procedure Hover_Changed
     (Item : in out Page_View; Hovered : Boolean);

   overriding procedure Focus_Changed
     (Item : in out Page_View; Focused : Boolean);

   overriding procedure Describe
     (Item  : Page_View;
      Facts : in out Semantics.Description);

private

   subtype Result_Access is Pomarine.Page_Builds.Result_Access;

   type Float_Array is array (Positive range <>) of Float;

   type Float_Array_Access is access Float_Array;

   type Image_Textures is
     array (1 .. Max_Page_Images) of SDL3.Windows.Renderers.Textures.Texture;

   type Slot is limited record
      Index   : Natural := 0;
      --  Which page, 0 if none.
      Job     : Natural := 0;
      --  The ticket (see Pomarine.Page_Builds) of the page being made in
      --  the background, 0 if none; its Content is null until it is.
      Content : Pomarine.Pages.Page_Access;
      --  Null if it could not be made.
      Found   : Result_Access;
      Images  : Image_Textures;
      Stamp   : Natural := 0;
      --  When it was last in view.
   end record;

   type Slot_Array is array (1 .. Cache_Size) of Slot;

   type Page_View is new Widget with record
      Sizes   : Pomarine.Pages.Size_Array_Access;
      Source  : Pomarine.Pages.Source_Access;
      Ratios  : Float_Array_Access;
      --  Ratios (I) is the height, of the width, of the pages before page I,
      --  one more than there are pages.
      Cached  : Slot_Array;
      Clock   : Natural := 0;
      Measuring : Natural := 0;
      --  The ticket (see Pomarine.Page_Builds) of the sizes of the pages
      --  being asked for in the background, 0 if none.
      Pending : Boolean := False;
      --  Pages in view are still to be made.
      Down    : Float := 0.0;
      --  How far down the document, as a fraction of its height.
      Wanted  : Natural := 0;
      --  A page to scroll to when it is known how big they are, as at the
      --  first draw: 0 if none.
      Across  : Float := 0.0;
      Zoomed  : Float := 1.0;
      Sel_Page : Natural := 0;
      Anchor  : Natural := 0;
      Head    : Natural := 0;
      Held    : Boolean := False;
      Chosen  : Tools := Pictures.Pointer;
      Marked  : Mark_Array (1 .. Max_Marks + 1);
      Marks   : Natural range 0 .. Max_Marks := 0;
      Version : Natural := 0;
      Past : Pomarine.Marks.History;
      Marking : Boolean := False;
      Started : Float := 0.0;
      Down_Bar   : Scrollbars.Bar;
      Across_Bar : Scrollbars.Bar;
   end record;

end Pomarine.Widgets.Page_Views;
