--  Damage, layout and painting: which part of the target is out of date, where the layout puts each widget, and drawing
--  the widgets in it, parents before children.
--  A private child of Pomarine.Widgets: its operations are the parts of that package's body that are not
--  its own interface, and are called from it.
private package Pomarine.Widgets.Drawing is

   procedure Damage_Box (Item : in out Widget'Class; Part : Pixel_Box);

   procedure Damage_Widget (Item : in out Widget'Class);

   procedure Damage_Widget (Item : in out Widget'Class; Part : Pixel_Box);

   procedure Place_At
     (Item         : in out Widget'Class;
      Left, Top    : Float;
      Was_Left, Was_Top : in out Float;
      Changed      : in out Boolean);

   procedure Place
     (Item    : in out Tree;
      Placing : Node_Index;
      Across, Down : Float;
      Parent_Moved : Boolean);

   procedure Lay_Out
     (Item   : in out Tree;
      Target : SDL3.Painters.Painter'Class);

   procedure Paint_Widget
     (Home     : in out Tree;
      Painting : Node_Index;
      Target   : SDL3.Painters.Painter'Class;
      Colors   : Themes.Theme;
      Region   : Pixel_Box);

   procedure Paint_All
     (Item     : in out Tree;
      Target   : SDL3.Painters.Painter'Class;
      Colors   : Themes.Theme;
      Retained : Boolean := False);

end Pomarine.Widgets.Drawing;
