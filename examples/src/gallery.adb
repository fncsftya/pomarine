with Pomarine.Anchoring;
with Pomarine.Dialogs;
with Pomarine.Themes;
with Pomarine.Widgets.Callbacks;
with Pomarine.Widgets.Checks;
with Pomarine.Widgets.Overlays;

package body Gallery is

   package Buttons renames Pomarine.Widgets.Buttons;
   package Menus renames Pomarine.Widgets.Menus;
   package Widgets renames Pomarine.Widgets;
   package Hooks is new Pomarine.Widgets.Callbacks (Specimens);

   use all type Gallery_VM.Command;

   function Heading (Parent : Gallery_UI.Context'Class; Caption : String) return UI.Layout is
     (Parent.Label (Caption, Height => 20.0));

   function Buttons_Row (Parent : Gallery_UI.Context'Class) return UI.Layout is
     (UI.Row ([Parent.Button ("Click me", Click_Me, Look => Buttons.Primary, Width => 90.0),
               Parent.Button ("Reset", Gallery_VM.Reset, Width => 70.0),
               Parent.Button ("Remove", Remove_Chosen, Look => Buttons.Danger, Width => 80.0),
               Parent.Label (Summary_Text, Grow => 1.0, Margin => 8.0)],
              Gap => 8.0));

   function Progress_Row (Parent : Gallery_UI.Context'Class) return UI.Layout is
     (Parent.Progress (Progress_Done, Height => 8.0));

   function Name_Row (Parent : Gallery_UI.Context'Class) return UI.Layout is
     (UI.Row ([Parent.Text_Field (Name_Text, Placeholder => "Your name", Name => "Your name", Width => 260.0),
               Parent.Label (Greeting_Text, Grow => 1.0, Margin => 8.0)],
              Gap => 8.0));

   function Choices_Row (Parent : Gallery_UI.Context'Class) return UI.Layout is
     (UI.Row ([Parent.Check ("Notify me", Notify_Flag, Name => "Notify me", Width => 120.0),
               Parent.Check ("Small", Size_Flag, Pick_Size, Pomarine.Widgets.Checks.Radio, Index => 1,
                             Name => "Small", Width => 80.0),
               Parent.Check ("Medium", Size_Flag, Pick_Size, Pomarine.Widgets.Checks.Radio, Index => 2,
                             Name => "Medium", Width => 90.0),
               Parent.Check ("Large", Size_Flag, Pick_Size, Pomarine.Widgets.Checks.Radio, Index => 3,
                             Name => "Large", Width => 80.0),
               Parent.Switch ("Compact", Compact_Flag, Toggle_Compact, Name => "Compact", Width => 120.0)],
              Gap => 8.0));

   function Specimens_Row (Parent : Gallery_UI.Context'Class; Parts : in out Specimens) return UI.Layout is
   begin
      Pomarine.Widgets.Sliders.Set_Value (Parts.Slider, 0.4);
      Pomarine.Widgets.Selects.Add_Choice (Parts.Choice, "Georgia");
      Pomarine.Widgets.Selects.Add_Choice (Parts.Choice, "Menlo");
      Pomarine.Widgets.Selects.Add_Choice (Parts.Choice, "Avenir");
      Pomarine.Widgets.Selects.Set_Value (Parts.Choice, "Georgia");
      Pomarine.Widgets.Chips.Set_Label (Parts.Tag, "Ada");
      Pomarine.Widgets.Chips.Set_Swatch (Parts.Tag, Pomarine.Themes.Primary);
      Pomarine.Widgets.Badges.Set_Count (Parts.Count, 3);
      return UI.Row
        ([Parent.Borrow_Widget (Parts.Slider, Tooltip => "Drag it, or use the arrow keys", Width => 200.0,
                                Height => 24.0),
          Parent.Borrow_Widget (Parts.Choice, Tooltip => "Opens its own menu", Name => "Font", Width => 160.0,
                                Height => 32.0),
          Parent.Borrow_Widget (Parts.Tag, Width => 90.0, Height => 24.0),
          Parent.Borrow_Widget (Parts.Count, Width => 40.0, Height => 16.0)],
         Gap => 16.0);
   end Specimens_Row;

   function Choosers_Row (Parent : Gallery_UI.Context'Class; Parts : in out Specimens) return UI.Layout is
   begin
      Pomarine.Widgets.Choice_Groups.Set_Look (Parts.Views, Pomarine.Widgets.Choice_Groups.Tabs);
      Pomarine.Widgets.Choice_Groups.Add_Choice (Parts.Views, "Write");
      Pomarine.Widgets.Choice_Groups.Add_Choice (Parts.Views, "Outline");
      Pomarine.Widgets.Choice_Groups.Add_Choice (Parts.Views, "Canvas");
      Widgets.Number_Fields.Configure (Parts.Quantity, "Georgia", 14.0, Min => 1, Max => 999, Start => 12);
      Widgets.Choice_Groups.Set_Focusable (Parts.Views, True);
      Pomarine.Widgets.Steppers.Set_Focusable (Parts.Copies, True);
      Pomarine.Widgets.Steppers.Set_Range (Parts.Copies, 1, 99);
      Pomarine.Widgets.Steppers.Set_Value (Parts.Copies, 2);
      Pomarine.Widgets.Steppers.Set_Suffix (Parts.Copies, " copies");
      return UI.Row
        ([Parent.Borrow_Widget (Parts.Views, Width => 280.0, Height => 32.0),
          Parent.Borrow_Widget (Parts.Copies, Name => "Copies", Width => 150.0, Height => 32.0),
          Parent.Borrow_Widget (Parts.Quantity, Name => "Quantity", Width => 160.0, Height => 32.0)],
         Gap => 24.0);
   end Choosers_Row;

   function Variants_Row (Parent : Gallery_UI.Context'Class; Parts : in out Specimens) return UI.Layout is
   begin
      Widgets.Choice_Groups.Set_Look (Parts.Alignment, Widgets.Choice_Groups.Segments);
      Widgets.Choice_Groups.Add_Choice (Parts.Alignment, "Left");
      Widgets.Choice_Groups.Add_Choice (Parts.Alignment, "Center");
      Widgets.Choice_Groups.Add_Choice (Parts.Alignment, "Right");
      Widgets.Choice_Groups.Set_Look (Parts.Mode, Widgets.Choice_Groups.Radios);
      Widgets.Choice_Groups.Set_Vertical (Parts.Mode, False);
      Widgets.Choice_Groups.Add_Choice (Parts.Mode, "Draft");
      Widgets.Choice_Groups.Add_Choice (Parts.Mode, "Final");
      Widgets.Choice_Groups.Set_Focusable (Parts.Alignment, True);
      Widgets.Choice_Groups.Set_Focusable (Parts.Mode, True);
      return UI.Row
        ([Parent.Borrow_Widget (Parts.Alignment, Width => 320.0, Height => 32.0),
          Parent.Borrow_Widget (Parts.Mode, Width => 320.0, Height => 32.0)],
         Gap => 24.0);
   end Variants_Row;

   function Editor_Row (Parent : Gallery_UI.Context'Class; Parts : in out Specimens) return UI.Layout is
   begin
      Texts.Documents.Load (Parts.Sample_Doc, "Select some text and try the formatting toolbar.");
      Widgets.Editors.Configure (Parts.Sample_Editor, "Georgia", 14.0, Measure => 640.0);
      Widgets.Editors.Attach (Parts.Sample_Editor, Parts.Sample_Doc'Unchecked_Access);
      Widgets.Editors.Set_Toolbar (Parts.Sample_Editor);
      return Parent.Borrow_Widget (Parts.Sample_Editor, Name => "Rich text", Height => 110.0);
   end Editor_Row;

   function Disclosure_Row (Parent : Gallery_UI.Context'Class; Parts : in out Specimens) return UI.Layout is
      Whole : constant UI.Widget_Handle := Parent.Borrow_Widget (Parts.Advanced);
   begin
      Pomarine.Widgets.Disclosures.Set_Title (Parts.Advanced, "Advanced");
      Pomarine.Widgets.Disclosures.Set_Focusable (Parts.Advanced, True);
      Pomarine.Widgets.Labels.Set_Text (Parts.Note_1, "A disclosure hides what is under its heading.");
      Pomarine.Widgets.Labels.Set_Text (Parts.Note_2, "Click the heading, or press Space on it.");
      return UI.Styled
        (UI.Hold (Whole, [Parent.Borrow_Widget (Parts.Note_1, Height => 20.0),
                          Parent.Borrow_Widget (Parts.Note_2, Height => 20.0)]),
         Pomarine.Widgets.Disclosures.Box_Style);
   end Disclosure_Row;

   function Splitter_Row (Parent : Gallery_UI.Context'Class; Parts : in out Specimens) return UI.Layout is
   begin
      Pomarine.Widgets.Panels.Set_Fill (Parts.Side_Pane, Pomarine.Themes.Tint);
      Pomarine.Widgets.Panels.Set_Border (Parts.Side_Pane, Pomarine.Themes.Border);
      Pomarine.Widgets.Panels.Set_Fill (Parts.Main_Pane, Pomarine.Themes.Page);
      Pomarine.Widgets.Panels.Set_Border (Parts.Main_Pane, Pomarine.Themes.Border);
      Pomarine.Widgets.Splitters.Set_Focusable (Parts.Divider, True);
      Pomarine.Widgets.Splitters.Set_Limits (Parts.Divider, 80.0, 400.0);
      return UI.Row
        ([Parent.Borrow_Widget (Parts.Side_Pane, Width => 160.0, Shrink => 0.0),
          Parent.Borrow_Widget (Parts.Divider, Tooltip => "Drag to give one side more room",
                                Name => "Pane divider", Width => 6.0, Shrink => 0.0),
          Parent.Borrow_Widget (Parts.Main_Pane, Grow => 1.0)],
         Height => 56.0, Align => UI.Layouts.Stretch);
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
      Menu_Height : constant UI.Layouts.Length := Prepared_Menu (Parts);
   begin
      return UI.Row ([Parent.List (Item_Rows, Item_Choice, Name => "Fruit", Width => 260.0, Height => 150.0),
                      Parent.Borrow_Widget (Parts.Menu, Width => 200.0, Height => Menu_Height)],
                     Gap => 16.0, Align => UI.Layouts.Start);
   end Lists_Row;

   function Notices_Row (Parent : Gallery_UI.Context'Class; Parts : in out Specimens) return UI.Layout is
   begin
      Pomarine.Widgets.Toasts.Set_Message (Parts.Message, "Task deleted");
      Pomarine.Widgets.Toasts.Set_Action (Parts.Message, "Undo");
      Pomarine.Widgets.Tooltips.Set_Text (Parts.Sample_Tip, "Saves the file");
      Buttons.Configure (Parts.Info_Button, Buttons.Looks ("Popover", Focusable => True));
      Buttons.Configure (Parts.Ask_Button, Buttons.Looks ("Dialog", Buttons.Danger, Focusable => True));
      Buttons.Configure (Parts.Context_Button, Buttons.Looks ("Context menu", Focusable => True));
      return UI.Row
        ([Parent.Borrow_Widget (Parts.Message, Width => 220.0, Height => 36.0),
          Parent.Borrow_Widget (Parts.Sample_Tip, Width => 90.0, Height => 22.0),
          Parent.Borrow_Widget (Parts.Info_Button, Tooltip => "Opens a popover beside it", Width => 80.0,
                                Height => 32.0),
          Parent.Borrow_Widget (Parts.Ask_Button, Tooltip => "Asks whether to go ahead", Width => 80.0,
                                Height => 32.0),
          Parent.Borrow_Widget (Parts.Context_Button, Width => 100.0, Height => 32.0)],
         Gap => 16.0);
   end Notices_Row;

   function Gallery_Screen (Bound : Gallery_UI.Context'Class; Parts : in out Specimens) return UI.Layout is
     (UI.Column
        ([Heading (Bound, "Buttons"), Buttons_Row (Bound), Progress_Row (Bound),
          Heading (Bound, "Fields"), Name_Row (Bound), Choices_Row (Bound),
          Heading (Bound, "Values"), Specimens_Row (Bound, Parts),
          Heading (Bound, "Choosers"), Choosers_Row (Bound, Parts), Variants_Row (Bound, Parts),
          Disclosure_Row (Bound, Parts), Splitter_Row (Bound, Parts),
          Heading (Bound, "Rich text"), Editor_Row (Bound, Parts),
          Heading (Bound, "Lists and menus"), Lists_Row (Bound, Parts),
          Heading (Bound, "Notices"), Notices_Row (Bound, Parts)],
         Padding => 16.0, Gap => 8.0));

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

   procedure Show_Context
     (Self : in out Specimens; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event) is
      pragma Unreferenced (Event);
   begin
      if not Widgets.Overlays.Is_Presented (Self.Context_Menu) then
         Widgets.Overlays.Present_Beside
           (Self.Context_Menu, Source, (Side => Pomarine.Anchoring.Above, others => <>));
      end if;
   end Show_Context;

   procedure Build
     (Screen : in out UI.View;
      Model  : not null access Gallery_VM.Model;
      Parts  : in out Specimens)
   is
      Bound : constant Gallery_UI.Context'Class := Gallery_UI.Bind (Screen, Model);
      Whole : constant UI.Layout := UI.Column
        ([UI.Scroll (Gallery_Screen (Bound, Parts), Grow => 1.0, Height => 0.0)], Grow => 1.0);
      Root  : Widgets.Widget_Access;
   begin
      UI.Mount (Screen, Whole);
      --  What floats over the window is in the root of the tree, over what the screen made.
      Root := Widgets.Root_Widget (Screen.Tree.all);
      Widgets.Popovers.Add (Root.all, Parts.Info, Width => 230.0);
      UI.Layouts.Add (Parts.Info, Parts.Info_Note, (Height => 22.0, others => <>));
      Widgets.Labels.Set_Text (Parts.Info_Note, "A popover holds any widgets.");
      Widgets.Dialogs.Add (Root.all, Parts.Ask, Width => 340.0);
      UI.Layouts.Add (Root.all, Parts.Context_Menu, (Width => 200.0, others => <>));
      Menus.Set_Rows (Parts.Context_Menu, Menu_Rows);
      Menus.Set_Keyboard (Parts.Context_Menu, True);
      Menus.Set_Closes_On_Choose (Parts.Context_Menu, True);
      Widgets.Set_Visible (Parts.Context_Menu, False);
      Widgets.Tooltips.Install (Screen.Tree.all, Parts.Hover_Tip);
      Hooks.On (Parts.Context_Button, Widgets.Click, Parts'Unrestricted_Access, Show_Context'Access);
      Hooks.On (Parts.Info_Button, Widgets.Click, Parts'Unrestricted_Access, Show_Popover'Access);
      Hooks.On (Parts.Ask_Button, Widgets.Click, Parts'Unrestricted_Access, Ask_Question'Access);
   end Build;

end Gallery;
