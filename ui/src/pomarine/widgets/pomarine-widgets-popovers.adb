with Pomarine.Widgets.Overlays;
package body Pomarine.Widgets.Popovers is

   procedure Add
     (Parent : in out Widget'Class;
      Item   : in out Popover;
      Width  : Layouts.Length := 240.0) is
   begin
      Panels.Set_Fill (Panels.Panel (Item), Themes.Page);
      Panels.Set_Border (Panels.Panel (Item), Themes.Border);
      Panels.Set_Shadow (Panels.Panel (Item), Themes.Drop_Shadow);
      Panels.Set_Radius (Panels.Panel (Item), Themes.Small_Radius);
      Layouts.Add
        (Parent, Item,
         (Flow => Layouts.Column, Width => Width, Padding => (others => 8.0), Gap => 6.0,
          Outlined => Layouts.On, Shadowed => Layouts.On, Place => Layouts.Absolute, others => <>));
      Set_Visible (Item, False);
   end Add;

   procedure Show_Beside
     (Item   : in out Popover;
      Anchor : Widget'Class;
      Where  : Pomarine.Anchoring.Placement := (others => <>);
      How    : Pomarine.Anchoring.Behavior := Pomarine.Anchoring.Light_Dismiss) is
   begin
      Overlays.Present_Beside (Item, Anchor, Where, How);
   end Show_Beside;

   procedure Show_At
     (Item  : in out Popover;
      X, Y  : Float;
      Where : Pomarine.Anchoring.Placement := (Gap => 12.0, others => <>);
      How   : Pomarine.Anchoring.Behavior := Pomarine.Anchoring.Light_Dismiss) is
   begin
      Overlays.Present_At (Item, X, Y, Where, How);
   end Show_At;

   procedure Hide (Item : in out Popover) is
   begin
      Overlays.Dismiss (Item);
   end Hide;

   function Is_Shown (Item : Popover) return Boolean is (Overlays.Is_Presented (Item));

end Pomarine.Widgets.Popovers;
