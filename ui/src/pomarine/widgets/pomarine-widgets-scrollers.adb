with Yoga.Nodes;
package body Pomarine.Widgets.Scrollers is

   use type Semantics.Role;

   use type SDL3.Events.Event_Kind;

   function Offset (Item : Scroller) return Float is (Item.Moved);

   function Bar_Metrics (Item : Scroller) return Scrollbars.Metrics is
     (Left    => Left_Of (Item), Top => Top_Of (Item),
      Width   => Width_Of (Item), Height => Height_Of (Item),
      Density => Density (Item),
      Start   => Item.Moved * Density (Item),
      Shown   => (if Item.Across then Width_Of (Item) else Height_Of (Item)),
      Total   => (if Child_Count (Item) /= 1 then 0.0
                  elsif Item.Across then Width_Of (Child_At (Item, 1).all)
                  else Height_Of (Child_At (Item, 1).all)),
      Horizontal => Item.Across);

   procedure Set_Across (Item : in out Scroller; Across : Boolean) is
   begin
      Item.Across := Across;
   end Set_Across;

   procedure Scroll_To (Item : in out Scroller; To : Float) is
      Child  : constant Widget_Access := Child_At (Item, 1);
      Pixels : constant Float := Density (Item);
      Hidden : constant Float :=
        Float'Max
          (0.0,
           (if Item.Across
            then Width_Of (Child.all) - Width_Of (Item)
            else Height_Of (Child.all) - Height_Of (Item)) / Pixels);
      --  How much of the child is out of the box.
      Wanted : constant Float := Float'Min (Hidden, Float'Max (0.0, To));
   begin
      if Wanted /= Item.Moved then
         Item.Moved := Wanted;
         Yoga.Nodes.Set_Position
           (Node (Child.all), (if Item.Across then Yoga.Left else Yoga.Top),
            -Wanted * Pixels);
         Request_Layout (Item);
      end if;
   end Scroll_To;

   procedure Offset_Step (Item : in out Widget'Class; Value : Float);

   procedure Offset_Step (Item : in out Widget'Class; Value : Float) is
   begin
      if Child_Count (Item) = 1 then
         Scroll_To (Scroller (Item), Value);
      end if;
   end Offset_Step;

   procedure Scroll_Smoothly (Item : in out Scroller; To : Float; Milliseconds : Natural := 180) is
   begin
      Animate (Item, Item.Moved, To, Milliseconds, Ease_Out, Offset_Step'Access);
   end Scroll_Smoothly;

   overriding procedure Draw_Over
     (Item   : in out Scroller;
      Target : SDL3.Painters.Painter'Class;
      Colors : Themes.Theme) is
   begin
      if Child_Count (Item) = 1 then
         Scrollbars.Draw (Item.Bar, Target, Colors, Bar_Metrics (Item));
      end if;
   end Draw_Over;

   overriding procedure Hover_Changed
     (Item : in out Scroller; Hovered : Boolean) is
   begin
      Scrollbars.Set_Pane (Item.Bar, Hovered);
      Invalidate (Item);
   end Hover_Changed;

   overriding procedure Handle
     (Item    : in out Scroller;
      Event   : SDL3.Events.Event;
      Handled : out Boolean) is
   begin
      Handled := False;
      if Child_Count (Item) = 1
        and then Event.Kind in SDL3.Events.Mouse_Down
                             | SDL3.Events.Mouse_Move
                             | SDL3.Events.Mouse_Up
      then
         declare
            Moved, Changed : Boolean;
            To : Float;
         begin
            Scrollbars.Handle
              (Item.Bar, Event, Bar_Metrics (Item), Handled, Moved, To,
               Changed);
            if Moved then
               Scroll_To (Item, To / Density (Item));
            end if;
            if Changed or else Moved then
               Invalidate (Item);
            end if;
            if Handled then
               return;
            end if;
         end;
      end if;
      if Event.Kind = SDL3.Events.Mouse_Wheel
        and then Child_Count (Item) = 1
      then
         Scroll_To
           (Item,
            Item.Moved
            - (if Item.Across and then Event.Wheel_X /= 0.0
               then Event.Wheel_X else Event.Wheel_Y) * Points_Per_Notch);
         Handled := True;
      end if;
   end Handle;

   overriding procedure Describe
     (Item  : Scroller;
      Facts : in out Semantics.Description) is
   begin
      if Facts.Kind = Semantics.Unknown then
         Facts.Kind := Semantics.Scroll_View;
      end if;
      Facts.Actions (Semantics.Scroll_Up) := not Item.Across;
      Facts.Actions (Semantics.Scroll_Down) := not Item.Across;
      Facts.Actions (Semantics.Scroll_Left) := Item.Across;
      Facts.Actions (Semantics.Scroll_Right) := Item.Across;
   end Describe;

   overriding procedure Perform
     (Item    : in out Scroller;
      Request : Semantics.Request;
      Done    : out Boolean)
   is
      Page : constant Float := 0.9 * (if Item.Across then Width_Of (Item) else Height_Of (Item))
        / Density (Item);
   begin
      Done := Child_Count (Item) = 1;
      if not Done then
         return;
      end if;
      case Request.Doing is
         when Semantics.Scroll_Up | Semantics.Scroll_Left =>
            Scroll_Smoothly (Item, Item.Moved - Page);
         when Semantics.Scroll_Down | Semantics.Scroll_Right =>
            Scroll_Smoothly (Item, Item.Moved + Page);
         when others =>
            Done := False;
      end case;
   end Perform;

end Pomarine.Widgets.Scrollers;
