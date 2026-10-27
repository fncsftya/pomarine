with Ada.Strings.Fixed;
with Pomarine.Events;
with SDL3.Windows.Renderers;
with Goldens;
with Hearers;
with Pomarine.Anchoring;
with Pomarine.Themes;
with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Layouts;
with Pomarine.Widgets.Overlays;
with Pomarine.Widgets.Panels;

package body Overlay_Tests is

   package Widgets renames Pomarine.Widgets;
   package Events renames Pomarine.Events;
   package Layouts renames Pomarine.Widgets.Layouts;
   package Overlays renames Pomarine.Widgets.Overlays;
   package Buttons renames Pomarine.Widgets.Buttons;
   package Panels renames Pomarine.Widgets.Panels;
   package Renderers renames SDL3.Windows.Renderers;
   package Anchoring renames Pomarine.Anchoring;

   use type Widgets.Widget_Access;

   Window_Wide : constant := 400;
   Window_High : constant := 300;

   type Fixture is limited record
      Tree    : Widgets.Tree;
      Target  : Renderers.Renderer;
      Root    : aliased Panels.Panel;
      Anchor  : aliased Buttons.Button;
      Behind  : aliased Buttons.Button;
      Content : aliased Panels.Panel;
      Inner   : aliased Buttons.Button;
      Second  : aliased Panels.Panel;
      Ears    : aliased Hearers.Hearer;
   end record;

   function Image (Value : Integer) return String
   is (Ada.Strings.Fixed.Trim (Integer'Image (Value), Ada.Strings.Left));

   procedure Put (Item : in out Widgets.Widget'Class; Left, Top, Wide, High : Float) is
   begin
      Layouts.Set_Layout
        (Item,
         Width    => Layouts.In_Points (Wide),
         Height   => Layouts.In_Points (High),
         Place    => Layouts.Absolute,
         Position => (Left => Layouts.In_Points (Left), Top => Layouts.In_Points (Top), others => <>));
   end Put;

   procedure Open (Item : in out Fixture; Anchor_Left : Float := 20.0; Anchor_Top : Float := 20.0) is
   begin
      Renderers.Create_Offscreen (Item.Target, Window_Wide, Window_High);
      Widgets.Set_Listener (Item.Tree, Item.Ears'Unchecked_Access);
      Widgets.Set_Root (Item.Tree, Item.Root);
      Widgets.Add (Item.Root, Item.Anchor, Item.Behind, Item.Content);
      Widgets.Add (Item.Content, Item.Inner);
      Widgets.Add (Item.Root, Item.Second);
      Buttons.Set_Label (Item.Anchor, "Anchor");
      Buttons.Set_Label (Item.Behind, "Behind");
      Buttons.Set_Label (Item.Inner, "Inner");
      Put (Item.Anchor, Anchor_Left, Anchor_Top, 80.0, 30.0);
      Put (Item.Behind, 250.0, 150.0, 80.0, 30.0);
      Put (Item.Content, 0.0, 0.0, 120.0, 60.0);
      Put (Item.Second, 0.0, 0.0, 60.0, 40.0);
      Layouts.Set_Layout (Item.Inner, Width => 100.0, Height => 30.0, Margin => (others => 4.0));
      Buttons.Set_Focusable (Item.Anchor, True);
      Buttons.Set_Focusable (Item.Behind, True);
      Buttons.Set_Focusable (Item.Inner, True);
      Widgets.Set_Tag (Item.Behind, 7);
      Widgets.Set_Tag (Item.Anchor, 8);
      Widgets.Set_Visible (Item.Content, False);
      Widgets.Set_Visible (Item.Second, False);
      Widgets.Layout (Item.Tree, Item.Target);
   end Open;

   function Where (Item : Widgets.Widget'Class) return String
   is (Image (Integer (Widgets.Left_Of (Item))) & "," & Image (Integer (Widgets.Top_Of (Item))));

   procedure Settle (Item : in out Fixture) is
   begin
      Widgets.Layout (Item.Tree, Item.Target);
   end Settle;

   procedure Press_Key (Item : in out Fixture; Key : Events.Key_Code) is
      Handled : Boolean;
   begin
      Widgets.Dispatch (Item.Tree, (Kind => Events.Key_Down, Key => Key, others => <>), Handled);
   end Press_Key;

   procedure Click (Item : in out Fixture; X, Y : Float) is
      Handled : Boolean;
   begin
      Widgets.Dispatch
        (Item.Tree,
         (Kind => Events.Mouse_Down, Button => 1, Clicks => 1, Mouse_X => X, Mouse_Y => Y, others => <>),
         Handled);
      Widgets.Dispatch
        (Item.Tree, (Kind => Events.Mouse_Up, Button => 1, Mouse_X => X, Mouse_Y => Y, others => <>), Handled);
      Settle (Item);
   end Click;

   function Said (Item : in out Fixture; Source : Widgets.Widget'Class; Kind : Widgets.Event_Kind) return String is
      Taken : Boolean;
   begin
      Hearers.Take (Item.Ears, Source, Kind, Taken);
      return (if Taken then "yes" else "no");
   end Said;

   procedure Placing is
      Item : Fixture;
   begin
      Open (Item);
      Overlays.Present_Beside (Item.Content, Item.Anchor);
      Settle (Item);
      Goldens.Check_Text ("overlay-below", "20,54", Where (Item.Content));
      Goldens.Check_Text ("overlay-shown", "TRUE", Widgets.Is_Showing (Item.Content)'Image);
      Goldens.Check_Text ("overlay-presented", "TRUE", Overlays.Is_Presented (Item.Content)'Image);

      --  After it, along its top.
      Overlays.Dismiss (Item.Content);
      Overlays.Present_Beside (Item.Content, Item.Anchor, (Side => Anchoring.After, others => <>));
      Settle (Item);
      Goldens.Check_Text ("overlay-after", "104,20", Where (Item.Content));

      --  Middle and finish, along the anchor's width.
      Overlays.Dismiss (Item.Content);
      Overlays.Present_Beside (Item.Content, Item.Anchor, (Along => Anchoring.Middle, others => <>));
      Settle (Item);
      Goldens.Check_Text ("overlay-middle", "8,54", Where (Item.Content));
      Overlays.Dismiss (Item.Content);
      Overlays.Present_Beside (Item.Content, Item.Anchor, (Along => Anchoring.Finish, Margin => 0.0, others => <>));
      Settle (Item);
      Goldens.Check_Text ("overlay-finish", "0,54", Where (Item.Content));
      Overlays.Dismiss (Item.Content);

      --  The width of the anchor.
      Overlays.Present_Beside (Item.Content, Item.Anchor, (Match_Width => True, others => <>));
      Settle (Item);
      Goldens.Check_Text ("overlay-matches-width", "80", Image (Integer (Widgets.Width_Of (Item.Content))));
      Overlays.Dismiss (Item.Content);

      --  At a point, clear of the pointer.
      Overlays.Present_At (Item.Content, 100.0, 100.0);
      Settle (Item);
      Goldens.Check_Text ("overlay-at-point", "100,112", Where (Item.Content));
      Overlays.Dismiss (Item.Content);

      --  In the middle, a little above the centre (at the width it was made).
      Put (Item.Content, 0.0, 0.0, 120.0, 60.0);
      Overlays.Present_Centered (Item.Content, Pomarine.Anchoring.Light_Dismiss);
      Settle (Item);
      Goldens.Check_Text ("overlay-centred", "140,96", Where (Item.Content));
      Overlays.Dismiss (Item.Content);
      Goldens.Check_Text ("overlay-dismissed-hidden", "FALSE", Widgets.Is_Showing (Item.Content)'Image);
      Goldens.Check_Text ("overlay-silent", "no", Said (Item, Item.Content, Widgets.Dismiss));
   end Placing;

   procedure Placing_At_Edges is
      Low   : Fixture;
      Right : Fixture;
   begin
      --  Under it there is no room, so it goes over it.
      Open (Low, Anchor_Left => 20.0, Anchor_Top => 250.0);
      Overlays.Present_Beside (Low.Content, Low.Anchor);
      Settle (Low);
      Goldens.Check_Text ("overlay-flips-above", "20,186", Where (Low.Content));
      Overlays.Dismiss (Low.Content);
      Overlays.Present_Beside (Low.Content, Low.Anchor, (Flip => False, others => <>));
      Settle (Low);
      Goldens.Check_Text ("overlay-clamped-without-flip", "20,232", Where (Low.Content));

      --  Too far right: pulled in, a margin from the edge.
      Open (Right, Anchor_Left => 350.0, Anchor_Top => 20.0);
      Overlays.Present_Beside (Right.Content, Right.Anchor);
      Settle (Right);
      Goldens.Check_Text ("overlay-clamped-right", "272,54", Where (Right.Content));
   end Placing_At_Edges;

   procedure Letting_Go is
      Item : Fixture;
   begin
      Open (Item);
      Overlays.Present_Beside (Item.Content, Item.Anchor);
      Settle (Item);

      --  A press inside it does not let it go.
      Click (Item, 30.0, 70.0);
      Goldens.Check_Text ("overlay-inside-stays", "TRUE", Overlays.Is_Presented (Item.Content)'Image);

      --  Escape does, and it says so; what had the focus does not take the key.
      Press_Key (Item, Events.Key_Escape);
      Goldens.Check_Text ("overlay-escape", "FALSE", Overlays.Is_Presented (Item.Content)'Image);
      Goldens.Check_Text ("overlay-escape-hidden", "FALSE", Widgets.Is_Showing (Item.Content)'Image);
      Goldens.Check_Text ("overlay-escape-said", "yes", Said (Item, Item.Content, Widgets.Dismiss));

      --  A press outside lets it go, and is not given to what is under it.
      Overlays.Present_Beside (Item.Content, Item.Anchor);
      Settle (Item);
      Click (Item, 280.0, 165.0);
      Goldens.Check_Text ("overlay-outside", "FALSE", Overlays.Is_Presented (Item.Content)'Image);
      Goldens.Check_Text ("overlay-outside-said", "yes", Said (Item, Item.Content, Widgets.Dismiss));
      Goldens.Check_Text ("overlay-outside-swallowed", "no", Said (Item, Item.Behind, Widgets.Click));

      --  With Pass_Through, it is.
      Overlays.Present_Beside (Item.Content, Item.Anchor, How => (Pass_Through => True, others => <>));
      Settle (Item);
      Click (Item, 280.0, 165.0);
      Goldens.Check_Text ("overlay-pass-through-let-go", "FALSE", Overlays.Is_Presented (Item.Content)'Image);
      Goldens.Check_Text ("overlay-pass-through-clicked", "yes", Said (Item, Item.Behind, Widgets.Click));

      --  A press on what it is anchored to only lets it go: a second click on a select closes its menu.
      Overlays.Present_Beside (Item.Content, Item.Anchor, How => (Pass_Through => True, others => <>));
      Settle (Item);
      Click (Item, 40.0, 30.0);
      Goldens.Check_Text ("overlay-anchor-let-go", "FALSE", Overlays.Is_Presented (Item.Content)'Image);
      Goldens.Check_Text ("overlay-anchor-not-clicked", "no", Said (Item, Item.Anchor, Widgets.Click));

      --  Not let go of by what it is not asked to be let go of by.
      Overlays.Present_Beside (Item.Content, Item.Anchor, How => Anchoring.Passive);
      Settle (Item);
      Press_Key (Item, Events.Key_Escape);
      Click (Item, 280.0, 165.0);
      Goldens.Check_Text ("overlay-passive-stays", "TRUE", Overlays.Is_Presented (Item.Content)'Image);
      Goldens.Check_Text ("overlay-passive-passes", "yes", Said (Item, Item.Behind, Widgets.Click));

      --  Taken out of the tree, it is forgotten.
      Widgets.Remove (Item.Content);
      Goldens.Check_Text ("overlay-removed", "0", Image (Overlays.Presented_Count (Item.Tree)));
   end Letting_Go;

   procedure Modality is
      Item : Fixture;
   begin
      Open (Item);
      Widgets.Set_Tab_Navigation (Item.Tree, True);
      Widgets.Focus (Item.Behind);
      Overlays.Present_Centered (Item.Content);
      Settle (Item);
      Goldens.Check_Text
        ("overlay-modal-focus-in", "TRUE", Boolean'Image (Widgets.Focus_Of (Item.Tree) = Item.Inner'Unchecked_Access));

      --  What is outside takes nothing: not a press, and Tab stays in.
      Click (Item, 280.0, 165.0);
      Goldens.Check_Text ("overlay-modal-blocks-click", "no", Said (Item, Item.Behind, Widgets.Click));
      Goldens.Check_Text ("overlay-modal-stays", "TRUE", Overlays.Is_Presented (Item.Content)'Image);
      Press_Key (Item, Events.Key_Tab);
      Goldens.Check_Text
        ("overlay-modal-tab-stays-in",
         "TRUE",
         Boolean'Image (Widgets.Focus_Of (Item.Tree) = Item.Inner'Unchecked_Access));

      --  Inside it, a press is taken as always.
      Click (Item, 200.0, 115.0);
      Goldens.Check_Text ("overlay-modal-inside-clicks", "yes", Said (Item, Item.Inner, Widgets.Click));

      --  Escape lets it go, and the focus goes back where it was.
      Press_Key (Item, Events.Key_Escape);
      Goldens.Check_Text ("overlay-modal-escape", "FALSE", Overlays.Is_Presented (Item.Content)'Image);
      Goldens.Check_Text
        ("overlay-modal-focus-back",
         "TRUE",
         Boolean'Image (Widgets.Focus_Of (Item.Tree) = Item.Behind'Unchecked_Access));
      Click (Item, 280.0, 165.0);
      Goldens.Check_Text ("overlay-modal-gone-click", "yes", Said (Item, Item.Behind, Widgets.Click));
   end Modality;

   procedure Stacking is
      Item : Fixture;
   begin
      Open (Item);
      Overlays.Present_Centered (Item.Content);
      Overlays.Present_Beside (Item.Second, Item.Behind);
      Settle (Item);
      Goldens.Check_Text ("overlay-stack-count", "2", Image (Overlays.Presented_Count (Item.Tree)));

      --  Escape lets go of the top one only.
      Press_Key (Item, Events.Key_Escape);
      Goldens.Check_Text
        ("overlay-stack-top-first",
         "TRUE,FALSE",
         Overlays.Is_Presented (Item.Content)'Image & "," & Overlays.Is_Presented (Item.Second)'Image);
      Press_Key (Item, Events.Key_Escape);
      Goldens.Check_Text ("overlay-stack-then-dialog", "0", Image (Overlays.Presented_Count (Item.Tree)));

      --  Dismissing the one under takes those over it.
      Overlays.Present_Centered (Item.Content);
      Overlays.Present_Beside (Item.Second, Item.Behind);
      Overlays.Dismiss (Item.Content);
      Goldens.Check_Text ("overlay-stack-dismiss-under", "0", Image (Overlays.Presented_Count (Item.Tree)));
      Goldens.Check_Text ("overlay-stack-over-hidden", "FALSE", Widgets.Is_Showing (Item.Second)'Image);
   end Stacking;

   procedure Dimming is
      package Images renames Goldens.Images;
      Item   : Fixture;
      Before : Images.Image;
      Over   : Images.Image;
      After  : Images.Image;
      Light  : Images.Image;

      function Red_At (Picture : Images.Image) return Natural
      is (Natural (Images.Pixel (Picture, 300, 250).Red));

      procedure Draw (Into : in out Images.Image) is
      begin
         Widgets.Layout (Item.Tree, Item.Target);
         Widgets.Paint (Item.Tree, Item.Target, Pomarine.Themes.Light);
         Images.Read (Into, Item.Target);
      end Draw;
   begin
      Open (Item);
      Draw (Before);

      Overlays.Present_Centered (Item.Content);
      Draw (Over);
      Goldens.Check_Text ("dimming-darker", "TRUE", Boolean'Image (Red_At (Over) < Red_At (Before)));
      Goldens.Check_Text ("dimming-not-black", "TRUE", Boolean'Image (Red_At (Over) > Red_At (Before) / 2));

      Overlays.Dismiss (Item.Content);
      Draw (After);
      Goldens.Check_Text ("dimming-given-back", Image (Red_At (Before)), Image (Red_At (After)));

      --  A light overlay leaves what is under it as it is.
      Overlays.Present_Beside (Item.Content, Item.Anchor);
      Draw (Light);
      Goldens.Check_Text ("dimming-none-for-light", Image (Red_At (Before)), Image (Red_At (Light)));
   end Dimming;

end Overlay_Tests;
