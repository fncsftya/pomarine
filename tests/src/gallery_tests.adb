with Gallery;
with Gallery_VM;
with Goldens;
with Pomarine.Clipboards;
with Pomarine.Icons;
with Pomarine.Line_Texts;
with Test_Icons;
with Pomarine.Testing;
with Pomarine.Themes;
with Pomarine.Widgets;
with Pomarine.Widgets.Sliders;
with SDL3.Windows.Renderers;

package body Gallery_Tests is

   package Renderers renames SDL3.Windows.Renderers;
   package Images renames Goldens.Images;
   package Widgets renames Pomarine.Widgets;

   type Stage is (Fresh, Handled);
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
   end Use_It;

   procedure Draw (Name : String; Colors : Pomarine.Themes.Theme; Density : Float; Then_Do : Stage) is
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
        (Target, Positive (Float (Gallery.Width) * Density), Positive (Float (Gallery.Height) * Density));
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

   procedure Described is
      Tree    : aliased Widgets.Tree;
      Model   : aliased Gallery_VM.Model;
      Parts   : Gallery.Specimens;
      Screen  : Gallery.UI.View (Tree'Access);
      Session : Pomarine.Testing.Session;
      Expected : constant String :=
        "window" & ASCII.LF &
        "text 'Buttons'" & ASCII.LF &
        "group" & ASCII.LF &
        "button 'Click me'" & ASCII.LF &
        "button 'Reset' disabled" & ASCII.LF &
        "button 'Remove' disabled" & ASCII.LF &
        "text 'Clicked 0 times'" & ASCII.LF &
        "progress indicator =0%" & ASCII.LF &
        "text 'Fields'" & ASCII.LF &
        "group" & ASCII.LF &
        "text field 'Your name'" & ASCII.LF &
        "text" & ASCII.LF &
        "text 'Hello, stranger!'" & ASCII.LF &
        "group" & ASCII.LF &
        "check box 'Notify me' OFF" & ASCII.LF &
        "radio button 'Small' OFF" & ASCII.LF &
        "radio button 'Medium' ON selected" & ASCII.LF &
        "radio button 'Large' OFF" & ASCII.LF &
        "switch 'Compact' OFF" & ASCII.LF &
        "text 'Values'" & ASCII.LF &
        "group" & ASCII.LF &
        "slider =40%" & ASCII.LF &
        "button =Georgia" & ASCII.LF &
        "group 'Ada'" & ASCII.LF &
        "button 'close Ada'" & ASCII.LF &
        "text '3'" & ASCII.LF &
        "text 'Lists and menus'" & ASCII.LF &
        "group" & ASCII.LF &
        "list 'Fruit'" & ASCII.LF &
        "list item 'Apples'" & ASCII.LF &
        "list item 'Bananas'" & ASCII.LF &
        "list item 'Cherries'" & ASCII.LF &
        "list item 'Damsons'" & ASCII.LF &
        "menu" & ASCII.LF &
        "heading 'Edit'" & ASCII.LF &
        "menu item 'Copy'" & ASCII.LF &
        "menu item 'Word wrap' ON" & ASCII.LF &
        "separator" & ASCII.LF &
        "menu item 'Delete'" & ASCII.LF &
        "text 'Nothing else'" & ASCII.LF &
        "text 'Notices'" & ASCII.LF &
        "group" & ASCII.LF &
        "status 'Task deleted'" & ASCII.LF &
        "button 'Undo'" & ASCII.LF &
        "tooltip 'Saves the file'" & ASCII.LF;
   begin
      Gallery_VM.Seed (Model);
      Gallery.Build (Screen, Model'Access, Parts);
      Pomarine.Testing.Open (Session, Tree, Gallery.Width, Gallery.Height);
      Goldens.Check_Text ("gallery-described-opens", Expected, Pomarine.Testing.Screen (Session));
   end Described;

end Gallery_Tests;
