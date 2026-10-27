with Pomarine.Widgets.Nodes;
with Pomarine.Widgets.Overlaying;

package body Pomarine.Widgets.Tipping is

   use Pomarine.Widgets.Nodes;
   use type Pomarine.Events.Milliseconds;

   function Tipped (Home : Tree; From : Node_Index) return Node_Index is
      --  The widget under the pointer, or the nearest of those it is in that has a tooltip; 0 if none.
      Climbing : Node_Index := From;
   begin
      while Climbing /= 0 loop
         if Tooltip_Of (Home.Nodes.Object (Climbing).all) /= "" then
            return Climbing;
         end if;
         Climbing := Home.Nodes.Parent (Climbing);
      end loop;
      return 0;
   end Tipped;

   procedure Let_Go (Home : in out Tree) is
      Shown : constant Widget_Access := Resolve (Home, Home.Tip_Id);
      Index : constant Natural := Overlaying.Index_Of (Home, Home.Tip_Id);
   begin
      if Home.Tip_Shown and then Shown /= null and then Index /= 0 then
         Overlaying.Remove (Home, Index, Told => False);
      end if;
      Home.Tip_Shown := False;
   end Let_Go;

   procedure Step (Home : in out Tree; Now : Pomarine.Events.Milliseconds) is
   begin
      if Home.Tip_Present = null or else not Is_Live (Home, Home.Tip_Id) then
         return;
      end if;
      declare
         Over    : constant Node_Index := Tipped (Home, Home.Hover);
         Over_Id : constant Node_Id := Id_Of_Slot (Home, Over);
      begin
         if Over_Id /= Home.Tip_Over then
            Let_Go (Home);
            Home.Tip_Over := Over_Id;
            Home.Tip_Since := Now;
            Home.Tip_Quiet := False;
         elsif Over /= 0
           and then not Home.Tip_Shown
           and then not Home.Tip_Quiet
           and then Now - Home.Tip_Since >= Pomarine.Events.Milliseconds (Home.Tip_Delay)
         then
            declare
               Anchor : constant Widget_Access := Home.Nodes.Object (Over);
               Tip    : constant Widget_Access := Resolve (Home, Home.Tip_Id);
            begin
               Home.Tip_Present (Tip.all, Tooltip_Of (Anchor.all), Anchor.all);
               Home.Tip_Shown := True;
            end;
         end if;
      end;
   end Step;

   function Wait (Home : Tree) return Integer is
   begin
      if Home.Tip_Present = null
        or else Home.Tip_Over = No_Node
        or else Home.Tip_Shown
        or else Home.Tip_Quiet
        or else not Is_Live (Home, Home.Tip_Id)
      then
         return -1;
      end if;
      return Integer'Max (0, Home.Tip_Delay - Integer (Home.Clock - Home.Tip_Since));
   end Wait;

   procedure Pressed (Home : in out Tree) is
   begin
      if Home.Tip_Present = null then
         return;
      end if;
      Let_Go (Home);
      Home.Tip_Quiet := True;
   end Pressed;

end Pomarine.Widgets.Tipping;
