with Pomarine.Clipboards;
with Pomarine.Themes;
with Pomarine.Widgets;
with SDL3.Windows.Renderers;
with Goldens;
with Todo;
with Todo_VM;

package body UI_Tests is

   package Renderers renames SDL3.Windows.Renderers;
   package Images renames Goldens.Images;
   package Widgets renames Pomarine.Widgets;

   Colors : constant Pomarine.Themes.Theme := Pomarine.Themes.Light;

   --  A screen of the todo example in a window of that size, drawn in software.

   procedure Draw (Name : String; Width : Positive; Height : Positive; Used : Boolean) is
      Target : Renderers.Renderer;  --  before the tree that draws to it
      Board  : Pomarine.Clipboards.Memory_Clipboard;
      Tree   : aliased Widgets.Tree;
      Model  : aliased Todo_VM.Model;  --  before the view that shows it
      Screen : Todo.UI.View (Tree'Access);
      Drawn  : Images.Image;
   begin
      Renderers.Create_Offscreen (Target, Width, Height);
      Widgets.Set_Density (Tree, 1.0);
      Widgets.Set_Reduced_Motion (Tree, True);
      Widgets.Set_Clipboard (Tree, Board);
      Todo_VM.Seed (Model);
      Todo.Build (Screen, Model'Access);
      if Used then
         Todo_VM.Select_Row (Model, 2);
         Todo_VM.Set_Draft (Model, "Draw more goldens");
      end if;
      Widgets.Layout (Tree, Target);
      Widgets.Update (Tree, 16);
      Widgets.Layout (Tree, Target);
      Widgets.Paint (Tree, Target, Colors);
      Images.Read (Drawn, Target);
      Goldens.Check (Name, Drawn);
   end Draw;

   procedure Todo_Opens is
   begin
      Draw ("ui-todo-opens", 640, 480, Used => False);
   end Todo_Opens;

   procedure Todo_Used is
   begin
      Draw ("ui-todo-used", 640, 480, Used => True);
   end Todo_Used;

   procedure Todo_Wide is
   begin
      Draw ("ui-todo-wide", 900, 260, Used => True);
   end Todo_Wide;

end UI_Tests;
