with Ada.Strings.Fixed;
with SDL3.Events;
with SDL3.Windows.Renderers;
with Goldens;
with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Checks;
with Pomarine.Widgets.Panels;
with Pomarine.Widgets.Sliders;
with Pomarine.Widgets.Switches;
with Yoga.Nodes;

package body Keyboard_Tests is

   package Widgets renames Pomarine.Widgets;
   package Events renames SDL3.Events;
   package Renderers renames SDL3.Windows.Renderers;
   package Nodes renames Yoga.Nodes;

   use type Widgets.Widget_Access;

   type Fixture is limited record
      Tree   : Widgets.Tree;
      Target : Renderers.Renderer;
      Root   : aliased Widgets.Panels.Panel;
      Save   : aliased Widgets.Buttons.Button;
      Skip   : aliased Widgets.Buttons.Button;
      Wrap   : aliased Widgets.Checks.Check;
      Power  : aliased Widgets.Switches.Switch;
      Volume : aliased Widgets.Sliders.Slider;
   end record;

   procedure Open (Item : in out Fixture) is
   begin
      Renderers.Create_Offscreen (Item.Target, 400, 50);
      Widgets.Set_Root (Item.Tree, Item.Root);
      Widgets.Add (Item.Root, Item.Save, Item.Skip, Item.Wrap, Item.Power, Item.Volume);
      Nodes.Set_Flex_Direction (Widgets.Node (Item.Root), Yoga.Row);
      Widgets.Buttons.Set_Label (Item.Save, "Save");
      Widgets.Buttons.Set_Label (Item.Skip, "Skip");
      Widgets.Checks.Set_Label (Item.Wrap, "Wrap");
      Widgets.Switches.Set_Label (Item.Power, "Power");
      Widgets.Buttons.Set_Focusable (Item.Save, True);
      Widgets.Checks.Set_Focusable (Item.Wrap, True);
      Widgets.Switches.Set_Focusable (Item.Power, True);
      Widgets.Sliders.Set_Focusable (Item.Volume, True);
      Widgets.Sliders.Set_Value (Item.Volume, 0.5);
      Nodes.Set_Width (Widgets.Node (Item.Save), 70.0);
      Nodes.Set_Width (Widgets.Node (Item.Skip), 70.0);
      Nodes.Set_Width (Widgets.Node (Item.Wrap), 70.0);
      Nodes.Set_Width (Widgets.Node (Item.Power), 70.0);
      Nodes.Set_Width (Widgets.Node (Item.Volume), 70.0);
      Widgets.Layout (Item.Tree, Item.Target);
   end Open;

   procedure Press (Item : in out Fixture; Key : Events.Key_Code; Shift : Boolean := False) is
      Handled : Boolean;
   begin
      Widgets.Dispatch
        (Item.Tree, (Kind => Events.Key_Down, Key => Key, Shift => Shift, others => <>), Handled);
   end Press;

   function Who (Item : in out Fixture) return String is
      Focused : constant Widgets.Widget_Access := Widgets.Focus_Of (Item.Tree);
   begin
      return (if Focused = null then "none"
              elsif Focused = Item.Save'Unchecked_Access then "save"
              elsif Focused = Item.Wrap'Unchecked_Access then "wrap"
              elsif Focused = Item.Power'Unchecked_Access then "power"
              elsif Focused = Item.Volume'Unchecked_Access then "volume"
              else "other");
   end Who;

   procedure Tab_Order is
      Item : Fixture;
   begin
      Open (Item);
      Widgets.Set_Tab_Navigation (Item.Tree, True);
      Press (Item, Events.Key_Tab);
      Goldens.Check_Text ("keyboard-first", "save", Who (Item));
      Press (Item, Events.Key_Tab);
      Goldens.Check_Text ("keyboard-skips", "wrap", Who (Item));
      Press (Item, Events.Key_Tab);
      Press (Item, Events.Key_Tab);
      Goldens.Check_Text ("keyboard-last", "volume", Who (Item));
      Press (Item, Events.Key_Tab);
      Goldens.Check_Text ("keyboard-round", "save", Who (Item));
      Press (Item, Events.Key_Tab, Shift => True);
      Goldens.Check_Text ("keyboard-back-round", "volume", Who (Item));
      Press (Item, Events.Key_Tab, Shift => True);
      Goldens.Check_Text ("keyboard-back", "power", Who (Item));

      --  Hidden, it is gone from the order.
      Widgets.Set_Visible (Item.Power, False);
      Widgets.Focus (Item.Wrap);
      Press (Item, Events.Key_Tab);
      Goldens.Check_Text ("keyboard-hidden-skipped", "volume", Who (Item));
   end Tab_Order;

   procedure Operating_Widgets is
      Item : Fixture;
   begin
      Open (Item);
      Widgets.Focus (Item.Wrap);
      Press (Item, Events.Key_Space);
      Goldens.Check_Text ("keyboard-check", "TRUE", Widgets.Checks.Is_Checked (Item.Wrap)'Image);
      Press (Item, Events.Key_Space);
      Goldens.Check_Text ("keyboard-uncheck", "FALSE", Widgets.Checks.Is_Checked (Item.Wrap)'Image);

      Widgets.Focus (Item.Power);
      Press (Item, Events.Key_Space);
      Goldens.Check_Text ("keyboard-switch", "TRUE", Widgets.Switches.Is_On (Item.Power)'Image);

      Widgets.Focus (Item.Volume);
      Press (Item, Events.Key_Right_Arrow);
      Press (Item, Events.Key_Right_Arrow);
      Goldens.Check_Text
        ("keyboard-slider", "60",
         Ada.Strings.Fixed.Trim (Integer'Image (Integer (Widgets.Sliders.Value (Item.Volume) * 100.0)),
                                 Ada.Strings.Left));
      Press (Item, Events.Key_Home);
      Goldens.Check_Text
        ("keyboard-slider-home", "0.0", Float'Image (Widgets.Sliders.Value (Item.Volume)) (2 .. 4));
      Press (Item, Events.Key_End);
      Goldens.Check_Text
        ("keyboard-slider-end", "1.0", Float'Image (Widgets.Sliders.Value (Item.Volume)) (2 .. 4));

      --  A button with the focus is pressed by Space, as before.
      Widgets.Focus (Item.Save);
      Press (Item, Events.Key_Space);
      declare
         Clicked : Boolean;
      begin
         Widgets.Buttons.Take_Click (Item.Save, Clicked);
         Goldens.Check_Text ("keyboard-button", "TRUE", Clicked'Image);
      end;
   end Operating_Widgets;

   procedure Off_Until_Asked is
      Item    : Fixture;
      Handled : Boolean;
   begin
      Open (Item);
      Widgets.Dispatch
        (Item.Tree, (Kind => Events.Key_Down, Key => Events.Key_Tab, others => <>), Handled);
      Goldens.Check_Text ("keyboard-tab-off", "FALSE none", Handled'Image & " " & Who (Item));
      --  Not focusable, they take no focus, by a click either.
      Goldens.Check_Text
        ("keyboard-not-focusable", "FALSE",
         Widgets.Accepts_Focus (Widgets.Widget'Class (Item.Skip))'Image);
   end Off_Until_Asked;

end Keyboard_Tests;
