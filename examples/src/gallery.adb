with Pomarine.Themes;
with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Checks;

package body Gallery is

   package Buttons renames Pomarine.Widgets.Buttons;
   package Menus renames Pomarine.Widgets.Menus;

   use all type Gallery_VM.Command;

   function Heading (Parent : Gallery_UI.Context'Class; Caption : String) return UI.Layout is
      Bound  : aliased Gallery_UI.Component (Parent'Access);
      Title  : constant UI.Label_Handle := Bound.Label (Caption);
      Result : constant UI.Layout := UI.Place (Title, Height => 20.0);
   begin
      Bound.Commit;
      return Result;
   end Heading;

   function Buttons_Row (Parent : Gallery_UI.Context'Class) return UI.Layout is
      Bound   : aliased Gallery_UI.Component (Parent'Access);
      Click   : constant UI.Button_Handle := Bound.Button ("Click me", Click_Me, Look => Buttons.Primary);
      Restart : constant UI.Button_Handle := Bound.Button ("Reset", Gallery_VM.Reset);
      Remove  : constant UI.Button_Handle := Bound.Button ("Remove", Remove_Chosen, Look => Buttons.Danger);
      Summary : constant UI.Label_Handle := Bound.Label (Summary_Adapter.Property);
      Result  : constant UI.Layout :=
        UI.Row ([UI.Place (Click, Width => 90.0), UI.Place (Restart, Width => 70.0),
                 UI.Place (Remove, Width => 80.0), UI.Place (Summary, Grow => 1.0, Margin => 8.0)],
                Gap => 8.0);
   begin
      Bound.Commit;
      return Result;
   end Buttons_Row;

   function Progress_Row (Parent : Gallery_UI.Context'Class) return UI.Layout is
      Bound  : aliased Gallery_UI.Component (Parent'Access);
      Done   : constant UI.Progress_Handle := Bound.Progress (Progress_Adapter.Property);
      Result : constant UI.Layout := UI.Place (Done, Height => 8.0);
   begin
      Bound.Commit;
      return Result;
   end Progress_Row;

   function Name_Row (Parent : Gallery_UI.Context'Class) return UI.Layout is
      Bound    : aliased Gallery_UI.Component (Parent'Access);
      Typed    : constant UI.Field_Handle :=
        Bound.Text_Field (Name_Adapter.Property, Placeholder => "Your name", Name => "Your name");
      Greeting : constant UI.Label_Handle := Bound.Label (Greeting_Adapter.Property);
      Result   : constant UI.Layout :=
        UI.Row ([UI.Place (Typed, Width => 260.0), UI.Place (Greeting, Grow => 1.0, Margin => 8.0)], Gap => 8.0);
   begin
      Bound.Commit;
      return Result;
   end Name_Row;

   function Choices_Row (Parent : Gallery_UI.Context'Class) return UI.Layout is
      Bound   : aliased Gallery_UI.Component (Parent'Access);
      Notify  : constant UI.Check_Handle := Bound.Check ("Notify me", Notify_Adapter.Property, Name => "Notify me");
      Small   : constant UI.Check_Handle :=
        Bound.Check ("Small", Size_Adapter.Property, Pick_Size, Pomarine.Widgets.Checks.Radio, Index => 1,
                     Name => "Small");
      Medium  : constant UI.Check_Handle :=
        Bound.Check ("Medium", Size_Adapter.Property, Pick_Size, Pomarine.Widgets.Checks.Radio, Index => 2,
                     Name => "Medium");
      Large   : constant UI.Check_Handle :=
        Bound.Check ("Large", Size_Adapter.Property, Pick_Size, Pomarine.Widgets.Checks.Radio, Index => 3,
                     Name => "Large");
      Compact : constant UI.Switch_Handle :=
        Bound.Switch ("Compact", Compact_Adapter.Property, Toggle_Compact, Name => "Compact");
      Result  : constant UI.Layout :=
        UI.Row ([UI.Place (Notify, Width => 120.0), UI.Place (Small, Width => 80.0),
                 UI.Place (Medium, Width => 90.0), UI.Place (Large, Width => 80.0),
                 UI.Place (Compact, Width => 120.0)],
                Gap => 8.0);
   begin
      Bound.Commit;
      return Result;
   end Choices_Row;

   function Specimens_Row (Parent : Gallery_UI.Context'Class; Parts : in out Specimens) return UI.Layout is
      Bound  : aliased Gallery_UI.Component (Parent'Access);
      Slide  : constant UI.Widget_Handle := Bound.Borrow_Widget (Parts.Slider);
      Choice : constant UI.Widget_Handle := Bound.Borrow_Widget (Parts.Choice);
      Tag    : constant UI.Widget_Handle := Bound.Borrow_Widget (Parts.Tag);
      Count  : constant UI.Widget_Handle := Bound.Borrow_Widget (Parts.Count);
      Result : constant UI.Layout :=
        UI.Row ([UI.Place (Slide, Width => 200.0, Height => 24.0), UI.Place (Choice, Width => 160.0, Height => 32.0),
                 UI.Place (Tag, Width => 90.0, Height => 24.0), UI.Place (Count, Width => 40.0, Height => 16.0)],
                Gap => 16.0);
   begin
      Pomarine.Widgets.Sliders.Set_Value (Parts.Slider, 0.4);
      Pomarine.Widgets.Selects.Set_Value (Parts.Choice, "Georgia");
      Pomarine.Widgets.Chips.Set_Label (Parts.Tag, "Ada");
      Pomarine.Widgets.Chips.Set_Swatch (Parts.Tag, Pomarine.Themes.Primary);
      Pomarine.Widgets.Badges.Set_Count (Parts.Count, 3);
      Bound.Commit;
      return Result;
   end Specimens_Row;

   function Menu_Rows return Menus.Row_Vectors.Vector is
      Result : Menus.Row_Vectors.Vector;
   begin
      Result.Append (Menus.Describe_Row (Menus.Heading, "Edit"));
      Result.Append (Menus.Describe_Row (Menus.Action, "Copy"));
      Result.Append (Menus.Describe_Row (Menus.Check, "Word wrap", Checked => True));
      Result.Append (Menus.Describe_Row (Menus.Separator));
      Result.Append (Menus.Describe_Row (Menus.Action, "Delete", Shade => Menus.Danger));
      Result.Append (Menus.Describe_Row (Menus.Note, "Nothing else"));
      return Result;
   end Menu_Rows;

   function Prepared_Menu (Parts : in out Specimens) return UI.Layouts.Length is
   begin
      Menus.Set_Rows (Parts.Menu, Menu_Rows);
      return UI.Layouts.In_Points (Menus.Height_For (Parts.Menu));
   end Prepared_Menu;

   function Lists_Row (Parent : Gallery_UI.Context'Class; Parts : in out Specimens) return UI.Layout is
      Bound  : aliased Gallery_UI.Component (Parent'Access);
      Fruit  : constant UI.List_Handle := Bound.List (Rows_Adapter.Property, Choice_Adapter.Property, Name => "Fruit");
      Menu   : constant UI.Widget_Handle := Bound.Borrow_Widget (Parts.Menu);
      Result : constant UI.Layout :=
        UI.Row ([UI.Place (Fruit, Width => 260.0, Height => 150.0),
                 UI.Place (Menu, Width => 200.0, Height => Prepared_Menu (Parts))],
                Gap => 16.0, Align => UI.Layouts.Start);
   begin
      Bound.Commit;
      return Result;
   end Lists_Row;

   function Notices_Row (Parent : Gallery_UI.Context'Class; Parts : in out Specimens) return UI.Layout is
      Bound   : aliased Gallery_UI.Component (Parent'Access);
      Message : constant UI.Widget_Handle := Bound.Borrow_Widget (Parts.Message);
      Tip     : constant UI.Widget_Handle := Bound.Borrow_Widget (Parts.Tip);
      Result  : constant UI.Layout :=
        UI.Row ([UI.Place (Message, Width => 300.0, Height => 36.0), UI.Place (Tip, Width => 110.0, Height => 22.0)],
                Gap => 16.0);
   begin
      Pomarine.Widgets.Toasts.Set_Message (Parts.Message, "Task deleted");
      Pomarine.Widgets.Toasts.Set_Action (Parts.Message, "Undo");
      Pomarine.Widgets.Tooltips.Set_Text (Parts.Tip, "Saves the file");
      Bound.Commit;
      return Result;
   end Notices_Row;

   function Gallery_Screen (Bound : Gallery_UI.Context'Class; Parts : in out Specimens) return UI.Layout is
      --  Declared one after the other: the order controls are made in is the order of the tab key.
      Buttons_Part : constant UI.Layout := Buttons_Row (Bound);
      Progress     : constant UI.Layout := Progress_Row (Bound);
      Name_Part    : constant UI.Layout := Name_Row (Bound);
      Choices      : constant UI.Layout := Choices_Row (Bound);
      Specimen     : constant UI.Layout := Specimens_Row (Bound, Parts);
      Lists        : constant UI.Layout := Lists_Row (Bound, Parts);
      Notices      : constant UI.Layout := Notices_Row (Bound, Parts);
   begin
      return UI.Column
        ([Heading (Bound, "Buttons"), Buttons_Part, Progress,
          Heading (Bound, "Fields"), Name_Part, Choices,
          Heading (Bound, "Values"), Specimen,
          Heading (Bound, "Lists and menus"), Lists,
          Heading (Bound, "Notices"), Notices],
         Padding => 16.0, Gap => 8.0);
   end Gallery_Screen;

   procedure Build
     (Screen : in out UI.View;
      Model  : not null access Gallery_VM.Model;
      Parts  : in out Specimens)
   is
      Bound : constant Gallery_UI.Context'Class := Gallery_UI.Bind (Screen, Model);
      Whole : constant UI.Layout := Gallery_Screen (Bound, Parts);
   begin
      UI.Mount (Screen, Whole);
   end Build;

end Gallery;
