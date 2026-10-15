with Interfaces;
with Pomarine.Words;

--  A page of a document as what is drawn on it, not as pixels: shapes,
--  text and pictures in the order they are drawn, in points from the page's
--  top left, that a Picture widget draws at whatever size it is shown, so
--  that it stays sharp when zoomed. Whatever reads a document (the ebook
--  crate, with PDFium) makes one and the widget is given it.
--
--  Everything is in arrays of records of the C layout, so that what makes
--  a page can write them directly. A page is made once and not changed.
package Pomarine.Pages is

   type RGBA is record
      Red, Green, Blue, Alpha : Interfaces.Unsigned_8;
   end record
     with Convention => C;

   type Point is record
      X, Y : Float;
   end record
     with Convention => C;

   type Point_Array is array (Positive range <>) of Point
     with Convention => C;

   type Rect is record
      Left, Top, Right, Bottom : Float;
   end record
     with Convention => C;

   type Rect_Array is array (Positive range <>) of Rect
     with Convention => C;

   type Kinds is (Fill, Stroke, Text, Picture)
     with Convention => C;
   --  What an operation draws:
   --    Fill    Count triangles from Points (First), in the colour;
   --    Stroke  Count lines, each two Points from First, Width wide;
   --    Text    Count characters from Chars (First), in font Face;
   --    Picture Image First, in Box.

   type Operation is record
      Kind  : Kinds;
      Clip  : Natural;
      --  Which of Clips draws only within it, 0 if none.
      First : Natural;
      Count : Natural;
      Color : RGBA;
      Width : Float;
      Face  : Natural;
      Box   : Rect;
      --  Where it is drawn (all of it), to leave it out when it is not in
      --  view.
   end record
     with Convention => C;

   type Operation_Array is array (Positive range <>) of Operation
     with Convention => C;

   type Character_Mark is record
      Code : Interfaces.Unsigned_32;
      --  The Unicode character.
      X, Y : Float;
      --  Where its baseline starts.
      Size : Float;
      --  The font's size, in points.
   end record
     with Convention => C;

   type Character_Array is array (Positive range <>) of Character_Mark
     with Convention => C;

   Max_Faces : constant := 64;

   Face_Length : constant := 64;

   type Face_Name is record
      Name : String (1 .. Face_Length) := [others => ' '];
      Last : Natural := 0;
   end record
     with Convention => C;
   --  A CoreText font name, Name (1 .. Last).

   type Face_Array is array (Positive range <>) of Face_Name
     with Convention => C;

   type Image is record
      Width, Height : Natural;
      First         : Natural;
      --  Where its pixels are in Pixels: rows of Width, each pixel the
      --  bytes R, G, B, A with the colour multiplied by the alpha.
   end record
     with Convention => C;

   type Image_Array is array (Positive range <>) of Image
     with Convention => C;

   type Byte_Array is array (Positive range <>) of Interfaces.Unsigned_8;

   type Page
     (Operations, Points, Characters, Faces, Clips, Images, Bytes : Natural)
   is record
      Width, Height : Float := 0.0;
      --  In points.
      Op      : Operation_Array (1 .. Operations);
      Corner  : Point_Array (1 .. Points);
      Letters : Character_Array (1 .. Characters);
      Fonts   : Face_Array (1 .. Faces);
      Clip    : Rect_Array (1 .. Clips);
      Pictures : Image_Array (1 .. Images);
      Pixels  : Byte_Array (1 .. Bytes);
   end record;

   type Page_Access is access Page;

   procedure Free (Item : in out Page_Access)
     with Post => Item = null;

   function Image_Count (Item : Page) return Natural is (Item.Images);

   --  A document of many pages: how big each is, and what makes them when
   --  they are wanted (a page view asks only for those it shows).

   type Size is record
      Width, Height : Float;
   end record
     with Convention => C;
   --  Of a page, in points.

   type Size_Array is array (Positive range <>) of Size
     with Convention => C;

   type Size_Array_Access is access Size_Array;

   procedure Free (Item : in out Size_Array_Access)
     with Post => Item = null;

   type Source is limited interface;

   procedure Build
     (Item    : in out Source;
      Index   : Positive;
      Content : out Page_Access;
      Found   : in out Pomarine.Words.Result;
      Ok      : out Boolean) is abstract;
   --  Make the page Index of the document, and the words of its text. A
   --  page that cannot be made is not Ok, and Content is null.

   procedure Measure
     (Item  : in out Source;
      Count : Positive;
      Sizes : out Size_Array_Access;
      Ok    : out Boolean) is abstract;
   --  How big each of the first Count pages is: Sizes'Length = Count when
   --  Ok, else null. It may take a while (it opens the document), so is
   --  asked for in the background (see Pomarine.Page_Builds).

   type Source_Access is access all Source'Class;

end Pomarine.Pages;
