with Goldens;
with Pomarine.Themes;
with Pomarine.Models;
with SDL3.Windows.Renderers;
with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Checks;
with Pomarine.Widgets.Labels;
with Pomarine.Widgets.Lists;
with Pomarine.Widgets.Panels;
with Pomarine.Widgets.Progress_Bars;
with Pomarine.Widgets.Selects;
with Pomarine.Widgets.Sliders;
with Pomarine.Widgets.Switches;
with Yoga.Nodes;

package body Setter_Tests is

   package Widgets renames Pomarine.Widgets;
   package Renderers renames SDL3.Windows.Renderers;

   Colors : constant Pomarine.Themes.Theme := Pomarine.Themes.Light;

   type Three_Rows is limited new Pomarine.Models.List_Model with null record;

   overriding function Count (Self : Three_Rows) return Natural is (3);
   overriding function Version (Self : Three_Rows) return Natural is (0);
   overriding function Row_Id (Self : Three_Rows; Row : Positive) return Positive is (Row);
   overriding procedure Describe_Row (Self : Three_Rows; Row : Positive; Content : out Pomarine.Models.Row_Content);

   overriding procedure Describe_Row (Self : Three_Rows; Row : Positive; Content : out Pomarine.Models.Row_Content) is
      pragma Unreferenced (Self);
   begin
      Content := (others => <>);
      Pomarine.Models.Set_Text (Content, "Row" & Row'Image);
   end Describe_Row;

   type Fixture is limited record
      Tree     : Widgets.Tree;
      Target   : Renderers.Renderer;
      Rows     : aliased Three_Rows;
      Root     : aliased Widgets.Panels.Panel;
      Words    : aliased Widgets.Labels.Label;
      Press    : aliased Widgets.Buttons.Button;
      Box      : aliased Widgets.Checks.Check;
      Flip     : aliased Widgets.Switches.Switch;
      Choice   : aliased Widgets.Selects.Select_Field;
      Slide    : aliased Widgets.Sliders.Slider;
      Progress : aliased Widgets.Progress_Bars.Progress_Bar;
      Chosen   : aliased Widgets.Lists.List;
   end record;

   procedure Size (Part : in out Widgets.Widget'Class) is
   begin
      Yoga.Nodes.Set_Width (Widgets.Node (Part), 200.0);
      Yoga.Nodes.Set_Height (Widgets.Node (Part), 24.0);
   end Size;

   procedure Open (Item : in out Fixture) is
   begin
      Renderers.Create_Offscreen (Item.Target, 300, 300);
      Widgets.Set_Density (Item.Tree, 1.0);
      Widgets.Set_Reduced_Motion (Item.Tree, True);
      Widgets.Set_Root (Item.Tree, Item.Root);
      Widgets.Add (Item.Root, Item.Words, Item.Press, Item.Box);
      Widgets.Add (Item.Root, Item.Flip, Item.Choice, Item.Slide);
      Widgets.Add (Item.Root, Item.Progress, Item.Chosen);
      Widgets.Buttons.Set_Label (Item.Press, "Press");
      Widgets.Checks.Set_Label (Item.Box, "Check");
      Widgets.Switches.Set_Label (Item.Flip, "Switch");
      Widgets.Lists.Set_Model (Item.Chosen, Item.Rows'Unchecked_Access);
      --  Each has a size, or what changes in it has nowhere to be damaged.
      Size (Item.Words);
      Size (Item.Press);
      Size (Item.Box);
      Size (Item.Flip);
      Size (Item.Choice);
      Size (Item.Slide);
      Size (Item.Progress);
      Yoga.Nodes.Set_Width (Widgets.Node (Item.Chosen), 200.0);
      Yoga.Nodes.Set_Height (Widgets.Node (Item.Chosen), 60.0);
      Widgets.Layout (Item.Tree, Item.Target);
      Widgets.Paint (Item.Tree, Item.Target, Colors, Retained => True);
   end Open;

   --  Whether anything needs drawing now.

   function Pending (Item : Fixture) return Boolean is (Widgets.Needs_Paint (Item.Tree));

   procedure Settle (Item : in out Fixture) is
   begin
      Widgets.Layout (Item.Tree, Item.Target);
      Widgets.Paint (Item.Tree, Item.Target, Colors, Retained => True);
   end Settle;

   procedure Idempotent is
      Item : Fixture;

      procedure Twice (Name : String; First, Again : not null access procedure) is
      begin
         First.all;
         Goldens.Check_Text ("setters-" & Name & "-first", "TRUE", Pending (Item)'Image);
         Settle (Item);
         Again.all;
         Goldens.Check_Text ("setters-" & Name, "FALSE", Pending (Item)'Image);
      end Twice;

      procedure Label_Text is begin Widgets.Labels.Set_Text (Item.Words, "Skua"); end Label_Text;
      procedure Button_Off is begin Widgets.Buttons.Set_Enabled (Item.Press, False); end Button_Off;
      procedure Check_On is begin Widgets.Checks.Set_Checked (Item.Box, True); end Check_On;
      procedure Check_Off is begin Widgets.Checks.Set_Enabled (Item.Box, False); end Check_Off;
      procedure Switch_On is begin Widgets.Switches.Set_On (Item.Flip, True); end Switch_On;
      procedure Switch_Off is begin Widgets.Switches.Set_Enabled (Item.Flip, False); end Switch_Off;
      procedure Select_Text is begin Widgets.Selects.Set_Value (Item.Choice, "Dark"); end Select_Text;
      procedure Select_Off is begin Widgets.Selects.Set_Enabled (Item.Choice, False); end Select_Off;
      procedure Slide_To is begin Widgets.Sliders.Set_Value (Item.Slide, 0.25); end Slide_To;
      procedure Progress_To is begin Widgets.Progress_Bars.Set_Value (Item.Progress, 0.5); end Progress_To;
      procedure Row_Two is begin Widgets.Lists.Select_Row (Item.Chosen, 2); end Row_Two;
      procedure Hide_Words is begin Widgets.Set_Visible (Item.Words, False); end Hide_Words;
   begin
      Open (Item);
      Twice ("label-text", Label_Text'Access, Label_Text'Access);
      Twice ("button-enabled", Button_Off'Access, Button_Off'Access);
      Twice ("check-checked", Check_On'Access, Check_On'Access);
      Twice ("check-enabled", Check_Off'Access, Check_Off'Access);
      Twice ("switch-on", Switch_On'Access, Switch_On'Access);
      Twice ("switch-enabled", Switch_Off'Access, Switch_Off'Access);
      Twice ("select-value", Select_Text'Access, Select_Text'Access);
      Twice ("select-enabled", Select_Off'Access, Select_Off'Access);
      Twice ("slider-value", Slide_To'Access, Slide_To'Access);
      Twice ("progress-value", Progress_To'Access, Progress_To'Access);
      Twice ("list-select-row", Row_Two'Access, Row_Two'Access);
      Twice ("visible", Hide_Words'Access, Hide_Words'Access);
   end Idempotent;

end Setter_Tests;
