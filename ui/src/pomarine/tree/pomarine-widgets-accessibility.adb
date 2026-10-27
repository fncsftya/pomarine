with Pomarine.Widgets.Focusing;
with Pomarine.Widgets.Nodes;

package body Pomarine.Widgets.Accessibility is

   use Pomarine.Widgets.Focusing;
   use Pomarine.Widgets.Nodes;

   function Is_Told (Home : Tree; Slot : Node_Index) return Boolean
   is (Home.Nodes.Spot (Slot).Visible and then not Home.Nodes.Object (Slot).Hidden_From_AT);
   --  Whether an assistive technology is to hear of Slot: not if it, or
   --  what it is in, is hidden.

   procedure Forget (Home : in out Tree; Slot : Node_Index) is
      Child : Node_Index := Home.Nodes.First (Slot);
   begin
      Home.Nodes.Known (Slot) := False;
      while Child /= 0 loop
         Forget (Home, Child);
         Child := Home.Nodes.Next (Child);
      end loop;
   end Forget;
   --  Slot, and all in it, are no longer known to an assistive technology.

   procedure Tell (Home : in out Tree; Slot : Node_Index; Into : in out Semantic_Sink'Class; Whole : Boolean) is
      Table : Node_Table renames Home.Nodes.all;
      Mine  : constant Widget_Access := Table.Object (Slot);
      Shown : Natural := 0;
      Child : Node_Index := Table.First (Slot);
   begin
      --  Those it is to hear of, in order. The scratch is this level's
      --  alone: it is used up before the next is begun.
      while Child /= 0 loop
         if Is_Told (Home, Child) then
            Shown := Shown + 1;
            Table.Kids (Shown) := Id_Of_Slot (Home, Child);
         else
            Forget (Home, Child);
         end if;
         Child := Table.Next (Child);
      end loop;
      declare
         Parts : constant Natural := Part_Count (Mine.all);
      begin
         pragma Assert (Shown + Parts <= Node_Capacity);
         for Index in 1 .. Parts loop
            Shown := Shown + 1;
            Table.Kids (Shown) := Part_Id (Mine.all, Part_Number (Mine.all, Index));
         end loop;
      end;

      if Whole or else not Table.Known (Slot) or else Table.Semantics_Dirty (Slot) then
         declare
            Facts  : Semantics.Description;
            Box    : Semantics.Rectangle;
            Points : constant Float := Home.Density;
            Where  : Spot renames Table.Spot (Slot);
         begin
            Facts.Kind := Mine.Said_Role;
            Describe (Mine.all, Facts);
            if Slot = Home.Root and then Facts.Kind in Semantics.Unknown | Semantics.Group then
               Facts.Kind := Semantics.Window;
            end if;
            if Mine.Cold /= 0 and then Semantics.Length (Block (Mine.Cold).all.Name) > 0 then
               Facts.Name := Block (Mine.Cold).all.Name;
            elsif Slot = Home.Root and then Semantics.Length (Home.Title) > 0 then
               Facts.Name := Home.Title;
            end if;
            if Mine.Cold /= 0 and then Semantics.Length (Block (Mine.Cold).all.Help) > 0 then
               Facts.Help := Block (Mine.Cold).all.Help;
            end if;
            if Table.Focused (Slot) then
               Facts.Focusable := True;
            end if;
            Box :=
              (Left   => Where.Left / Points,
               Top    => Where.Top / Points,
               Right  => (Where.Left + Where.Wide) / Points,
               Bottom => (Where.Top + Where.High) / Points);
            Describe_Node (Into, Id_Of_Slot (Home, Slot), Facts, Box, Table.Kids (1 .. Shown));
            for Index in 1 .. Part_Count (Mine.all) loop
               declare
                  Number : constant Positive := Part_Number (Mine.all, Index);
                  Inner  : Semantics.Description;
                  Inside : Semantics.Rectangle;
               begin
                  Describe_Part (Mine.all, Number, Inner, Inside);
                  Describe_Node
                    (Into,
                     Part_Id (Mine.all, Number),
                     Inner,
                     (Left   => Inside.Left / Points,
                      Top    => Inside.Top / Points,
                      Right  => Inside.Right / Points,
                      Bottom => Inside.Bottom / Points),
                     Node_Id_Array'(1 .. 0 => No_Node));
               end;
            end loop;
            Table.Known (Slot) := True;
            Table.Semantics_Dirty (Slot) := False;
         end;
      end if;

      Child := Table.First (Slot);
      while Child /= 0 loop
         if Is_Told (Home, Child) then
            Tell (Home, Child, Into, Whole);
         end if;
         Child := Table.Next (Child);
      end loop;
   end Tell;

   function Is_Reachable (Home : Tree; Slot : Node_Index) return Boolean is
      Climbing : Node_Index := Slot;
   begin
      while Climbing /= 0 loop
         if not Is_Told (Home, Climbing) then
            return False;
         end if;
         Climbing := Home.Nodes.Parent (Climbing);
      end loop;
      return True;
   end Is_Reachable;
   --  Whether an assistive technology can come to Slot: it and all it is in
   --  are to be told of.

   procedure Tell_Changes (Item : in out Tree; Into : in out Semantic_Sink'Class; Whole : Boolean := False) is
      Everything : constant Boolean := Whole or else Item.Whole_Next;
      Focused    : constant Node_Id :=
        (if Item.Focus /= 0 and then Is_Reachable (Item, Item.Focus)
         then Id_Of_Slot (Item, Item.Focus)
         else Root_Id (Item));
   begin
      if Everything then
         Forget (Item, Item.Root);
      end if;
      Begin_Update (Into, Root_Id (Item), Focused, Everything);
      Tell (Item, Item.Root, Into, Everything);
      End_Update (Into);
      Item.Whole_Next := False;
   end Tell_Changes;

   procedure Perform_On (Item : in out Tree; Id : Node_Id; Request : Semantics.Request; Done : out Boolean) is
      Target : constant Widget_Access := Resolve (Item, Id);
   begin
      Done := False;
      if Target = null or else not Is_Reachable (Item, Id.Slot) then
         return;
      end if;
      if Id.Part /= 0 then
         Perform_Part (Target.all, Id.Part, Request, Done);
         Deliver (Item);
         return;
      end if;
      case Request.Doing is
         when Semantics.Focus =>
            if Is_Focusable (Target.all) then
               Set_Focus (Item, Id.Slot);
               Done := True;
            else
               Perform (Target.all, Request, Done);
            end if;

         when Semantics.Blur  =>
            if Item.Nodes.Focused (Id.Slot) then
               Set_Focus (Item, 0);
            end if;
            Done := True;

         when others          =>
            Perform (Target.all, Request, Done);
      end case;
      Deliver (Item);
   end Perform_On;

end Pomarine.Widgets.Accessibility;
