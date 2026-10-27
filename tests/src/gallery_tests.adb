with Gallery;
with Gallery_VM;
with Goldens;
with Pomarine.Clipboards;
with Pomarine.Events;
with Pomarine.Icons;
with Pomarine.Line_Texts;
with Test_Icons;
with Pomarine.Testing;
with Pomarine.Themes;
with Pomarine.Widgets;
with Pomarine.Widgets.Sliders;
with Pomarine.Widgets.Choice_Groups;
with Pomarine.Widgets.Number_Fields;
with Pomarine.Widgets.Steppers;
with Pomarine.Widgets.Disclosures;
with SDL3.Windows.Renderers;

package body Gallery_Tests is

   package Renderers renames SDL3.Windows.Renderers;
   package Images renames Goldens.Images;
   package Widgets renames Pomarine.Widgets;

   type Stage is (Fresh, Handled, Selecting, Showing_Popover, Asking, Hovering, Contextual, Invalid_Number, Scrolled);
   --  Handled: a person has been at it: clicks, a name, a box ticked, a size, a switch, a row, the slider.

   procedure Use_It (Model : in out Gallery_VM.Model; Parts : in out Gallery.Specimens) is
   begin
      for Tap in 1 .. 4 loop
         Gallery_VM.Execute (Model, Gallery_VM.Click_Me);
      end loop;
      Gallery_VM.Set_Name (Model, "Ada");
      Gallery_VM.Set_Notify (Model, True);
      Gallery_VM.Execute (Model, Gallery_VM.Pick_Size, 3);
      Gallery_VM.Execute (Model, Gallery_VM.Toggle_Compact);
      Gallery_VM.Select_Row (Model, 2);
      Pomarine.Widgets.Sliders.Set_Value (Parts.Slider, 0.75);
      Widgets.Choice_Groups.Select_Choice (Parts.Views, 2);
      Widgets.Choice_Groups.Select_Choice (Parts.Alignment, 2);
      Widgets.Choice_Groups.Select_Choice (Parts.Mode, 2);
      Widgets.Steppers.Set_Value (Parts.Copies, 99);
      Widgets.Number_Fields.Set_Value (Parts.Quantity, 42);
      Widgets.Disclosures.Set_Open (Parts.Advanced, False);
   end Use_It;

   procedure Click_On (Tree : in out Widgets.Tree; Item : Widgets.Widget'Class) is
      --  A press and a let go at the middle of Item.
      Taken  : Boolean;
      Pixels : constant Float := Widgets.Density (Item);
      X      : constant Float := (Widgets.Left_Of (Item) + Widgets.Width_Of (Item) / 2.0) / Pixels;
      Y      : constant Float := (Widgets.Top_Of (Item) + Widgets.Height_Of (Item) / 2.0) / Pixels;
   begin
      Widgets.Dispatch (Tree, (Kind => Pomarine.Events.Mouse_Move, Mouse_X => X, Mouse_Y => Y, others => <>), Taken);
      Widgets.Dispatch
        (Tree,
         (Kind => Pomarine.Events.Mouse_Down, Button => 1, Clicks => 1, Mouse_X => X, Mouse_Y => Y, others => <>),
         Taken);
      Widgets.Dispatch
        (Tree, (Kind => Pomarine.Events.Mouse_Up, Button => 1, Mouse_X => X, Mouse_Y => Y, others => <>), Taken);
   end Click_On;

   procedure Draw
     (Name          : String;
      Colors        : Pomarine.Themes.Theme;
      Density       : Float;
      Then_Do       : Stage;
      Window_Height : Positive := Gallery.Height)
   is
      Target : Renderers.Renderer;  --  before the tree that draws to it
      Board  : Pomarine.Clipboards.Memory_Clipboard;
      Lines  : aliased Pomarine.Line_Texts.Drawer;  --  after Target, which it draws to
      Icons  : aliased Pomarine.Icons.Library;
      Tree   : aliased Widgets.Tree;
      Model  : aliased Gallery_VM.Model;  --  before the view that shows it
      Parts  : Gallery.Specimens;
      Screen : Gallery.UI.View (Tree'Access);
      Drawn  : Images.Image;
   begin
      Renderers.Create_Offscreen
        (Target, Positive (Float (Gallery.Width) * Density), Positive (Float (Window_Height) * Density));
      Widgets.Set_Density (Tree, Density);
      Widgets.Set_Reduced_Motion (Tree, True);
      Widgets.Set_Clipboard (Tree, Board);
      Widgets.Set_Line_Texts (Tree, Lines);
      Test_Icons.Install (Icons);
      Widgets.Set_Icons (Tree, Icons);
      Gallery_VM.Seed (Model);
      Gallery.Build (Screen, Model'Access, Parts);
      if Then_Do = Handled then
         Use_It (Model, Parts);
      end if;
      Widgets.Layout (Tree, Target);
      Widgets.Update (Tree, 16);
      Widgets.Layout (Tree, Target);
      case Then_Do is
         when Selecting       =>
            Click_On (Tree, Parts.Choice);

         when Showing_Popover =>
            Click_On (Tree, Parts.Info_Button);

         when Asking          =>
            Click_On (Tree, Parts.Ask_Button);

         when Hovering        =>
            declare
               Taken : Boolean;
            begin
               Widgets.Dispatch
                 (Tree,
                  (Kind    => Pomarine.Events.Mouse_Move,
                   Mouse_X => (Widgets.Left_Of (Parts.Slider) + 20.0) / Density,
                   Mouse_Y => (Widgets.Top_Of (Parts.Slider) + Widgets.Height_Of (Parts.Slider) / 2.0) / Density,
                   others  => <>),
                  Taken);
               Widgets.Update (Tree, 32);
               Widgets.Update (Tree, 1000);
            end;

         when Scrolled        =>
            declare
               Taken : Boolean;
            begin
               Widgets.Dispatch
                 (Tree,
                  (Kind    => Pomarine.Events.Mouse_Wheel,
                   Wheel_Y => -100.0,
                   Mouse_X => 710.0,
                   Mouse_Y => 300.0,
                   others  => <>),
                  Taken);
            end;

         when Contextual      =>
            Click_On (Tree, Parts.Context_Button);

         when Invalid_Number  =>
            declare
               Taken : Boolean;
            begin
               Widgets.Focus (Parts.Quantity);
               Widgets.Dispatch
                 (Tree,
                  (Kind => Pomarine.Events.Key_Down, Key => Pomarine.Events.Key_A, Command => True, others => <>),
                  Taken);
               Widgets.Dispatch (Tree, Pomarine.Events.Text_Event ("1000"), Taken);
               Widgets.Dispatch
                 (Tree, (Kind => Pomarine.Events.Key_Down, Key => Pomarine.Events.Key_Return, others => <>), Taken);
               Widgets.Clear_Focus (Tree);
            end;

         when Fresh | Handled =>
            null;
      end case;
      Widgets.Update (Tree, 1100);
      Widgets.Layout (Tree, Target);
      Widgets.Paint (Tree, Target, Colors);
      Images.Read (Drawn, Target);
      Goldens.Check (Name, Drawn);
   end Draw;

   procedure Opens is
   begin
      Draw ("gallery-opens", Pomarine.Themes.Light, 1.0, Fresh);
   end Opens;

   procedure Used is
   begin
      Draw ("gallery-used", Pomarine.Themes.Light, 1.0, Handled);
   end Used;

   procedure Dark is
   begin
      Draw ("gallery-dark", Pomarine.Themes.Dark, 1.0, Handled);
   end Dark;

   procedure Dense is
   begin
      Draw ("gallery-dense", Pomarine.Themes.Light, 2.0, Handled);
   end Dense;

   procedure Select_Open is
   begin
      Draw ("gallery-select-open", Pomarine.Themes.Light, 1.0, Selecting);
   end Select_Open;

   procedure Popover_Open is
   begin
      Draw ("gallery-popover-open", Pomarine.Themes.Light, 1.0, Showing_Popover);
   end Popover_Open;

   procedure Dialog_Open is
   begin
      Draw ("gallery-dialog-open", Pomarine.Themes.Light, 1.0, Asking);
   end Dialog_Open;

   procedure Tooltip_Shown is
   begin
      Draw ("gallery-tooltip-shown", Pomarine.Themes.Light, 1.0, Hovering);
   end Tooltip_Shown;

   procedure Scrolled_Sheet is
   begin
      Draw ("gallery-scrolled", Pomarine.Themes.Light, 1.0, Scrolled, Gallery.Initial_Height);
   end Scrolled_Sheet;

   procedure Context_Open is
   begin
      Draw ("gallery-context-open", Pomarine.Themes.Light, 1.0, Contextual);
   end Context_Open;

   procedure Number_Invalid is
   begin
      Draw ("gallery-number-invalid", Pomarine.Themes.Light, 1.0, Invalid_Number);
   end Number_Invalid;

   procedure Described is
      Tree     : aliased Widgets.Tree;
      Model    : aliased Gallery_VM.Model;
      Parts    : Gallery.Specimens;
      Screen   : Gallery.UI.View (Tree'Access);
      Session  : Pomarine.Testing.Session;
      Expected : constant String :=
        "window"
        & ASCII.LF
        & "scroll area"
        & ASCII.LF
        & "group"
        & ASCII.LF
        & "text 'Buttons'"
        & ASCII.LF
        & "group"
        & ASCII.LF
        & "button 'Click me'"
        & ASCII.LF
        & "button 'Reset' disabled"
        & ASCII.LF
        & "button 'Remove' disabled"
        & ASCII.LF
        & "text 'Clicked 0 times'"
        & ASCII.LF
        & "progress indicator =0%"
        & ASCII.LF
        & "text 'Fields'"
        & ASCII.LF
        & "group"
        & ASCII.LF
        & "text field 'Your name'"
        & ASCII.LF
        & "text"
        & ASCII.LF
        & "text 'Hello, stranger!'"
        & ASCII.LF
        & "group"
        & ASCII.LF
        & "check box 'Notify me' OFF"
        & ASCII.LF
        & "radio button 'Small' OFF"
        & ASCII.LF
        & "radio button 'Medium' ON selected"
        & ASCII.LF
        & "radio button 'Large' OFF"
        & ASCII.LF
        & "switch 'Compact' OFF"
        & ASCII.LF
        & "text 'Values'"
        & ASCII.LF
        & "group"
        & ASCII.LF
        & "slider =40%"
        & ASCII.LF
        & "button 'Font' =Georgia"
        & ASCII.LF
        & "group 'Ada'"
        & ASCII.LF
        & "button 'close Ada'"
        & ASCII.LF
        & "text '3'"
        & ASCII.LF
        & "text 'Choosers'"
        & ASCII.LF
        & "group"
        & ASCII.LF
        & "group"
        & ASCII.LF
        & "radio button 'Write' ON selected"
        & ASCII.LF
        & "radio button 'Outline' OFF"
        & ASCII.LF
        & "radio button 'Canvas' OFF"
        & ASCII.LF
        & "slider 'Copies' =2 copies"
        & ASCII.LF
        & "text field 'Quantity' =12"
        & ASCII.LF
        & "text =12"
        & ASCII.LF
        & "group"
        & ASCII.LF
        & "group"
        & ASCII.LF
        & "radio button 'Left' ON selected"
        & ASCII.LF
        & "radio button 'Center' OFF"
        & ASCII.LF
        & "radio button 'Right' OFF"
        & ASCII.LF
        & "group"
        & ASCII.LF
        & "radio button 'Draft' ON selected"
        & ASCII.LF
        & "radio button 'Final' OFF"
        & ASCII.LF
        & "group 'Advanced'"
        & ASCII.LF
        & "text 'A disclosure hides what is under its heading.'"
        & ASCII.LF
        & "text 'Click the heading, or press Space on it.'"
        & ASCII.LF
        & "group"
        & ASCII.LF
        & "group"
        & ASCII.LF
        & "separator 'Pane divider'"
        & ASCII.LF
        & "group"
        & ASCII.LF
        & "text 'Rich text'"
        & ASCII.LF
        & "text area 'Rich text' =Select some text and try the formatting toolbar."
        & ASCII.LF
        & "text =Select some text and try the formatting toolbar."
        & ASCII.LF
        & "button 'Bold'"
        & ASCII.LF
        & "button 'Italic'"
        & ASCII.LF
        & "button 'Underline'"
        & ASCII.LF
        & "button 'Strikethrough'"
        & ASCII.LF
        & "button 'Bulleted list'"
        & ASCII.LF
        & "button 'Numbered list'"
        & ASCII.LF
        & "button 'Quotation'"
        & ASCII.LF
        & "button 'Decrease indent'"
        & ASCII.LF
        & "button 'Increase indent'"
        & ASCII.LF
        & "button 'Link' disabled"
        & ASCII.LF
        & "button 'Font family' =Georgia"
        & ASCII.LF
        & "button 'Font size' =14 pt"
        & ASCII.LF
        & "button 'Paragraph style' =Normal"
        & ASCII.LF
        & "text 'Lists and menus'"
        & ASCII.LF
        & "group"
        & ASCII.LF
        & "list 'Fruit'"
        & ASCII.LF
        & "list item 'Apples'"
        & ASCII.LF
        & "list item 'Bananas'"
        & ASCII.LF
        & "list item 'Cherries'"
        & ASCII.LF
        & "list item 'Damsons'"
        & ASCII.LF
        & "menu"
        & ASCII.LF
        & "heading 'Edit'"
        & ASCII.LF
        & "menu item 'Copy'"
        & ASCII.LF
        & "menu item 'Word wrap' ON"
        & ASCII.LF
        & "separator"
        & ASCII.LF
        & "menu item 'Delete'"
        & ASCII.LF
        & "text 'Nothing else'"
        & ASCII.LF
        & "text 'Notices'"
        & ASCII.LF
        & "group"
        & ASCII.LF
        & "status 'Task deleted'"
        & ASCII.LF
        & "button 'Undo'"
        & ASCII.LF
        & "tooltip 'Saves the file'"
        & ASCII.LF
        & "button 'Popover'"
        & ASCII.LF
        & "button 'Dialog'"
        & ASCII.LF
        & "button 'Context menu'"
        & ASCII.LF;
   begin
      Gallery_VM.Seed (Model);
      Gallery.Build (Screen, Model'Access, Parts);
      Pomarine.Testing.Open (Session, Tree, Gallery.Width, Gallery.Height);
      Goldens.Check_Text ("gallery-described-opens", Expected, Pomarine.Testing.Screen (Session));
   end Described;

end Gallery_Tests;
