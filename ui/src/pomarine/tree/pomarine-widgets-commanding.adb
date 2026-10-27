with Pomarine.Widgets.Nodes;
with Pomarine.Widgets.Queueing;

package body Pomarine.Widgets.Commanding is

   use type Interfaces.Unsigned_32;
   use Pomarine.Widgets.Nodes;
   use Pomarine.Widgets.Queueing;

   procedure Forget_Told_States (Item : in out Tree) is
   begin
      if Item.Nodes /= null then
         for Slot in 1 .. Item.Nodes.Fresh loop
            Item.Told_States (Slot) := Enabled;
         end loop;
      end if;
   end Forget_Told_States;

   procedure Tell_All (Item : in out Tree) is
   begin
      if (Item.Validator = null and then Item.Judge = null) or else Item.Nodes = null then
         return;
      end if;
      for Slot in 1 .. Item.Nodes.Fresh loop
         declare
            Mine : constant Widget_Access := Item.Nodes.Object (Slot);
         begin
            if Mine /= null and then Mine.Tag /= No_Tag and then Mine.Reflects then
               declare
                  Now : constant Command_State := Command_State_Of (Item, Mine.Tag, Mine.Index);
               begin
                  if Now /= Item.Told_States (Slot) or else Item.Retell (Slot) then
                     Item.Told_States (Slot) := Now;
                     Item.Retell (Slot) := False;
                     Mine.Was_Told := True;
                     if Now = Not_Offered then
                        Mine.Hid_By_Command := True;
                        Set_Visible (Mine.all, False);
                     elsif Mine.Hid_By_Command then
                        Mine.Hid_By_Command := False;
                        Set_Visible (Mine.all, True);
                     end if;
                     Command_State_Changed (Mine.all, Now);
                  end if;
               end;
            end if;
         end;
      end loop;
   end Tell_All;

   procedure Perform (Item : in out Tree; Tag : Integer; Done : out Boolean) is
      Asking : Node_Index := (if Item.Focus /= 0 then Item.Focus else Item.Root);
   begin
      Done := False;
      while Asking /= 0 and then not Done loop
         Handle_Command (Item.Nodes.Object (Asking).all, Tag, Done);
         Asking := Item.Nodes.Parent (Asking);
      end loop;
      if not Done and then Item.Hearer /= null and then Item.Root /= 0 then
         if Item.Queued = Queue_Capacity and then not Item.Delivering then
            Deliver (Item);
         end if;
         pragma Assert (Item.Queued < Queue_Capacity, "more events than the tree can keep");
         Item.Queue ((Item.Queue_First + Item.Queued - 1) mod Queue_Capacity + 1) :=
           (Source => Id_Of_Slot (Item, Item.Root),
            Target => Item.Hearer,
            Event  => Made_Event (Click, Tag, 0, 0, 0.0, 0.0, 0),
            Posted => <>,
            Code   => 0,
            Value  => 0);
         Item.Queued := Item.Queued + 1;
         Done := True;
      end if;
   end Perform;

   procedure Bind
     (Item    : in out Tree;
      Key     : Pomarine.Events.Key_Code;
      Command : Boolean := False;
      Shift   : Boolean := False;
      Tag     : Integer) is
   begin
      for Each of Item.Keys (1 .. Item.Keys_Bound) loop
         if Each.Key = Key and then Each.Command = Command and then Each.Shift = Shift then
            Each.Tag := Tag;
            return;
         end if;
      end loop;
      pragma Assert (Item.Keys_Bound < Key_Binding_Capacity, "more keys bound than the tree can keep");
      Item.Keys_Bound := Item.Keys_Bound + 1;
      Item.Keys (Item.Keys_Bound) := (Key, Command, Shift, Tag);
   end Bind;

end Pomarine.Widgets.Commanding;
