with Texts.Documents;
with Typeset.Layouts;

--  Where a text area's text is, in pixels and in layout units, and
--  counts of the document it shows.
private package Pomarine.Text_Areas.Geometry is

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
              (Item.Height - Typeset.Layouts.Line_Height (Item.Laid) * Scale (Item))
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
     (Typeset.Layouts.Top (Item.Laid, Item.Anchor) + Item.Offset);
   --  Of what is shown, down the text, in layout units.

   function Para_End (Item : Text_Area; Para : Positive)
      return Position is
     (Texts.Documents.Paragraph_End (Item.Doc.all, Para));

   function Last_Position (Item : Text_Area) return Position is
     (Texts.Documents.Text_End (Item.Doc.all));

   function Byte_Length (Item : Text_Area; Para : Positive) return Natural is
     (Texts.Documents.Byte_Length (Item.Doc.all, Para));

   function Count (Item : Text_Area) return Positive is
     (Texts.Documents.Count (Item.Doc.all));

   function Units (Item : Text_Area; At_Point : Position) return Natural is
     (Texts.Documents.Units_Before (Item.Doc.all, At_Point.Paragraph, At_Point.Index));
   --  Where At_Point is in its paragraph's lines.

   function Composed_End (Item : Text_Area) return Position is
     ((Item.Composed.Paragraph,
       Item.Composed.Index + Item.Composed_Length));

end Pomarine.Text_Areas.Geometry;
