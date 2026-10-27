package body Pomarine.Widgets.Frames.Handlers is

   procedure On (Item : in out Frame; Kind : Event_Kind; Self : not null access Context; Do_This : not null Handler) is
   begin
      if Kind = Blur then
         Plain.On (Item.Title_Field, Kind, Self, Do_This);
      else
         Plain.On (Item.Outline_Panel, Kind, Self, Do_This);
      end if;
   end On;

   procedure Off (Item : in out Frame; Kind : Event_Kind) is
   begin
      if Kind = Blur then
         Plain.Off (Item.Title_Field, Kind);
      else
         Plain.Off (Item.Outline_Panel, Kind);
      end if;
   end Off;

end Pomarine.Widgets.Frames.Handlers;
