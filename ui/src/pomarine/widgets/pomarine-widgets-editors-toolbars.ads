with Pomarine.Events;

private package Pomarine.Widgets.Editors.Toolbars is

   function Tip_Text (Item : Editor; Tool : Tool_Number) return String;

   function Tool_For_Key (Item : Editor; Key : Pomarine.Events.Key_Code) return Natural;
   --  The number of the tool whose key it is; 0 if none.

   procedure Refresh_Tip (Item : in out Editor);
   --  Show the tooltip of the tool button the pointer is over, if any.

   procedure Build_Toolbar (Item : in out Editor);

   procedure Refresh_Toolbar (Item : in out Editor);

   procedure Update_Toolbar (Item : in out Editor);
   --  Show the toolbar's buttons if it is to have them, and hide them if not.

end Pomarine.Widgets.Editors.Toolbars;
