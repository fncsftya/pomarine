with Pomarine.Boxes;
with Pomarine.Searches;
with Pomarine.Text_Areas.Core;
with Pomarine.Text_Areas.Finding;
with Pomarine.Text_Areas.Geometry;
with SDL3.Windows;
with SDL3.Windows.Renderers;
with CoreText.Wrapping;
with Texts.Documents;
with Typeset.Layouts;
with Typeset.Views;
package body Pomarine.Text_Areas.Drawing is

   package Docs renames Texts.Documents;
   package Layouts renames Typeset.Layouts;
   package Views renames Typeset.Views;

   use Core;
   use Finding;
   use Geometry;
   use type Docs.Version;
   use type Texts.Position;

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

   procedure Render
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

      for Index in 1 .. Natural (Item.Found.Matches.Length) loop
         declare
            M : constant Pomarine.Searches.Match := Item.Found.Matches (Index);
         begin
            Draw_Range
              (Item, Target, Search_Position (Item, M.First), Search_Position (Item, M.Last + 1), First, Last,
               (if Index = Item.Found.Current then Themes.Color'(40, 120, 255, 130)
                else Themes.Color'(60, 170, 255, 65)), False, Rows_From, Rows_To, Marking => True);
            Draw_Range
              (Item, Target, Search_Position (Item, M.First), Search_Position (Item, M.Last + 1), First, Last,
               Themes.Color'(30, 110, 240, 230), True, Rows_From, Rows_To, Marking => True);
         end;
      end loop;

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
            elsif R.Style = Docs.Linked then
               Draw_Range (Item, Target, R.From, R.To, First, Last, Colors (Themes.Accent), True,
                           Rows_From, Rows_To);
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
   end Render;

end Pomarine.Text_Areas.Drawing;
