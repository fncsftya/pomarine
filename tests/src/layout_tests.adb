with Ada.Strings.Fixed;
with SDL3.Windows.Renderers;
with Goldens;
with Pomarine.Widgets.Labels;
with Pomarine.Widgets.Panels;
with Yoga.Nodes;

package body Layout_Tests is

   package Widgets renames Pomarine.Widgets;
   package Labels renames Pomarine.Widgets.Labels;
   package Panels renames Pomarine.Widgets.Panels;
   package Renderers renames SDL3.Windows.Renderers;
   package Nodes renames Yoga.Nodes;

   function Image (Value : Integer) return String is
     (Ada.Strings.Fixed.Trim (Integer'Image (Value), Ada.Strings.Left));

   --  A panel that counts how often it is placed

   type Counted is new Panels.Panel with record
      Placings : Natural := 0;
   end record;

   overriding procedure Placed
     (Item : in out Counted; Left, Top, Width, Height : Float) is
      pragma Unreferenced (Left, Top, Width, Height);
   begin
      Item.Placings := Item.Placings + 1;
   end Placed;

   procedure Intrinsic_Labels is
      Tree   : Widgets.Tree;
      Target : Renderers.Renderer;
      Root   : aliased Panels.Panel;
      Short  : aliased Labels.Label;
      Fixed  : aliased Labels.Label;
   begin
      Renderers.Create_Offscreen (Target, 400, 100);
      Widgets.Set_Root (Tree, Root);
      Widgets.Add (Root, Short, Fixed);
      Nodes.Set_Flex_Direction (Widgets.Node (Root), Yoga.Row);
      Nodes.Set_Align_Items (Widgets.Node (Root), Yoga.Flex_Start);
      Labels.Set_Text (Short, "Hello");
      Labels.Set_Text (Fixed, "Hello");
      Labels.Set_Intrinsic (Short);

      --  Without text lines, the debug font: 8 pixels to a character.
      Widgets.Layout (Tree, Target);
      Goldens.Check_Text ("layout-intrinsic", "40 8",
                          Image (Integer (Widgets.Width_Of (Short))) & " "
                          & Image (Integer (Widgets.Height_Of (Short))));
      Goldens.Check_Text ("layout-not-intrinsic", "0", Image (Integer (Widgets.Width_Of (Fixed))));

      --  A longer text is a wider label, and the one after it moves along.
      Labels.Set_Text (Short, "Hello, world");
      Widgets.Layout (Tree, Target);
      Goldens.Check_Text ("layout-intrinsic-grows", "96", Image (Integer (Widgets.Width_Of (Short))));

      --  Said before it was in a tree, it still is.
      Widgets.Remove (Short);
      Labels.Set_Text (Short, "Hi");
      Widgets.Add (Root, Short);
      Widgets.Layout (Tree, Target);
      Goldens.Check_Text ("layout-intrinsic-readded", "16", Image (Integer (Widgets.Width_Of (Short))));

      --  An explicit width is the style's, not the text's.
      Nodes.Set_Width (Widgets.Node (Short), 200.0);
      Widgets.Request_Layout (Short);
      Widgets.Layout (Tree, Target);
      Goldens.Check_Text ("layout-intrinsic-style-wins", "200", Image (Integer (Widgets.Width_Of (Short))));
   end Intrinsic_Labels;

   procedure Only_What_Changed is
      Tree   : Widgets.Tree;
      Target : Renderers.Renderer;
      Root   : aliased Counted;
      Rows   : array (1 .. 5) of aliased Counted;
      Inside : aliased Counted;
   begin
      Renderers.Create_Offscreen (Target, 200, 200);
      Widgets.Set_Root (Tree, Root);
      Nodes.Set_Flex_Direction (Widgets.Node (Root), Yoga.Column);
      for Row of Rows loop
         Widgets.Add (Root, Row);
         Nodes.Set_Height (Widgets.Node (Row), 20.0);
      end loop;
      Widgets.Add (Rows (5), Inside);
      Nodes.Set_Height (Widgets.Node (Inside), 10.0);
      Widgets.Layout (Tree, Target);

      declare
         Total : Natural := Root.Placings + Inside.Placings;
      begin
         for Row of Rows loop
            Total := Total + Row.Placings;
         end loop;
         Goldens.Check_Text ("layout-first", "7", Image (Total));
      end;

      --  Nothing changed, nothing is placed.
      Widgets.Layout (Tree, Target);
      Goldens.Check_Text ("layout-quiet", "1", Image (Rows (3).Placings));

      --  The third grows by a little: it and those below it that moved are
      --  placed again, and the rows above it are not.
      Nodes.Set_Height (Widgets.Node (Rows (3)), 30.0);
      Widgets.Request_Layout (Rows (3));
      Widgets.Layout (Tree, Target);
      Goldens.Check_Text
        ("layout-changed", "1 1 2 2 2 2",
         Image (Rows (1).Placings) & " " & Image (Rows (2).Placings) & " " & Image (Rows (3).Placings) & " "
         & Image (Rows (4).Placings) & " " & Image (Rows (5).Placings) & " " & Image (Inside.Placings));
   end Only_What_Changed;

end Layout_Tests;
