with Gallery_VM;
with Tasks;
with Pomarine.UI;
with Pomarine.UI.Contexts;
with Pomarine.Widgets.Badges;
with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Choice_Groups;
with Pomarine.Widgets.Chips;
with Pomarine.Widgets.Dialogs;
with Pomarine.Widgets.Disclosures;
with Pomarine.Widgets.Labels;
with Pomarine.Widgets.Menus;
with Pomarine.Widgets.Number_Fields;
with Pomarine.Widgets.Editors;
with Texts.Documents;
with Pomarine.Widgets.Panels;
with Pomarine.Widgets.Popovers;
with Pomarine.Widgets.Selects;
with Pomarine.Widgets.Sliders;
with Pomarine.Widgets.Splitters;
with Pomarine.Widgets.Steppers;
with Pomarine.Widgets.Toasts;
with Pomarine.Widgets.Tooltips;

--  The general-purpose controls on a scrollable sheet: the program of Gallery_GUI, and what the golden
--  tests of the library draw (`gallery-*`) and the view tests click through, so that a change to any
--  widget, the layout or the theme shows up here.
--
--  The controls that have a view-model (buttons, a field, checks, radios, a switch, a progress bar, a
--  list) are made by the view and bound to Gallery_VM. The rest (a slider, a select that opens its own menu,
--  tabs, segments, grouped radios, a number field, a stepper, a disclosure, a splitter, an editor,
--  a chip, a badge, a menu, a toast, a tooltip) are the application's
--  own, in Specimens, which the caller declares before the view that places them. What opens over the window (a
--  popover, a dialog, a tooltip that shows itself) is added to the tree's root after the screen is mounted:
--  the Popover and Dialog buttons open them.
package Gallery is

   package UI renames Pomarine.UI;

   package Gallery_UI is new UI.Contexts (Gallery_VM.Commands, Gallery_VM.Model);

   package Summary_Adapter is new Gallery_UI.Read_Text (Gallery_VM.Summary);
   package Greeting_Adapter is new Gallery_UI.Read_Text (Gallery_VM.Greeting);
   package Name_Adapter is new Gallery_UI.Edit_Text (Gallery_VM.Name, Gallery_VM.Set_Name);
   package Notify_Adapter is new Gallery_UI.Edit_Flag (Gallery_VM.Notify, Gallery_VM.Set_Notify);
   package Compact_Adapter is new Gallery_UI.Read_Flag (Gallery_VM.Compact);
   package Size_Adapter is new Gallery_UI.Indexed_Flag (Gallery_VM.Is_Size);
   package Progress_Adapter is new Gallery_UI.Read_Fraction (Gallery_VM.Progress);
   package Rows_Adapter is new Gallery_UI.Row_Source (Tasks.Task_List, Gallery_VM.Rows);
   package Choice_Adapter is new Gallery_UI.Choice (Gallery_VM.Selected_Item, Gallery_VM.Select_Item);

   type Specimens is limited record
      Slider  : Pomarine.Widgets.Sliders.Slider;
      Choice  : Pomarine.Widgets.Selects.Select_Field;
      Tag     : Pomarine.Widgets.Chips.Chip;
      Count   : Pomarine.Widgets.Badges.Badge;
      Menu    : Pomarine.Widgets.Menus.Menu;
      Sample_Tip : Pomarine.Widgets.Tooltips.Tooltip;
      Message : Pomarine.Widgets.Toasts.Toast;
      Views   : Pomarine.Widgets.Choice_Groups.Choice_Group;
      Alignment : Pomarine.Widgets.Choice_Groups.Choice_Group;
      Mode : Pomarine.Widgets.Choice_Groups.Choice_Group;
      Quantity : Pomarine.Widgets.Number_Fields.Number_Field;
      Sample_Doc : aliased Texts.Documents.Document;
      Sample_Editor : Pomarine.Widgets.Editors.Editor;
      Context_Button : Pomarine.Widgets.Buttons.Button;
      Context_Menu : Pomarine.Widgets.Menus.Menu;
      Copies  : Pomarine.Widgets.Steppers.Stepper;
      Advanced : Pomarine.Widgets.Disclosures.Disclosure;
      Side_Pane, Main_Pane : Pomarine.Widgets.Panels.Panel;
      Divider : Pomarine.Widgets.Splitters.Splitter;
      Note_1, Note_2 : Pomarine.Widgets.Labels.Label;
      Info_Button, Ask_Button : Pomarine.Widgets.Buttons.Button;
      Info    : Pomarine.Widgets.Popovers.Popover;
      Info_Note : Pomarine.Widgets.Labels.Label;
      Ask     : Pomarine.Widgets.Dialogs.Dialog;
      Hover_Tip : Pomarine.Widgets.Tooltips.Tooltip;
   end record;

   Width  : constant := 720;
   Height : constant := 960;
   Initial_Height : constant := 770;
   --  Full-sheet test size and initial native window height, in points. Shorter windows scroll.

   procedure Build
     (Screen : in out UI.View;
      Model  : not null access Gallery_VM.Model;
      Parts  : in out Specimens);
   --  Make the screen of Model and Parts in Screen and mount it. Both must be there as long as Screen is used.

end Gallery;
