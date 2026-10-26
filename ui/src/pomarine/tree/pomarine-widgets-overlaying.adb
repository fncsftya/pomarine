with Pomarine.Anchoring;
with Pomarine.Widgets.Focusing;
with Pomarine.Widgets.Lifecycle;
with Pomarine.Widgets.Nodes;
with Pomarine.Widgets.Queueing;
with Yoga.Nodes;
package body Pomarine.Widgets.Overlaying is

   use Pomarine.Anchoring;
   use Pomarine.Widgets.Nodes;
   use type Pomarine.Events.Event_Kind;
   use type Pomarine.Events.Key_Code;

   function Slot_Of (Home : Tree; Id : Node_Id) return Node_Index is
     (if Is_Live (Home, Id) then Id.Slot else 0);

   function Is_Modal_Content (Home : Tree; Slot : Node_Index) return Boolean is
   begin
      for Each of Home.Overlays (1 .. Home.Overlay_Count) loop
         if Each.How.Modal and then Each.Content.Slot = Slot and then Slot_Of (Home, Each.Content) = Slot then
            return True;
         end if;
      end loop;
      return False;
   end Is_Modal_Content;

   function Index_Of (Home : Tree; Content : Node_Id) return Natural is
   begin
      for Index in 1 .. Home.Overlay_Count loop
         if Home.Overlays (Index).Content = Content then
            return Index;
         end if;
      end loop;
      return 0;
   end Index_Of;

   procedure Push (Content : in out Widget'Class; Using : Overlay) is
      Home  : Tree renames Content.Owner.all;
      Place : Overlay := Using;
   begin
      Prune (Home);
      pragma Assert (Home.Overlay_Count < Overlay_Capacity, "more overlays than a tree can present at once");
      Place.Content := Id_Of (Content);
      Place.Applied := False;
      Place.Saved_Scope := Home.Scope;
      Place.Saved_Focus := Id_Of_Slot (Home, Home.Focus);
      Home.Overlay_Count := Home.Overlay_Count + 1;
      Home.Overlays (Home.Overlay_Count) := Place;
      Yoga.Nodes.Set_Position_Type (Node (Content), Yoga.Absolute);
      Lifecycle.Show_Or_Hide (Content, True);
      if Parent_Of (Content) /= null then
         Lifecycle.Bring_Forward (Content);
      end if;
      if not Place.How.Modal and then Is_Focusable (Content) then
         --  A menu worked by keys has the focus while it is over the rest.
         Focusing.Set_Focus (Home, Content.Slot);
      end if;
      if Place.How.Modal then
         Home.Lost := True;
         --  What is under it is drawn dimmed, all of it.
         Home.Scope := Place.Content;
         Focusing.Set_Focus (Home, 0);
         Focusing.Next_Focus (Home);
      end if;
      Request_Layout (Content);
   end Push;

   procedure Remove (Home : in out Tree; Index : Positive; Told : Boolean) is
   begin
      for Each in reverse Index .. Home.Overlay_Count loop
         declare
            Gone    : constant Overlay := Home.Overlays (Each);
            Shown   : constant Widget_Access := Resolve (Home, Gone.Content);
            Focused : constant Node_Index := Slot_Of (Home, Gone.Saved_Focus);
            Held    : constant Boolean :=
              Home.Focus /= 0 and then Focusing.Within (Home, Home.Focus, Slot_Of (Home, Gone.Content));
            --  The focus was in it.
         begin
            Home.Overlay_Count := Each - 1;
            if Shown /= null then
               Lifecycle.Show_Or_Hide (Shown.all, False);
               if Told then
                  Queueing.Enqueue (Shown.all, Dismiss);
               end if;
            end if;
            if Gone.How.Modal then
               Home.Lost := True;
               Home.Scope := (if Slot_Of (Home, Gone.Saved_Scope) /= 0 then Gone.Saved_Scope else No_Node);
            end if;
            if (Gone.How.Modal or else Held) and then Focused /= 0 and then Home.Nodes.Spot (Focused).Visible then
               Focusing.Set_Focus (Home, Focused);
            end if;
         end;
      end loop;
   end Remove;

   procedure Prune (Home : in out Tree) is
      Kept : Natural := 0;
   begin
      for Index in 1 .. Home.Overlay_Count loop
         if Slot_Of (Home, Home.Overlays (Index).Content) /= 0 then
            Kept := Kept + 1;
            Home.Overlays (Kept) := Home.Overlays (Index);
         elsif Home.Overlays (Index).How.Modal then
            Home.Scope := (if Slot_Of (Home, Home.Overlays (Index).Saved_Scope) /= 0
                           then Home.Overlays (Index).Saved_Scope else No_Node);
         end if;
      end loop;
      Home.Overlay_Count := Kept;
   end Prune;

   function Position (Home : in out Tree; Wide, High : Float) return Boolean is
      Table   : Node_Table renames Home.Nodes.all;
      Changed : Boolean := False;
   begin
      Prune (Home);
      for Index in 1 .. Home.Overlay_Count loop
         declare
            Item    : Overlay renames Home.Overlays (Index);
            Slot    : constant Node_Index := Slot_Of (Home, Item.Content);
            Anchor  : constant Node_Index :=
              (if Item.Anchor = Placed_By_Widget then Slot_Of (Home, Item.Beside) else 0);
            Margin  : constant Float := Item.Where.Margin * Home.Density;
            Gap     : constant Float := Item.Where.Gap * Home.Density;
            Cover   : Spot renames Table.Spot (Slot);
            Rim_L, Rim_T, Rim_W, Rim_H : Float := 0.0;
            --  What it is placed by, in pixels.
            Width   : Float := Cover.Wide;
            Left, Top : Float;
            Side    : Side_Kind := Item.Where.Side;

            function Along_Left (Room : Float) return Float is
              (case Item.Where.Along is
                  when Start  => Rim_L,
                  when Middle => Rim_L + (Rim_W - Room) / 2.0,
                  when Finish => Rim_L + Rim_W - Room);
            function Along_Top (Room : Float) return Float is
              (case Item.Where.Along is
                  when Start  => Rim_T,
                  when Middle => Rim_T + (Rim_H - Room) / 2.0,
                  when Finish => Rim_T + Rim_H - Room);
            function Opposite (Of_Side : Side_Kind) return Side_Kind is
              (case Of_Side is when Below => Above, when Above => Below, when After => Before, when Before => After);

            function Fits (On : Side_Kind; High_Of : Float) return Boolean is
              (case On is
                  when Below  => Rim_T + Rim_H + Gap + High_Of <= High - Margin,
                  when Above  => Rim_T - Gap - High_Of >= Margin,
                  when After  => Rim_L + Rim_W + Gap + Width <= Wide - Margin,
                  when Before => Rim_L - Gap - Width >= Margin);
         begin
            if Item.Anchor = Placed_By_Widget and then Anchor = 0 then
               Remove (Home, Index, Told => False);
               return True;
            end if;
            case Item.Anchor is
               when Placed_By_Widget =>
                  Rim_L := Table.Spot (Anchor).Left;
                  Rim_T := Table.Spot (Anchor).Top;
                  Rim_W := Table.Spot (Anchor).Wide;
                  Rim_H := Table.Spot (Anchor).High;
               when Placed_At_Point =>
                  Rim_L := Item.Point_X;
                  Rim_T := Item.Point_Y;
               when Placed_In_Middle =>
                  null;
            end case;
            if Item.Where.Match_Width and then Item.Anchor = Placed_By_Widget then
               Width := Rim_W;
            end if;
            if Item.Anchor = Placed_In_Middle then
               Left := (Wide - Width) / 2.0;
               Top := (High - Cover.High) * 0.4;
            else
               if Item.Where.Flip and then not Fits (Side, Cover.High) and then Fits (Opposite (Side), Cover.High) then
                  Side := Opposite (Side);
               end if;
               case Side is
                  when Below  => Left := Along_Left (Width); Top := Rim_T + Rim_H + Gap;
                  when Above  => Left := Along_Left (Width); Top := Rim_T - Gap - Cover.High;
                  when After  => Left := Rim_L + Rim_W + Gap; Top := Along_Top (Cover.High);
                  when Before => Left := Rim_L - Gap - Width; Top := Along_Top (Cover.High);
               end case;
            end if;
            --  Inside the window, as far as it will go.
            Left := Float'Max (Margin, Float'Min (Left, Wide - Width - Margin));
            Top := Float'Max (Margin, Float'Min (Top, High - Cover.High - Margin));
            if Item.Anchor = Placed_In_Middle then
               Left := Float'Max (0.0, Left);
               Top := Float'Max (0.0, Top);
            end if;
            declare
               Above_Left : constant Float :=
                 (if Table.Parent (Slot) = 0 then 0.0 else Table.Spot (Table.Parent (Slot)).Left);
               Above_Top  : constant Float :=
                 (if Table.Parent (Slot) = 0 then 0.0 else Table.Spot (Table.Parent (Slot)).Top);
               Across     : constant Float := Left - Above_Left;
               Down       : constant Float := Top - Above_Top;
            begin
               if not Item.Applied
                 or else abs (Across - Item.Applied_Left) >= 0.5
                 or else abs (Down - Item.Applied_Top) >= 0.5
                 or else (Item.Where.Match_Width and then abs (Width - Item.Applied_Width) >= 0.5)
               then
                  Yoga.Nodes.Set_Position (Table.Yoga_Node (Slot), Yoga.Left, Across);
                  Yoga.Nodes.Set_Position (Table.Yoga_Node (Slot), Yoga.Top, Down);
                  if Item.Where.Match_Width and then Item.Anchor = Placed_By_Widget then
                     Yoga.Nodes.Set_Width (Table.Yoga_Node (Slot), Width);
                  end if;
                  Item.Applied := True;
                  Item.Applied_Left := Across;
                  Item.Applied_Top := Down;
                  Item.Applied_Width := Width;
                  Changed := True;
               end if;
            end;
         end;
      end loop;
      return Changed;
   end Position;

   procedure Take_Input
     (Home     : in out Tree;
      Event    : Pomarine.Events.Event;
      Over     : Node_Index;
      Consumed : out Boolean)
   is
   begin
      Consumed := False;
      Prune (Home);
      if Home.Overlay_Count = 0 then
         return;
      end if;
      declare
         Top     : constant Positive := Home.Overlay_Count;
         Mine    : constant Overlay := Home.Overlays (Top);
         Content : constant Node_Index := Slot_Of (Home, Mine.Content);
         Pointer : constant Boolean :=
           Event.Kind in Pomarine.Events.Mouse_Down | Pomarine.Events.Mouse_Up | Pomarine.Events.Mouse_Move
                         | Pomarine.Events.Mouse_Wheel | Pomarine.Events.Pinch;
      begin
         if Event.Kind = Pomarine.Events.Key_Down then
            if Event.Key = Pomarine.Events.Key_Escape and then Mine.How.Escape then
               Remove (Home, Top, Told => True);
               Consumed := True;
            end if;
            return;
         end if;
         if not Pointer then
            return;
         end if;
         if Event.Kind = Pomarine.Events.Mouse_Down
           and then not Focusing.Within (Home, Over, Content)
           and then Mine.How.Outside_Click
         then
            declare
               On_Anchor : constant Boolean :=
                 Mine.Anchor = Placed_By_Widget
                 and then Focusing.Within (Home, Over, Slot_Of (Home, Mine.Beside));
               Passing   : constant Boolean := Mine.How.Pass_Through and then not On_Anchor and then not Mine.How.Modal;
            begin
               Remove (Home, Top, Told => True);
               Consumed := not Passing;
            end;
         end if;
         --  A modal overlay (the topmost still presented) takes what is outside it.
         if not Consumed then
            for Index in reverse 1 .. Home.Overlay_Count loop
               if Home.Overlays (Index).How.Modal then
                  declare
                     Holding : constant Node_Index := Slot_Of (Home, Home.Overlays (Index).Content);
                  begin
                     if Home.Capture = 0 and then not Focusing.Within (Home, Over, Holding) then
                        if Event.Kind = Pomarine.Events.Mouse_Move then
                           Focusing.Set_Hover (Home, 0);
                        end if;
                        Consumed := True;
                     end if;
                  end;
                  exit;
               end if;
            end loop;
         end if;
      end;
   end Take_Input;

end Pomarine.Widgets.Overlaying;
