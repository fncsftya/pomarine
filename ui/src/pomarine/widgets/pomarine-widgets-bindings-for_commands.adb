package body Pomarine.Widgets.Bindings.For_Commands is

   procedure Bind (Item : in out Widget'Class; Is_For : Models.Command; Index : Natural := 0) is
   begin
      Set_Tag (Item, Tag_Base + Models.Command'Pos (Is_For), Index);
   end Bind;

   procedure Trigger (Item : in out Widget'Class; Is_For : Models.Command; Index : Natural := 0) is
   begin
      Set_Tag (Item, Tag_Base + Models.Command'Pos (Is_For), Index, Reflects => False);
   end Trigger;

   function What (Event : Widget_Event) return Models.Command is (Models.Command'Val (Event.Tag - Tag_Base));

   procedure Observe (Item : in out Judge; Model : not null access Models.Model'Class) is
   begin
      Item.Asked := Model.all'Unrestricted_Access;
   end Observe;

   procedure Attach
     (Item   : aliased in out Judge;
      Within : in out Pomarine.Widgets.Tree;
      Model  : not null access Models.Model'Class) is
   begin
      Observe (Item, Model);
      Set_Validator (Within, Item'Unchecked_Access);
   end Attach;

   overriding function Validate (Self : Judge; Tag : Integer; Index : Natural) return Command_State is
     (if Self.Asked = null or else not Is_Mine (Tag) then Not_Offered
      elsif Models.Can_Execute (Self.Asked.all, Models.Command'Val (Tag - Tag_Base), Index) then Enabled
      else Disabled);

   function Perform (Model : in out Models.Model'Class; Event : Widget_Event) return Boolean is
   begin
      if Event.Kind in Click | Submit and then Is_Bound (Event) then
         if Models.Can_Execute (Model, What (Event), Event.Index) then
            Models.Execute (Model, What (Event), Event.Index);
         end if;
         return True;
      end if;
      return False;
   end Perform;

   function Changed (Seen : in out Pomarine.View_Models.Watch; Model : Models.Model'Class) return Boolean is
     (Pomarine.View_Models.Changed (Seen, Models.Version (Model)));

end Pomarine.Widgets.Bindings.For_Commands;
