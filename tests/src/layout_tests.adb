with Ada.Strings.Fixed;
with SDL3.Windows.Renderers;
with Goldens;
with Pomarine.Icons;
with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Labels;
with Pomarine.Widgets.Layouts;
with Pomarine.Widgets.Panels;
with Yoga.Nodes;

package body Layout_Tests is

   package Widgets renames Pomarine.Widgets;
   package Buttons renames Pomarine.Widgets.Buttons;
   package Layouts renames Pomarine.Widgets.Layouts;
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

   procedure Declarative_Building is
      use type Buttons.Kind;
      use type Buttons.Shape_Kind;
      Tree   : Widgets.Tree;
      Target : Renderers.Renderer;
      Root   : aliased Panels.Panel;
      Title  : aliased Labels.Label;
      Save   : aliased Buttons.Button;
      Menu   : aliased Buttons.Button;
   begin
      Renderers.Create_Offscreen (Target, 400, 100);
      Widgets.Set_Root (Tree, Root);
      Layouts.Set_Layout (Root, (Flow => Layouts.Row, Align => Layouts.Start, others => <>));
      Layouts.Add (Root, Title, (Width => 50.0, Height => 10.0, others => <>));
      Buttons.Add
        (Root, Save, Buttons.Looks ("Save", Buttons.Primary, Focusable => True),
         (Width => 60.0, Height => 20.0, others => <>));
      Buttons.Add (Root, Menu, Buttons.Looks ("More", Shape => Buttons.Split_Dropdown));
      Widgets.Layout (Tree, Target);

      Goldens.Check_Text ("layouts-add", "50 10", Image (Integer (Widgets.Width_Of (Title))) & " "
                          & Image (Integer (Widgets.Height_Of (Title))));
      Goldens.Check_Text ("layouts-add-button", "60 20 Save", Image (Integer (Widgets.Width_Of (Save))) & " "
                          & Image (Integer (Widgets.Height_Of (Save))) & " " & Buttons.Label (Save));
      Goldens.Check_Text
        ("buttons-looks", "TRUE TRUE TRUE",
         Boolean'Image (Buttons.Kind_Of (Save) = Buttons.Primary and then Buttons.Shape_Of (Save) = Buttons.Plain)
         & " " & Boolean'Image (Buttons.Is_Dropdown (Menu)) & " "
         & Boolean'Image (Buttons.Shape_Of (Menu) = Buttons.Split_Dropdown));

      --  Configure says all of it: what is not named goes back; the state stays.
      Buttons.Set_Selected (Save, True);
      Buttons.Configure
        (Save, Buttons.Looks ("Edit", Icon => Pomarine.Icons.Shown (Pomarine.Icons.Check), Captioned => True));
      Goldens.Check_Text
        ("buttons-configure", "Edit NORMAL TRUE TRUE FALSE",
         Buttons.Label (Save) & " " & Buttons.Kind'Image (Buttons.Kind_Of (Save)) & " "
         & Boolean'Image (Buttons.Has_Icon (Save)) & " " & Boolean'Image (Buttons.Is_Selected (Save)) & " "
         & Boolean'Image (Buttons.Is_Dropdown (Save)));
      Buttons.Configure (Save, Buttons.Looks ("Edit"));
      Goldens.Check_Text ("buttons-configure-no-icon", "FALSE", Boolean'Image (Buttons.Has_Icon (Save)));

      --  Added before another, and styled, it is first and has its size.
      declare
         First : aliased Panels.Panel;
      begin
         Layouts.Add_Before (Root, First, Title, (Width => 7.0, Height => 9.0, others => <>));
         Widgets.Layout (Tree, Target);
         Goldens.Check_Text
           ("layouts-add-before", "7 9 0",
            Image (Integer (Widgets.Width_Of (First))) & " " & Image (Integer (Widgets.Height_Of (First))) & " "
            & Image (Integer (Widgets.Left_Of (First))));
         Widgets.Remove (First);
      end;

      --  A dropdown made plain is plain, a split one too.
      Buttons.Set_Dropdown (Menu, False);
      Goldens.Check_Text ("buttons-dropdown-off", "PLAIN", Buttons.Shape_Kind'Image (Buttons.Shape_Of (Menu)));
   end Declarative_Building;

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
