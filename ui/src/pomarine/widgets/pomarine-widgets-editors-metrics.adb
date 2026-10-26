with Yoga.Nodes;
package body Pomarine.Widgets.Editors.Metrics is

   function Family_Shown (Item : Editor) return String is
     (if Text_Areas.Family_Here (Item.Text) /= "" then Text_Areas.Family_Here (Item.Text) else Font_Family (Item));

   function Size_Shown (Item : Editor) return Float is
     (if Text_Areas.Size_Here (Item.Text) > 0 then Float (Text_Areas.Size_Here (Item.Text)) else Item.Points);

   function Window_Height (Item : Widget'Class) return Float is
      Above : Widget_Access := Parent_Of (Item);
      Last  : Float := Height_Of (Item);
   begin
      while Above /= null loop
         Last := Height_Of (Above.all);
         Above := Parent_Of (Above.all);
      end loop;
      return Last;
   end Window_Height;

   procedure Shape_Bubble (Item : in out Editor; Bubble : in out Panels.Panel; Wide : Float) is
      Pixels : constant Float := Density (Item);
   begin
      Panels.Set_Fill (Bubble, Themes.Page);
      Panels.Set_Border (Bubble, Themes.Border);
      Panels.Set_Radius (Bubble, 6.0);
      Add (Item, Bubble);
      Yoga.Nodes.Set_Position_Type (Node (Bubble), Yoga.Absolute);
      Yoga.Nodes.Set_Width (Node (Bubble), Wide * Pixels);
      Yoga.Nodes.Set_Height (Node (Bubble), Bubble_High * Pixels);
      Set_Visible (Bubble, False);
   end Shape_Bubble;

   procedure Put_Button
     (Item : in out Editor; Bubble : in out Panels.Panel; Part : in out Buttons.Button;
      Left, Wide : Float; Label, Name : String)
   is
      Pixels : constant Float := Density (Item);
   begin
      Buttons.Set_Label (Part, Label);
      Set_Accessible_Name (Part, Name);
      Buttons.Set_Enabled (Part, True);
      Set_Listener (Part, Item'Unchecked_Access);
      Add (Bubble, Part);
      Yoga.Nodes.Set_Position_Type (Node (Part), Yoga.Absolute);
      Yoga.Nodes.Set_Position (Node (Part), Yoga.Left, Left * Pixels);
      Yoga.Nodes.Set_Position (Node (Part), Yoga.Top, (Bubble_High - Button_High) / 2.0 * Pixels);
      Yoga.Nodes.Set_Width (Node (Part), Wide * Pixels);
      Yoga.Nodes.Set_Height (Node (Part), Button_High * Pixels);
   end Put_Button;

   procedure Place_Bubble
     (Item : in out Editor; Bubble : in out Panels.Panel; Wide : Float; X, Top, Bottom : Float;
      Left_Kept, Top_Kept : in out Integer; High : Float := Bubble_High)
   is
      --  Under the caret, or over it if there is no room under it in the window.
      Pixels : constant Float := Density (Item);
      Edge   : constant Float := 4.0 * Pixels;
      Left   : constant Float :=
        Float'Max (Edge, Float'Min (X - Left_Of (Item), Width_Of (Item) - Wide * Pixels - Edge));
      Below  : constant Float := Bottom + Bubble_Gap * Pixels;
      Upper  : constant Boolean := Below + High * Pixels > Window_Height (Item);
      Put_Top : constant Float :=
        (if Upper then Top - Bubble_Gap * Pixels - High * Pixels else Below) - Top_Of (Item);
   begin
      if Integer (Left) /= Left_Kept or else Integer (Put_Top) /= Top_Kept then
         Left_Kept := Integer (Left);
         Top_Kept := Integer (Put_Top);
         Yoga.Nodes.Set_Position (Node (Bubble), Yoga.Left, Float'Rounding (Left));
         Yoga.Nodes.Set_Position (Node (Bubble), Yoga.Top, Float'Rounding (Put_Top));
         Request_Layout (Item);
      end if;
   end Place_Bubble;

end Pomarine.Widgets.Editors.Metrics;
