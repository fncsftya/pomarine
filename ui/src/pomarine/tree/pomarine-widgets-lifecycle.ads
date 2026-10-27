--  Widgets leaving or moving in the tree: taken out, shown or hidden, raised to the front.
--  A private child of Pomarine.Widgets: its operations are the parts of that package's body that are not
--  its own interface, and are called from it.

private package Pomarine.Widgets.Lifecycle is

   procedure Let_Go (Item : in out Tree; Of_Widget : Node_Index);

   procedure Show_Or_Hide (Item : in out Widget'Class; To : Boolean);

   procedure Unlink (Home : in out Tree; Slot : Node_Index);

   procedure Take_Out (Item : in out Widget'Class);

   procedure Bring_Forward (Item : in out Widget'Class);

end Pomarine.Widgets.Lifecycle;
