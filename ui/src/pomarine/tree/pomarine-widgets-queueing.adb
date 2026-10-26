with Pomarine.Widgets.Nodes;
package body Pomarine.Widgets.Queueing is

   use Pomarine.Widgets.Nodes;

   function Run_Hooks (Item : in out Widget'Class; Event : Widget_Event) return Boolean is
   begin
      if Item.Cold = 0 or else not Block (Item.Cold).all.Hooks (Event.Kind).Used then
         return False;
      end if;
      declare
         Each : constant Hook := Block (Item.Cold).all.Hooks (Event.Kind);
      begin
         Each.Run (Each.Self, Each.Proc, Item, Event);
      end;
      return True;
   end Run_Hooks;
   --  Whether any handler of the widget's own took the event.

   procedure Deliver_All (Item : in out Tree) is
   begin
      if Item.Delivering then
         return;
      end if;
      Item.Delivering := True;
      while Item.Queued > 0 loop
         declare
            Next : constant Queued_Event := Item.Queue (Item.Queue_First);
            From : Widget_Access;
         begin
            Item.Queue_First := Item.Queue_First mod Queue_Capacity + 1;
            Item.Queued := Item.Queued - 1;
            --  Taken out of the tree since it spoke: nobody to answer.
            From := Resolve (Item, Next.Source);
            if From = null then
               null;
            elsif Next.Posted.Run /= null then
               Next.Posted.Run (Next.Posted.Self, Next.Posted.Proc, From.all, Next.Code, Next.Value);
            elsif not Run_Hooks (From.all, Next.Event) and then Next.Target /= null then
               Handle_Event (Next.Target.all, From.all, Next.Event);
            end if;
         end;
      end loop;
      Item.Delivering := False;
   exception
      when others =>
         Item.Delivering := False;
         raise;
   end Deliver_All;

   function Made_Event
     (Kind   : Event_Kind;
      Tag    : Integer;
      Index  : Natural;
      Row    : Natural;
      Across, Down : Float;
      Action : Natural) return Widget_Event
   is
      Result : Widget_Event (Kind);
   begin
      Result.Tag := Tag;
      Result.Index := Index;
      case Kind is
         when Choose =>
            Result.Row := Row;
         when Act =>
            Result.Row := Row;
            Result.Action := Action;
         when Drag | Move | Resize =>
            Result.Across := Across;
            Result.Down := Down;
         when others =>
            null;
      end case;
      return Result;
   end Made_Event;

   procedure Enqueue
     (Item   : in out Widget'Class;
      Kind   : Event_Kind;
      Row    : Natural := 0;
      Across : Float := 0.0;
      Down   : Float := 0.0;
      Action : Natural := 0)
   is
      Home   : constant Tree_Access := Item.Owner;
   begin
      if Home = null then
         return;
      end if;
      declare
         Target : constant Listener_Access :=
           (if Item.Own /= null then Item.Own else Home.Hearer);
      begin
         if Target = null and then not Has_Hook (Item, Kind) then
            return;
         end if;
         if Home.Queued = Queue_Capacity and then not Home.Delivering then
            Deliver (Home.all);
         end if;
         pragma Assert (Home.Queued < Queue_Capacity, "more events than the tree can keep");
         Home.Queue ((Home.Queue_First + Home.Queued - 1) mod Queue_Capacity + 1) :=
           (Source => Id_Of (Item),
            Target => Target,
            Event  => Made_Event (Kind, Item.Tag, Item.Index, Row, Across, Down, Action),
            Posted => <>,
            Code   => 0,
            Value  => 0);
         Home.Queued := Home.Queued + 1;
      end;
   end Enqueue;

   procedure Enqueue_Posted
     (Item  : in out Widget'Class;
      Using : Posted_Hook;
      Code  : Natural := 0;
      Value : Natural := 0)
   is
      Home : constant Tree_Access := Item.Owner;
   begin
      if Home = null or else Using.Run = null then
         return;
      end if;
      if Home.Queued = Queue_Capacity and then not Home.Delivering then
         Deliver (Home.all);
      end if;
      pragma Assert (Home.Queued < Queue_Capacity, "more events than the tree can keep");
      Home.Queue ((Home.Queue_First + Home.Queued - 1) mod Queue_Capacity + 1) :=
        (Source => Id_Of (Item),
         Target => null,
         Event  => Made_Event (Click, Item.Tag, Item.Index, 0, 0.0, 0.0, 0),
         Posted => Using,
         Code   => Code,
         Value  => Value);
      Home.Queued := Home.Queued + 1;
   end Enqueue_Posted;

end Pomarine.Widgets.Queueing;
