with Ada.Strings.Fixed;
with SDL3.Windows.Renderers;
with Goldens;
with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Embeds.Callbacks;
with Pomarine.Widgets.Layouts;
with Pomarine.Widgets.Overlays;
with Pomarine.Widgets.Panels;

package body Embed_Tests is

   package Widgets renames Pomarine.Widgets;
   package Embeds renames Pomarine.Widgets.Embeds;
   package Layouts renames Pomarine.Widgets.Layouts;
   package Overlays renames Pomarine.Widgets.Overlays;
   package Buttons renames Pomarine.Widgets.Buttons;
   package Panels renames Pomarine.Widgets.Panels;
   package Renderers renames SDL3.Windows.Renderers;

   function Image (Value : Integer) return String
   is (Ada.Strings.Fixed.Trim (Integer'Image (Value), Ada.Strings.Left));

   function Image (Value : Boolean) return String
   is (if Value then "yes" else "no");

   --  What the system's view would do, as far as it is told.

   type Recorder is limited new Embeds.Host with record
      Left, Top, Wide, High : Integer := -1;
      Showing               : Boolean := False;
      Placements            : Natural := 0;
      Keyboard              : Boolean := False;
      Pressed               : Natural := 0;
   end record;

   overriding
   procedure Place (Self : in out Recorder; Left, Top, Wide, High : Float; Showing : Boolean);

   overriding
   procedure Give_Keyboard (Self : in out Recorder; To_View : Boolean);

   overriding
   function Has_Keyboard (Self : Recorder) return Boolean;

   overriding
   function Shortcut (Self : in out Recorder) return Natural;

   overriding
   procedure Place (Self : in out Recorder; Left, Top, Wide, High : Float; Showing : Boolean) is
   begin
      Self.Left := Integer (Left);
      Self.Top := Integer (Top);
      Self.Wide := Integer (Wide);
      Self.High := Integer (High);
      Self.Showing := Showing;
      Self.Placements := Self.Placements + 1;
   end Place;

   overriding
   procedure Give_Keyboard (Self : in out Recorder; To_View : Boolean) is
   begin
      Self.Keyboard := To_View;
   end Give_Keyboard;

   overriding
   function Has_Keyboard (Self : Recorder) return Boolean
   is (Self.Keyboard);

   overriding
   function Shortcut (Self : in out Recorder) return Natural is
      Number : constant Natural := Self.Pressed;
   begin
      Self.Pressed := 0;
      return Number;
   end Shortcut;

   type Fixture is limited record
      Tree   : Widgets.Tree;
      Target : Renderers.Renderer;
      Root   : aliased Panels.Panel;
      Page   : aliased Embeds.Embed;
      Other  : aliased Buttons.Button;
      Menu   : aliased Panels.Panel;
      View   : aliased Recorder;
      Heard  : Natural := 0;
   end record;

   procedure Open (Item : in out Fixture) is
   begin
      Renderers.Create_Offscreen (Item.Target, 400, 300);
      Widgets.Set_Root (Item.Tree, Item.Root);
      Widgets.Add (Item.Root, Item.Page, Item.Other, Item.Menu);
      Layouts.Set_Layout
        (Item.Page,
         Width    => Layouts.In_Points (300.0),
         Height   => Layouts.In_Points (200.0),
         Place    => Layouts.Absolute,
         Position => (Left => Layouts.In_Points (40.0), Top => Layouts.In_Points (50.0), others => <>));
      Layouts.Set_Layout
        (Item.Other,
         Width    => Layouts.In_Points (60.0),
         Height   => Layouts.In_Points (30.0),
         Place    => Layouts.Absolute,
         Position => (Left => Layouts.In_Points (0.0), Top => Layouts.In_Points (0.0), others => <>));
      Layouts.Set_Layout
        (Item.Menu,
         Width    => Layouts.In_Points (100.0),
         Height   => Layouts.In_Points (40.0),
         Place    => Layouts.Absolute,
         Position => (others => <>));
      Buttons.Set_Focusable (Item.Other, True);
      Item.Page.Set_Host (Item.View'Unchecked_Access);
      Widgets.Layout (Item.Tree, Item.Target);
      Widgets.Update (Item.Tree, 1000);
   end Open;

   procedure Placing is
      Item : Fixture;
   begin
      Open (Item);
      Goldens.Check_Text
        ("embed-placed",
         "40 50 300 200 yes",
         Image (Item.View.Left)
         & " "
         & Image (Item.View.Top)
         & " "
         & Image (Item.View.Wide)
         & " "
         & Image (Item.View.High)
         & " "
         & Image (Item.View.Showing));

      --  Nothing changed, nothing told.
      declare
         Before : constant Natural := Item.View.Placements;
      begin
         Widgets.Update (Item.Tree, 1100);
         Widgets.Update (Item.Tree, 1200);
         Goldens.Check_Text ("embed-quiet", "yes", Image (Item.View.Placements = Before));
      end;

      --  Hidden, it is not shown.
      Widgets.Set_Visible (Item.Page, False);
      Widgets.Update (Item.Tree, 1300);
      Goldens.Check_Text ("embed-hidden", "no", Image (Item.View.Showing));
      Widgets.Set_Visible (Item.Page, True);
      Widgets.Update (Item.Tree, 1400);
      Goldens.Check_Text ("embed-shown-again", "yes", Image (Item.View.Showing));
   end Placing;

   procedure Hiding_Under_Overlays is
      Item : Fixture;
   begin
      Open (Item);
      Overlays.Present_Centered (Item.Menu);
      Widgets.Update (Item.Tree, 1100);
      Goldens.Check_Text ("embed-under-overlay", "no", Image (Item.View.Showing));
      Overlays.Dismiss (Item.Menu);
      Widgets.Update (Item.Tree, 1200);
      Goldens.Check_Text ("embed-after-overlay", "yes", Image (Item.View.Showing));
   end Hiding_Under_Overlays;

   procedure Keyboard is
      Item : Fixture;
   begin
      Open (Item);

      --  A press in the view gives it the keyboard, which the tree is not told of: the widget notices.
      Item.View.Keyboard := True;
      Widgets.Update (Item.Tree, 1100);
      Goldens.Check_Text ("embed-focused", "yes", Image (Widgets.Has_Focus (Item.Page)));

      --  Another widget is given the focus: the view lets go of the keyboard.
      Widgets.Focus (Item.Other);
      Goldens.Check_Text
        ("embed-keyboard-back", "no no", Image (Item.View.Keyboard) & " " & Image (Widgets.Has_Focus (Item.Page)));

      --  An overlay over it takes the keyboard from it too.
      Item.View.Keyboard := True;
      Widgets.Update (Item.Tree, 1200);
      Overlays.Present_Centered (Item.Menu);
      Widgets.Update (Item.Tree, 1300);
      Goldens.Check_Text ("embed-overlay-keyboard", "no", Image (Item.View.Keyboard));
   end Keyboard;

   procedure Asked (Self : in out Fixture; Source : in out Embeds.Embed'Class; Which : Positive) is
      pragma Unreferenced (Source);
   begin
      Self.Heard := Which;
   end Asked;

   package Hearing is new Embeds.Callbacks (Fixture);

   procedure Shortcuts is
      Item : Fixture;
   begin
      Open (Item);
      Hearing.On_Shortcut (Item.Page, Item'Unrestricted_Access, Asked'Access);
      Item.View.Keyboard := True;
      Widgets.Update (Item.Tree, 1100);
      Item.View.Pressed := 3;
      Widgets.Update (Item.Tree, 1200);
      Widgets.Update (Item.Tree, 1300);
      Goldens.Check_Text
        ("embed-shortcut",
         "3 no",
         Image (Item.Heard) & " " & Image (Item.View.Keyboard));
   end Shortcuts;

end Embed_Tests;
