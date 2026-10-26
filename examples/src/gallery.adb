with Pomarine.Anchoring;
with Pomarine.Dialogs;
with Pomarine.Themes;
with Pomarine.Widgets.Callbacks;
with Pomarine.Widgets.Checks;

package body Gallery is

   package Buttons renames Pomarine.Widgets.Buttons;
   package Menus renames Pomarine.Widgets.Menus;
   package Widgets renames Pomarine.Widgets;
   package Hooks is new Pomarine.Widgets.Callbacks (Specimens);

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
      Pomarine.Widgets.Selects.Add_Choice (Parts.Choice, "Georgia");
      Pomarine.Widgets.Selects.Add_Choice (Parts.Choice, "Menlo");
      Pomarine.Widgets.Selects.Add_Choice (Parts.Choice, "Avenir");
      Pomarine.Widgets.Selects.Set_Value (Parts.Choice, "Georgia");
      Widgets.Set_Tooltip (Parts.Choice, "Opens its own menu");
      Widgets.Set_Tooltip (Parts.Slider, "Drag it, or use the arrow keys");
      Pomarine.Widgets.Chips.Set_Label (Parts.Tag, "Ada");
      Pomarine.Widgets.Chips.Set_Swatch (Parts.Tag, Pomarine.Themes.Primary);
      Pomarine.Widgets.Badges.Set_Count (Parts.Count, 3);
      Bound.Commit;
      return Result;
   end Specimens_Row;

   function Choosers_Row (Parent : Gallery_UI.Context'Class; Parts : in out Specimens) return UI.Layout is
      Bound  : aliased Gallery_UI.Component (Parent'Access);
      Views  : constant UI.Widget_Handle := Bound.Borrow_Widget (Parts.Views);
      Copies : constant UI.Widget_Handle := Bound.Borrow_Widget (Parts.Copies);
      Result : constant UI.Layout :=
        UI.Row ([UI.Place (Views, Width => 320.0, Height => 32.0), UI.Place (Copies, Width => 150.0, Height => 32.0)],
                Gap => 24.0);
   begin
      Pomarine.Widgets.Choice_Groups.Set_Look (Parts.Views, Pomarine.Widgets.Choice_Groups.Tabs);
      Pomarine.Widgets.Choice_Groups.Add_Choice (Parts.Views, "Write");
      Pomarine.Widgets.Choice_Groups.Add_Choice (Parts.Views, "Outline");
      Pomarine.Widgets.Choice_Groups.Add_Choice (Parts.Views, "Canvas");
      Pomarine.Widgets.Steppers.Set_Range (Parts.Copies, 1, 99);
      Pomarine.Widgets.Steppers.Set_Value (Parts.Copies, 2);
      Pomarine.Widgets.Steppers.Set_Suffix (Parts.Copies, " copies");
      Bound.Commit;
      return Result;
   end Choosers_Row;

   function Disclosure_Row (Parent : Gallery_UI.Context'Class; Parts : in out Specimens) return UI.Layout is
      Bound   : aliased Gallery_UI.Component (Parent'Access);
      Whole   : constant UI.Widget_Handle := Bound.Borrow_Widget (Parts.Advanced);
      First   : constant UI.Widget_Handle := Bound.Borrow_Widget (Parts.Note_1);
      Second  : constant UI.Widget_Handle := Bound.Borrow_Widget (Parts.Note_2);
      Result  : constant UI.Layout :=
        UI.Styled
          (UI.Hold (Whole, [UI.Place (First, Height => 20.0), UI.Place (Second, Height => 20.0)]),
           Pomarine.Widgets.Disclosures.Box_Style);
   begin
      Pomarine.Widgets.Disclosures.Set_Title (Parts.Advanced, "Advanced");
      Pomarine.Widgets.Disclosures.Set_Focusable (Parts.Advanced, True);
      Pomarine.Widgets.Labels.Set_Text (Parts.Note_1, "A disclosure hides what is under its heading.");
      Pomarine.Widgets.Labels.Set_Text (Parts.Note_2, "Click the heading, or press Space on it.");
      Bound.Commit;
      return Result;
   end Disclosure_Row;

   function Splitter_Row (Parent : Gallery_UI.Context'Class; Parts : in out Specimens) return UI.Layout is
      Bound   : aliased Gallery_UI.Component (Parent'Access);
      Side    : constant UI.Widget_Handle := Bound.Borrow_Widget (Parts.Side_Pane);
      Divider : constant UI.Widget_Handle := Bound.Borrow_Widget (Parts.Divider);
      Main    : constant UI.Widget_Handle := Bound.Borrow_Widget (Parts.Main_Pane);
      Result  : constant UI.Layout :=
        UI.Row ([UI.Place (Side, Width => 160.0, Shrink => 0.0), UI.Place (Divider, Width => 6.0, Shrink => 0.0),
                 UI.Place (Main, Grow => 1.0)],
                Height => 56.0, Align => UI.Layouts.Stretch);
   begin
      Pomarine.Widgets.Panels.Set_Fill (Parts.Side_Pane, Pomarine.Themes.Tint);
      Pomarine.Widgets.Panels.Set_Border (Parts.Side_Pane, Pomarine.Themes.Border);
      Pomarine.Widgets.Panels.Set_Fill (Parts.Main_Pane, Pomarine.Themes.Page);
      Pomarine.Widgets.Panels.Set_Border (Parts.Main_Pane, Pomarine.Themes.Border);
      Pomarine.Widgets.Splitters.Set_Focusable (Parts.Divider, True);
      Pomarine.Widgets.Splitters.Set_Limits (Parts.Divider, 80.0, 400.0);
      Widgets.Set_Tooltip (Parts.Divider, "Drag to give one side more room");
      Bound.Commit;
      return Result;
   end Splitter_Row;

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
      Tip     : constant UI.Widget_Handle := Bound.Borrow_Widget (Parts.Sample_Tip);
      Popover : constant UI.Widget_Handle := Bound.Borrow_Widget (Parts.Info_Button);
      Dialog  : constant UI.Widget_Handle := Bound.Borrow_Widget (Parts.Ask_Button);
      Result  : constant UI.Layout :=
        UI.Row ([UI.Place (Message, Width => 300.0, Height => 36.0), UI.Place (Tip, Width => 110.0, Height => 22.0),
                 UI.Place (Popover, Width => 90.0, Height => 32.0), UI.Place (Dialog, Width => 90.0, Height => 32.0)],
                Gap => 16.0);
   begin
      Pomarine.Widgets.Toasts.Set_Message (Parts.Message, "Task deleted");
      Pomarine.Widgets.Toasts.Set_Action (Parts.Message, "Undo");
      Pomarine.Widgets.Tooltips.Set_Text (Parts.Sample_Tip, "Saves the file");
      Buttons.Configure (Parts.Info_Button, Buttons.Looks ("Popover", Focusable => True));
      Buttons.Configure (Parts.Ask_Button, Buttons.Looks ("Dialog", Buttons.Danger, Focusable => True));
      Widgets.Set_Tooltip (Parts.Info_Button, "Opens a popover beside it");
      Widgets.Set_Tooltip (Parts.Ask_Button, "Asks whether to go ahead");
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
      Choosers     : constant UI.Layout := Choosers_Row (Bound, Parts);
      Disclosure   : constant UI.Layout := Disclosure_Row (Bound, Parts);
      Divided      : constant UI.Layout := Splitter_Row (Bound, Parts);
      Notices      : constant UI.Layout := Notices_Row (Bound, Parts);
   begin
      return UI.Column
        ([Heading (Bound, "Buttons"), Buttons_Part, Progress,
          Heading (Bound, "Fields"), Name_Part, Choices,
          Heading (Bound, "Values"), Specimen,
          Heading (Bound, "Choosers"), Choosers, Disclosure, Divided,
          Heading (Bound, "Lists and menus"), Lists,
          Heading (Bound, "Notices"), Notices],
         Padding => 16.0, Gap => 8.0);
   end Gallery_Screen;

   procedure Show_Popover
     (Self : in out Specimens; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event) is
      pragma Unreferenced (Event);
   begin
      if Widgets.Popovers.Is_Shown (Self.Info) then
         Widgets.Popovers.Hide (Self.Info);
      else
         Widgets.Popovers.Show_Beside (Self.Info, Source, (Side => Pomarine.Anchoring.Above, others => <>));
      end if;
   end Show_Popover;

   procedure Ask_Question
     (Self : in out Specimens; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event) is
      pragma Unreferenced (Source, Event);
   begin
      if not Widgets.Dialogs.Is_Shown (Self.Ask) then
         Pomarine.Dialogs.Confirm
           (Self.Ask, "Delete the file?", "It cannot be got back, so think twice before you press Delete." & ASCII.LF
            & "Press Escape to keep the file.",
            Yes => "Delete", Dangerous => True);
      end if;
   end Ask_Question;

   procedure Build
     (Screen : in out UI.View;
      Model  : not null access Gallery_VM.Model;
      Parts  : in out Specimens)
   is
      Bound : constant Gallery_UI.Context'Class := Gallery_UI.Bind (Screen, Model);
      Whole : constant UI.Layout := Gallery_Screen (Bound, Parts);
      Root  : Widgets.Widget_Access;
   begin
      UI.Mount (Screen, Whole);
      --  What floats over the window is in the root of the tree, over what the screen made.
      Root := Widgets.Root_Widget (Screen.Tree.all);
      Widgets.Popovers.Add (Root.all, Parts.Info, Width => 230.0);
      UI.Layouts.Add (Parts.Info, Parts.Info_Note, (Height => 22.0, others => <>));
      Widgets.Labels.Set_Text (Parts.Info_Note, "A popover holds any widgets.");
      Widgets.Dialogs.Add (Root.all, Parts.Ask, Width => 340.0);
      Widgets.Tooltips.Install (Screen.Tree.all, Parts.Hover_Tip);
      Hooks.On (Parts.Info_Button, Widgets.Click, Parts'Unrestricted_Access, Show_Popover'Access);
      Hooks.On (Parts.Ask_Button, Widgets.Click, Parts'Unrestricted_Access, Ask_Question'Access);
   end Build;

end Gallery;
