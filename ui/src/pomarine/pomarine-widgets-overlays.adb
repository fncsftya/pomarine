with Pomarine.Widgets.Overlaying;

package body Pomarine.Widgets.Overlays is

   function Is_Presented (Content : Widget'Class) return Boolean
   is (Is_Attached (Content) and then Overlaying.Index_Of (Content.Owner.all, Id_Of (Content)) /= 0);

   function Presented_Count (Home : Tree) return Natural is
      Live : Natural := 0;
   begin
      for Each of Home.Overlays (1 .. Home.Overlay_Count) loop
         if Overlaying.Slot_Of (Home, Each.Content) /= 0 then
            Live := Live + 1;
         end if;
      end loop;
      return Live;
   end Presented_Count;

   procedure Overlap (Home : Tree; Within : Area; Hole : out Area; Modal : out Boolean) is
      Right  : Float := 0.0;
      Bottom : Float := 0.0;
      Found  : Boolean := False;
   begin
      Hole := (others => <>);
      Modal := False;
      for Each of Home.Overlays (1 .. Home.Overlay_Count) loop
         declare
            Slot : constant Node_Index := Overlaying.Slot_Of (Home, Each.Content);
         begin
            if Slot /= 0 then
               Modal := Modal or else Each.How.Modal;
               declare
                  Box : Spot renames Home.Nodes.Spot (Slot);
               begin
                  if Box.Left < Within.Left + Within.Wide
                    and then Within.Left < Box.Left + Box.Wide
                    and then Box.Top < Within.Top + Within.High
                    and then Within.Top < Box.Top + Box.High
                  then
                     if not Found then
                        Hole.Left := Box.Left;
                        Hole.Top := Box.Top;
                        Right := Box.Left + Box.Wide;
                        Bottom := Box.Top + Box.High;
                        Found := True;
                     else
                        Hole.Left := Float'Min (Hole.Left, Box.Left);
                        Hole.Top := Float'Min (Hole.Top, Box.Top);
                        Right := Float'Max (Right, Box.Left + Box.Wide);
                        Bottom := Float'Max (Bottom, Box.Top + Box.High);
                     end if;
                  end if;
               end;
            end if;
         end;
      end loop;
      if Found then
         Hole.Wide := Right - Hole.Left;
         Hole.High := Bottom - Hole.Top;
      end if;
   end Overlap;

   procedure Present_Beside
     (Content : in out Widget'Class;
      Anchor  : Widget'Class;
      Where   : Anchoring.Placement := (others => <>);
      How     : Anchoring.Behavior := Anchoring.Light_Dismiss) is
   begin
      Overlaying.Push
        (Content, (Anchor => Placed_By_Widget, Beside => Id_Of (Anchor), Where => Where, How => How, others => <>));
   end Present_Beside;

   procedure Present_At
     (Content : in out Widget'Class;
      X, Y    : Float;
      Where   : Anchoring.Placement := Pointer_Placement;
      How     : Anchoring.Behavior := Anchoring.Light_Dismiss) is
   begin
      Overlaying.Push
        (Content,
         (Anchor  => Placed_At_Point,
          Point_X => X * Content.Owner.Density,
          Point_Y => Y * Content.Owner.Density,
          Where   => Where,
          How     => How,
          others  => <>));
   end Present_At;

   procedure Present_Centered (Content : in out Widget'Class; How : Anchoring.Behavior := Anchoring.Dialog) is
   begin
      Overlaying.Push (Content, (Anchor => Placed_In_Middle, How => How, others => <>));
   end Present_Centered;

   procedure Dismiss (Content : in out Widget'Class) is
      Index : constant Natural := Overlaying.Index_Of (Content.Owner.all, Id_Of (Content));
   begin
      if Index /= 0 then
         Overlaying.Remove (Content.Owner.all, Index, Told => False);
      end if;
   end Dismiss;

   procedure Dismiss_All (Home : in out Tree) is
   begin
      if Home.Overlay_Count > 0 then
         Overlaying.Remove (Home, 1, Told => False);
      end if;
   end Dismiss_All;

end Pomarine.Widgets.Overlays;
