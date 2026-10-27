with Pomarine.Widgets.Adding;
with Pomarine.Widgets.Focusing;

package body Pomarine.Widgets.Lifecycle is

   use Pomarine.Widgets.Adding;
   use Pomarine.Widgets.Focusing;

   procedure Let_Go (Item : in out Tree; Of_Widget : Node_Index) is
   begin
      if Within (Item, Item.Focus, Of_Widget) then
         Set_Focus (Item, 0);
      end if;
      if Within (Item, Item.Hover, Of_Widget) then
         --  The pointer is over what the widget was in, if anything.
         Set_Hover (Item, Item.Nodes.Parent (Of_Widget));
      end if;
      if Within (Item, Item.Capture, Of_Widget) then
         Item.Capture := 0;
      end if;
      if Within (Item, Item.Wheel_Taker, Of_Widget) then
         Item.Wheel_Taker := 0;
      end if;
   end Let_Go;

   procedure Tell_Hidden (Home : in out Tree; Slot : Node_Index) is
      Part : Node_Index := Home.Nodes.First (Slot);
   begin
      Home.Nodes.Object (Slot).Hidden;
      while Part /= 0 loop
         declare
            Next : constant Node_Index := Home.Nodes.Next (Part);
         begin
            Tell_Hidden (Home, Part);
            Part := Next;
         end;
      end loop;
   end Tell_Hidden;
   --  Say it of the widget and of each in it, as they are no longer shown.

   procedure Show_Or_Hide (Item : in out Widget'Class; To : Boolean) is
      Table : Node_Table renames Item.Owner.Nodes.all;
   begin
      if To = Table.Spot (Item.Slot).Visible then
         return;
      end if;
      if not To then
         Let_Go (Item.Owner.all, Item.Slot);
         Invalidate (Item);
      end if;
      Table.Spot (Item.Slot).Visible := To;
      Table.Semantics_Dirty (Item.Slot) := True;
      if Table.Parent (Item.Slot) /= 0 then
         Table.Semantics_Dirty (Table.Parent (Item.Slot)) := True;
      end if;
      Yoga.Nodes.Set_Display (Table.Yoga_Node (Item.Slot), (if To then Yoga.Flex else Yoga.None));
      Request_Layout (Item);
      if not To then
         Tell_Hidden (Item.Owner.all, Item.Slot);
      end if;
   end Show_Or_Hide;

   procedure Unlink (Home : in out Tree; Slot : Node_Index) is
      Table  : Node_Table renames Home.Nodes.all;
      Above  : constant Node_Index := Table.Parent (Slot);
      Before : Node_Index := Table.First (Above);
   begin
      if Before = Slot then
         Table.First (Above) := Table.Next (Slot);
         if Table.Last (Above) = Slot then
            Table.Last (Above) := 0;
         end if;
      else
         while Table.Next (Before) /= Slot loop
            Before := Table.Next (Before);
         end loop;
         Table.Next (Before) := Table.Next (Slot);
         if Table.Last (Above) = Slot then
            Table.Last (Above) := Before;
         end if;
      end if;
      Table.Children (Above) := Table.Children (Above) - 1;
      Table.Semantics_Dirty (Above) := True;
   end Unlink;
   --  Take Slot out of its parent's children.

   procedure Take_Out (Item : in out Widget'Class) is
      Owner : constant Tree_Access := Item.Owner;
      Slot  : constant Node_Index := Item.Slot;
      Above : constant Node_Index := Owner.Nodes.Parent (Slot);
   begin
      Let_Go (Owner.all, Slot);
      Tell_Hidden (Owner.all, Slot);
      Invalidate (Item);
      Request_Layout (Item);
      Unlink (Owner.all, Slot);
      Yoga.Nodes.Delete (Owner.Nodes.Yoga_Node (Above), Owner.Nodes.Yoga_Node (Slot));
      Give_Back_All (Owner.all, Slot);
   end Take_Out;

   procedure Bring_Forward (Item : in out Widget'Class) is
      Table   : Node_Table renames Item.Owner.Nodes.all;
      Raising : constant Node_Index := Item.Slot;
      Above   : constant Node_Index := Table.Parent (Raising);
      Before  : Node_Index := Table.First (Above);
   begin
      if Table.Last (Above) = Raising then
         return;
      end if;
      if Before = Raising then
         Table.First (Above) := Table.Next (Raising);
      else
         while Table.Next (Before) /= Raising loop
            Before := Table.Next (Before);
         end loop;
         Table.Next (Before) := Table.Next (Raising);
      end if;
      Table.Next (Table.Last (Above)) := Raising;
      Table.Last (Above) := Raising;
      Table.Next (Raising) := 0;
      Table.Semantics_Dirty (Above) := True;
      Invalidate (Item);
   end Bring_Forward;

end Pomarine.Widgets.Lifecycle;
