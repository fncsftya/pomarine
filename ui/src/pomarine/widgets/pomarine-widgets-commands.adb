package body Pomarine.Widgets.Commands is

   procedure Bind (Item : in out Widget'Class; Is_For : Command; Index : Natural := 0) is
   begin
      Set_Tag (Item, Command'Pos (Is_For), Index);
   end Bind;

   procedure Trigger (Item : in out Widget'Class; Is_For : Command; Index : Natural := 0) is
   begin
      Set_Tag (Item, Command'Pos (Is_For), Index, Reflects => False);
   end Trigger;

   function What (Event : Widget_Event) return Command is (Command'Val (Event.Tag));

end Pomarine.Widgets.Commands;
