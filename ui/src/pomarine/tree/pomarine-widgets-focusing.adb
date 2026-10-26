with Pomarine.Widgets.Nodes;
package body Pomarine.Widgets.Focusing is

   use Pomarine.Widgets.Nodes;

   procedure Set_Focus (Item : in out Tree; To : Node_Index) is
      Was : constant Node_Index := Item.Focus;
   begin
      if To /= Was then
         Item.Focus := To;
         if Was /= 0 then
            Item.Nodes.Focused (Was) := False;
            Item.Nodes.Semantics_Dirty (Was) := True;
            Focus_Changed (Item.Nodes.Object (Was).all, False);
            --  Said only to a handler of its own, or every change would be.
            if Has_Hook (Item.Nodes.Object (Was).all, Blur) then
               Notify (Item.Nodes.Object (Was).all, Blur);
            end if;
         end if;
         if To /= 0 then
            Item.Nodes.Focused (To) := True;
            Item.Nodes.Semantics_Dirty (To) := True;
            Focus_Changed (Item.Nodes.Object (To).all, True);
         end if;
      end if;
   end Set_Focus;

   function Is_Taker (Item : Tree; Slot : Node_Index) return Boolean is
     (Item.Nodes.Spot (Slot).Visible and then Accepts_Focus (Item.Nodes.Object (Slot).all));
   --  Whether Slot is one the focus may go to.

   procedure Next_Focus (Item : in out Tree; Backwards : Boolean := False) is
      Scoped  : constant Boolean := Is_Live (Item, Item.Scope);
      Walking : Node_Index := (if Scoped then Item.Scope.Slot else Item.Root);
      First   : Node_Index := 0;
      Last    : Node_Index := 0;
      Before  : Node_Index := 0;
      After   : Node_Index := 0;
      Passed  : Boolean := False;
      --  Whether the walk is past the widget that has the focus.
   begin
      if Item.Root = 0 then
         return;
      end if;
      while Walking /= 0 and then (not Scoped or else Within (Item, Walking, Item.Scope.Slot)) loop
         if Walking = Item.Focus then
            Passed := True;
         elsif Is_Taker (Item, Walking) then
            if First = 0 then
               First := Walking;
            end if;
            Last := Walking;
            if Passed then
               if After = 0 then
                  After := Walking;
               end if;
            else
               Before := Walking;
            end if;
         end if;
         Walking := Following_Shown (Item, Walking);
      end loop;
      if Backwards then
         Set_Focus (Item, (if Before /= 0 then Before else Last));
      else
         Set_Focus (Item, (if After /= 0 then After else First));
      end if;
      Deliver (Item);
   end Next_Focus;

   function Within (Item : Tree; Slot, Inside : Node_Index) return Boolean is
      Climbing : Node_Index := Slot;
   begin
      while Climbing /= 0 loop
         if Climbing = Inside then
            return True;
         end if;
         Climbing := Item.Nodes.Parent (Climbing);
      end loop;
      return False;
   end Within;

   procedure Set_Hover (Item : in out Tree; To : Node_Index) is
      Was      : constant Node_Index := Item.Hover;
      Climbing : Node_Index;
   begin
      if To = Was then
         return;
      end if;
      Item.Hover := To;
      --  Those the pointer has left, and then those it has come over: not
      --  those it moved between.
      Climbing := Was;
      while Climbing /= 0 loop
         if not Within (Item, To, Climbing) then
            Item.Nodes.Hovered (Climbing) := False;
            Hover_Changed (Item.Nodes.Object (Climbing).all, False);
         end if;
         Climbing := Item.Nodes.Parent (Climbing);
      end loop;
      Climbing := To;
      while Climbing /= 0 loop
         if not Item.Nodes.Hovered (Climbing) then
            Item.Nodes.Hovered (Climbing) := True;
            Hover_Changed (Item.Nodes.Object (Climbing).all, True);
         end if;
         Climbing := Item.Nodes.Parent (Climbing);
      end loop;
   end Set_Hover;

end Pomarine.Widgets.Focusing;
