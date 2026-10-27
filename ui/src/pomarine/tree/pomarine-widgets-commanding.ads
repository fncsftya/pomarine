--  The commands of the tree's widgets: what each is for now (by the validator), and the keys bound to them.
--  A private child of Pomarine.Widgets: its operations are the parts of that package's body that are not
--  its own interface, and are called from it.

private package Pomarine.Widgets.Commanding is

   procedure Forget_Told_States (Item : in out Tree);

   procedure Tell_All (Item : in out Tree);

   procedure Perform (Item : in out Tree; Tag : Integer; Done : out Boolean);

   procedure Bind
     (Item    : in out Tree;
      Key     : Pomarine.Events.Key_Code;
      Command : Boolean := False;
      Shift   : Boolean := False;
      Tag     : Integer);

end Pomarine.Widgets.Commanding;
