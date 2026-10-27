--  Widgets joining the tree: the slot each takes in the tree's table, the root, and children added after or before
--  another, with the layout's node made for each.
--  A private child of Pomarine.Widgets: its operations are the parts of that package's body that are not
--  its own interface, and are called from it.

private package Pomarine.Widgets.Adding is

   procedure Start_Measuring (Item : in out Widget'Class);
   --  Have the layout ask the widget how big it wants to be.

   procedure Take_Slot (Home : in out Tree; Item : in out Widget'Class; Slot : out Node_Index);

   procedure Give_Back (Home : in out Tree; Slot : Node_Index);

   procedure Give_Back_All (Home : in out Tree; Slot : Node_Index);

   procedure Plant_Root (Item : in out Tree; Root : in out Widget'Class);

   procedure Attach (Parent : in out Widget'Class; Child : in out Widget'Class);

   procedure Attach (Parent : in out Widget'Class; First, Second, Third, Fourth : in out Widget'Class);

   procedure Attach (Parent : in out Widget'Class; First, Second, Third, Fourth, Fifth : in out Widget'Class);

   procedure Attach_Before (Parent : in out Widget'Class; Child : in out Widget'Class; Before : Widget'Class);

end Pomarine.Widgets.Adding;
