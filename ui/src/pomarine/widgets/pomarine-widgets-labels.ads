with Yoga.Nodes;
with Pomarine.Semantics;
with SDL3.Painters;
with Pomarine_Ui_Config;
with Pomarine.Icons;

--  A line of text to read, on the left of its box, in the middle of its
--  height. It takes no events.
package Pomarine.Widgets.Labels is

   Text_Capacity : constant := Pomarine_Ui_Config.Label_Capacity;
   --  Characters.

   type Label is new Widget with private;

   procedure Set_Text (Item : in out Label; Value : String)
     with Pre => Value'Length <= Text_Capacity;
   --  Show Value, in the debug font of SDL3.Windows.Renderers, scaled to
   --  the density; in the system font, cut short, with an ellipsis, if it
   --  is wider than the box.

   function Fitted (Value : String) return String
     with Post => Fitted'Result'Length <= Text_Capacity;
   --  As much of Value as a label takes.

   function Text (Item : Label) return String;

   procedure Set_Style (Item : in out Label; To : Line_Texts.Style);
   --  Show it as a heading, or as regular text, which it is to begin with.
   --  Only in the system font: the debug font has the one size.

   function Style (Item : Label) return Line_Texts.Style;

   procedure Set_Scale (Item : in out Label; To : Float)
     with Pre => To > 0.0;
   --  Show the text at To times its size (1.0 to begin with), in the
   --  system font: as a title is smaller over a canvas zoomed out.

   procedure Set_Centered (Item : in out Label; To : Boolean);
   --  Put the text in the middle of its box across, rather than at the
   --  left (in the system font).

   procedure Set_Trailing (Item : in out Label; To : Boolean);
   --  Put the text at the right of its box, rather than at the left (in
   --  the system font), as a count at the end of a row.

   procedure Set_Icon (Item : in out Label; To : Pomarine.Icons.Icon);
   --  Show the icon before the text, in its ink, if the tree has icons.

   procedure Set_Intrinsic (Item : in out Label; To : Boolean := True);
   --  Let the layout size it to its text (and its icon) where its style
   --  does not: as wide as the text is, and as high as a line. Not so to
   --  begin with, when it is as its style makes it.

   procedure Set_Ink (Item : in out Label; To : Themes.Slot);
   --  Show it in To, rather than the theme's foreground: as on a dark
   --  bar.

   overriding procedure Draw
     (Item   : in out Label;
      Target : SDL3.Painters.Painter'Class;
      Colors : Themes.Theme);

   overriding procedure Measure
     (Item      : in out Label;
      Room_Wide : Float;
      Wide_Mode : Yoga.Nodes.Measure_Mode;
      Room_High : Float;
      High_Mode : Yoga.Nodes.Measure_Mode;
      Result    : out Yoga.Nodes.Measured_Size);

   overriding procedure Describe
     (Item  : Label;
      Facts : in out Semantics.Description);

private

   type Label is new Widget with record
      Content : String (1 .. Text_Capacity) := [others => ' '];
      Length  : Natural range 0 .. Text_Capacity := 0;
      Using   : Line_Texts.Style := Line_Texts.Regular;
      Inked   : Boolean := False;
      Centered : Boolean := False;
      Trailing : Boolean := False;
      Ink     : Themes.Slot := Themes.Foreground;
      Scaled  : Float := 1.0;
      Iconed  : Boolean := False;
      Which   : Pomarine.Icons.Icon := Pomarine.Icons.Icon'First;
      Fit_Width  : Float := -1.0;
      Fit_Length : Natural range 0 .. Text_Capacity := 0;
      Fit_Cut    : Boolean := False;
      Measure_Valid : Boolean := False;
      Measure_Wide, Measure_High : Float := 0.0;
      Measure_Pixels : Float := 0.0;
      --  What it measured as, for the density it was: kept until the text,
      --  its style, its scale, its icon or the density change.
      --  How much of the text fits a box Fit_Width pixels wide, and whether
      --  that is not all of it: worked out when drawn, and kept until the
      --  text, its style or its scale change (negative: not yet).
   end record;

end Pomarine.Widgets.Labels;
