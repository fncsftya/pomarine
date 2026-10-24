package body Hearers is

   use type System.Address;
   use type Pomarine.Widgets.Event_Kind;

   overriding procedure Handle_Event
     (Self   : in out Hearer;
      Source : in out Pomarine.Widgets.Widget'Class;
      Event  : Pomarine.Widgets.Widget_Event) is
   begin
      Self.Log.Append (Heard'(From => Source'Address, Event => Event));
   end Handle_Event;

   procedure Find
     (Self   : Hearer;
      Source : Pomarine.Widgets.Widget'Class;
      Kind   : Pomarine.Widgets.Event_Kind;
      Found  : out Natural) is
   begin
      Found := 0;
      for Each in 1 .. Natural (Self.Log.Length) loop
         if Self.Log (Each).From = Source'Address and then Self.Log (Each).Event.Kind = Kind then
            Found := Each;
            return;
         end if;
      end loop;
   end Find;

   procedure Take
     (Self   : in out Hearer;
      Source : Pomarine.Widgets.Widget'Class;
      Kind   : Pomarine.Widgets.Event_Kind;
      Event  : out Pomarine.Widgets.Widget_Event;
      Taken  : out Boolean)
   is
      Found : Natural;
   begin
      Find (Self, Source, Kind, Found);
      Taken := Found /= 0;
      if Taken then
         Event := Self.Log (Found).Event;
         Self.Log.Delete (Found);
      end if;
   end Take;

   procedure Take
     (Self   : in out Hearer;
      Source : Pomarine.Widgets.Widget'Class;
      Kind   : Pomarine.Widgets.Event_Kind;
      Taken  : out Boolean)
   is
      Found : Natural;
   begin
      Taken := False;
      loop
         Find (Self, Source, Kind, Found);
         exit when Found = 0;
         Self.Log.Delete (Found);
         Taken := True;
      end loop;
   end Take;

   procedure Take_Row
     (Self   : in out Hearer;
      Source : Pomarine.Widgets.Widget'Class;
      Kind   : Pomarine.Widgets.Event_Kind;
      Row    : out Natural)
   is
      Found : Natural;
   begin
      Row := 0;
      Find (Self, Source, Kind, Found);
      if Found /= 0 then
         declare
            Said : constant Pomarine.Widgets.Widget_Event := Self.Log (Found).Event;
         begin
            Row := (case Said.Kind is
                       when Pomarine.Widgets.Choose | Pomarine.Widgets.Act => Said.Row,
                       when others => 0);
         end;
         Self.Log.Delete (Found);
      end if;
   end Take_Row;

   procedure Forget (Self : in out Hearer) is
   begin
      Self.Log.Clear;
   end Forget;

end Hearers;
