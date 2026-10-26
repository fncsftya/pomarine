with Pomarine.Widgets.Nodes;
package body Pomarine.Widgets.Drawing is

   package Renderers renames SDL3.Windows.Renderers;

   use Pomarine.Widgets.Nodes;

   procedure Damage_Box (Item : in out Widget'Class; Part : Pixel_Box) is
   begin
      Item.Owner.Damaged := Union (Item.Owner.Damaged, Part);
   end Damage_Box;

   procedure Damage_Widget (Item : in out Widget'Class) is
   begin
      Item.Owner.Nodes.Paint_Dirty (Item.Slot) := True;
      Item.Owner.Nodes.Semantics_Dirty (Item.Slot) := True;
      --  A widget that has not been placed is damaged when it is.
      if Item.Owner.Nodes.Spot (Item.Slot).Placed then
         Damage_Box (Item, Box_Of (Item));
      end if;
   end Damage_Widget;

   procedure Damage_Widget (Item : in out Widget'Class; Part : Pixel_Box) is
   begin
      --  A part of it only, as a caret: not what it is to an assistive
      --  technology.
      Item.Owner.Nodes.Paint_Dirty (Item.Slot) := True;
      if Item.Owner.Nodes.Spot (Item.Slot).Placed then
         Damage_Box (Item, Intersection (Part, Box_Of (Item)));
      end if;
   end Damage_Widget;

   procedure Place_At
     (Item         : in out Widget'Class;
      Left, Top    : Float;
      Was_Left, Was_Top : in out Float;
      Changed      : in out Boolean) is
   begin
      if Left /= Was_Left or else Top /= Was_Top then
         Was_Left := Left;
         Was_Top := Top;
         Yoga.Nodes.Set_Position (Node (Item), Yoga.Left, Left);
         Yoga.Nodes.Set_Position (Node (Item), Yoga.Top, Top);
         Request_Layout (Item);
         Changed := True;
      end if;
   end Place_At;

   procedure Place
     (Item    : in out Tree;
      Placing : Node_Index;
      Across, Down : Float;
      Parent_Moved : Boolean)
   is
      pragma Unreferenced (Parent_Moved);
      Table    : Node_Table renames Item.Nodes.all;
      Own_Left : constant Float :=
        Across + Yoga.Nodes.Left (Table.Yoga_Node (Placing));
      Own_Top  : constant Float :=
        Down + Yoga.Nodes.Top (Table.Yoga_Node (Placing));
      Wide     : constant Float := Yoga.Nodes.Width (Table.Yoga_Node (Placing));
      High     : constant Float := Yoga.Nodes.Height (Table.Yoga_Node (Placing));
      Child    : Node_Index := Table.First (Placing);
      Moved    : Boolean;
   begin
      Yoga.Nodes.Clear_New_Layout (Table.Yoga_Node (Placing));
      Table.Layout_Dirty (Placing) := False;
      Moved := Item.Replace_All or else not Table.Spot (Placing).Placed
        or else Own_Left /= Table.Spot (Placing).Left
        or else Own_Top /= Table.Spot (Placing).Top;
      if Moved
        or else Wide /= Table.Spot (Placing).Wide
        or else High /= Table.Spot (Placing).High
      then
         if Table.Spot (Placing).Placed then
            Item.Damaged := Union (Item.Damaged, Box_Of (Item, Placing));
         end if;
         Table.Spot (Placing).Placed := True;
         Table.Spot (Placing).Left := Own_Left;
         Table.Spot (Placing).Top := Own_Top;
         Table.Spot (Placing).Wide := Wide;
         Table.Spot (Placing).High := High;
         Table.Semantics_Dirty (Placing) := True;
         --  Its place is part of what an assistive technology is told.
         Item.Damaged := Union (Item.Damaged, Box_Of (Item, Placing));
         Placed (Table.Object (Placing).all, Own_Left, Own_Top, Wide, High);
      end if;
      while Child /= 0 loop
         --  What the layout has not touched, and has not moved with its
         --  parent, is where it was.
         if Moved or else Yoga.Nodes.Has_New_Layout (Table.Yoga_Node (Child)) then
            Place (Item, Child, Own_Left, Own_Top, Moved);
         end if;
         Child := Table.Next (Child);
      end loop;
   end Place;

   procedure Lay_Out
     (Item   : in out Tree;
      Target : SDL3.Painters.Painter'Class)
   is
      Pixels_Wide, Pixels_High : Natural;
   begin
      SDL3.Painters.Output_Size (Target, Pixels_Wide, Pixels_High);
      Yoga.Nodes.Calculate_Layout
        (Item.Yoga_Tree, Float (Pixels_Wide), Float (Pixels_High));
      Place (Item, Item.Root, 0.0, 0.0, False);
      Item.Replace_All := False;
      Item.Layout_Pending := False;
   end Lay_Out;

   procedure Paint_Widget
     (Home     : in out Tree;
      Painting : Node_Index;
      Target   : SDL3.Painters.Painter'Class;
      Colors   : Themes.Theme;
      Region   : Pixel_Box)
   is
      Table : Node_Table renames Home.Nodes.all;
      Box   : constant Pixel_Box := Intersection (Box_Of (Home, Painting), Region);
   begin
      if Is_Empty (Box) or else not Table.Spot (Painting).Visible then
         return;
      end if;
      declare
         Outer  : constant Renderers.Clip := SDL3.Painters.Current_Clip (Target);
         Child  : Node_Index := Table.First (Painting);
         Drawer : constant Widget_Access := Table.Object (Painting);
      begin
         SDL3.Painters.Narrow_Clip
           (Target, Box.Left, Box.Top, Box.Width, Box.Height);
         Table.Paint_Box (Painting) := Box;
         Draw (Drawer.all, Target, Colors);
         Table.Paint_Dirty (Painting) := False;
         while Child /= 0 loop
            Paint_Widget (Home, Child, Target, Colors, Box);
            Child := Table.Next (Child);
         end loop;
         Table.Paint_Box (Painting) := Box;
         Draw_Over (Drawer.all, Target, Colors);
         SDL3.Painters.Restore_Clip (Target, Outer);
      end;
   end Paint_Widget;

   procedure Paint_All
     (Item     : in out Tree;
      Target   : SDL3.Painters.Painter'Class;
      Colors   : Themes.Theme;
      Retained : Boolean := False)
   is
      Pixels_Wide, Pixels_High : Natural;
   begin
      SDL3.Painters.Output_Size (Target, Pixels_Wide, Pixels_High);
      Layout (Item, Target);
      declare
         Everything : constant Pixel_Box := (0, 0, Pixels_Wide, Pixels_High);
         Whole      : constant Boolean :=
           not Retained or else Item.Lost
           or else Pixels_Wide /= Item.Painted_Width
           or else Pixels_High /= Item.Painted_Height;
         Region     : constant Pixel_Box :=
           (if Whole then Everything
            else Intersection (Item.Damaged, Everything));
         Outer      : constant Renderers.Clip :=
           SDL3.Painters.Current_Clip (Target);
      begin
         if not Is_Empty (Region) then
            SDL3.Painters.Narrow_Clip
              (Target, Region.Left, Region.Top, Region.Width, Region.Height);
            if Whole then
               SDL3.Painters.Clear (Target, Colors (Themes.Background));
            else
               SDL3.Painters.Fill_Rect
                 (Target, Colors (Themes.Background),
                  Float (Region.Left), Float (Region.Top),
                  Float (Region.Width), Float (Region.Height));
            end if;
            Paint_Widget (Item, Item.Root, Target, Colors, Region);
            SDL3.Painters.Restore_Clip (Target, Outer);
         end if;
      end;
      Item.Damaged := (others => 0);
      Item.Lost := False;
      Item.Painted_Width := Pixels_Wide;
      Item.Painted_Height := Pixels_High;
   end Paint_All;

end Pomarine.Widgets.Drawing;
