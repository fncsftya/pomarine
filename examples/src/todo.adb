with Pomarine.Line_Texts;
with Pomarine.Widgets.Callbacks;
with Pomarine.Widgets.Layouts;

package body Todo is
   package Widgets renames Pomarine.Widgets;
   package Buttons renames Pomarine.Widgets.Buttons;
   package Layouts renames Pomarine.Widgets.Layouts;

   package Handlers is new Widgets.Callbacks (Page);

   procedure Show_Summary (Item : in out Page) is
      Open : constant Natural := Tasks.Open_Count (Item.Items);
   begin
      Pomarine.Widgets.Labels.Set_Text
        (Item.Summary, Open'Image & " of" & Tasks.Count (Item.Items)'Image & " left");
   end Show_Summary;

   procedure Add_Task (Item : in out Page; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event) is
      pragma Unreferenced (Source, Event);
      Text : constant String := Texts.Documents.Whole (Item.Typed);
   begin
      if Text'Length > 0 then
         Tasks.Add (Item.Items, Text);
         Texts.Documents.Load (Item.Typed, "");
         Pomarine.Widgets.Lists.Reveal (Item.List, Tasks.Count (Item.Items));
         Show_Summary (Item);
      end if;
   end Add_Task;

   procedure Toggle_Chosen
     (Item : in out Page; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
      Row : constant Natural := Pomarine.Widgets.Lists.Selected (Item.List);
   begin
      if Row > 0 then
         Tasks.Toggle (Item.Items, Row);
         Show_Summary (Item);
      end if;
   end Toggle_Chosen;

   procedure Remove_Chosen
     (Item : in out Page; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
      Row : constant Natural := Pomarine.Widgets.Lists.Selected (Item.List);
   begin
      if Row > 0 then
         Tasks.Delete (Item.Items, Row);
         Show_Summary (Item);
      end if;
   end Remove_Chosen;

   procedure Sweep_Done
     (Item : in out Page; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source, Event);
   begin
      Tasks.Clear_Done (Item.Items);
      Show_Summary (Item);
   end Sweep_Done;

   procedure Build (Item : aliased in out Page; Tree : in out Widgets.Tree) is
   begin
      Widgets.Set_Root (Tree, Item.Root);
      Layouts.Set_Layout (Item.Root, (Flow => Layouts.Column, Padding => (others => 12.0), Gap => 8.0, others => <>));
      Layouts.Add (Item.Root, Item.Entry_Box, (Height => 38.0, others => <>));
      Layouts.Add (Item.Root, Item.List, (Grow => 1.0, others => <>));
      Layouts.Add
        (Item.Root, Item.Footer,
         (Flow => Layouts.Row, Align => Layouts.Center, Height => 32.0, Gap => 8.0, others => <>));
      Layouts.Add (Item.Footer, Item.Summary, (Grow => 1.0, Height => 24.0, others => <>));
      Buttons.Add
        (Item.Footer, Item.Toggle, Buttons.Looks ("Done"), (Width => 70.0, Height => 32.0, others => <>));
      Buttons.Add
        (Item.Footer, Item.Remove, Buttons.Looks ("Delete", Buttons.Danger),
         (Width => 70.0, Height => 32.0, others => <>));
      Buttons.Add
        (Item.Footer, Item.Sweep, Buttons.Looks ("Clear done"), (Width => 100.0, Height => 32.0, others => <>));

      Pomarine.Widgets.Text_Fields.Configure (Item.Entry_Box, Pomarine.Line_Texts.Interface_Font, 15.0);
      Pomarine.Widgets.Text_Fields.Attach (Item.Entry_Box, Item.Typed'Unchecked_Access);
      Pomarine.Widgets.Text_Fields.Set_Placeholder (Item.Entry_Box, "What needs doing? Press Return");
      Pomarine.Widgets.Lists.Set_Model (Item.List, Item.Items'Unchecked_Access);

      Handlers.On (Item.Entry_Box, Widgets.Submit, Item'Access, Add_Task'Access);
      Handlers.On (Item.Toggle, Widgets.Click, Item'Access, Toggle_Chosen'Access);
      Handlers.On (Item.Remove, Widgets.Click, Item'Access, Remove_Chosen'Access);
      Handlers.On (Item.Sweep, Widgets.Click, Item'Access, Sweep_Done'Access);

      Tasks.Add (Item.Items, "Read the Pomarine README");
      Tasks.Add (Item.Items, "Build the examples");
      Show_Summary (Item);
      Widgets.Focus (Item.Entry_Box);
   end Build;

end Todo;
