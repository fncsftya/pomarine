
private package Pomarine.Widgets.Editors.Choosers is

   procedure Close_Chooser (Item : in out Editor);
   --  Hide the menu of a font control, if one is open.

   procedure Open_Chooser (Item : in out Editor; Which : Choice);
   --  Open the menu of a font control, or close it if it is that one's.

end Pomarine.Widgets.Editors.Choosers;
