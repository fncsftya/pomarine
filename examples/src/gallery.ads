with Gallery_VM;
with Tasks;
with Pomarine.UI;
with Pomarine.UI.Contexts;
with Pomarine.Widgets.Badges;
with Pomarine.Widgets.Chips;
with Pomarine.Widgets.Menus;
with Pomarine.Widgets.Selects;
with Pomarine.Widgets.Sliders;
with Pomarine.Widgets.Toasts;
with Pomarine.Widgets.Tooltips;

--  Every kind of widget the library has, on one screen: the program of Gallery_GUI, and what the golden
--  tests of the library draw (`gallery-*`) and the view tests click through, so that a change to any
--  widget, the layout or the theme shows up here.
--
--  The controls that have a view-model (buttons, a field, checks, radios, a switch, a progress bar, a
--  list) are made by the view and bound to Gallery_VM. The rest (a slider, a select, a chip, a badge, a
--  menu, a tooltip, a toast) are the application's own, in Specimens, which the caller declares before
--  the view that places them.
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
      Tip     : Pomarine.Widgets.Tooltips.Tooltip;
      Message : Pomarine.Widgets.Toasts.Toast;
   end record;

   Width  : constant := 720;
   Height : constant := 560;
   --  The window, in points, that the screen is made for.

   procedure Build
     (Screen : in out UI.View;
      Model  : not null access Gallery_VM.Model;
      Parts  : in out Specimens);
   --  Make the screen of Model and Parts in Screen and mount it. Both must be there as long as Screen is used.

end Gallery;
