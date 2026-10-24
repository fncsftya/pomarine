with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with SDL3.Cursors;
with SDL3.Events;
with SDL3.Windows.Renderers;
with SDL3.Windows;
with SDL3;
with Pomarine.Text_Areas;
with Pomarine.Line_Texts;
with Texts;
with Texts.Documents;
with Goldens;
with Pomarine.Clipboards;
with Pomarine.Themes;
with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Callbacks;
with Pomarine.Widgets.Editors;
with Pomarine.Widgets.Panels;
with Yoga.Nodes;

package body Widget_Tests is

   package Events renames SDL3.Events;
   package Renderers renames SDL3.Windows.Renderers;
   package Images renames Goldens.Images;
   package Widgets renames Pomarine.Widgets;
   package Panels renames Pomarine.Widgets.Panels;
   package Docs renames Texts.Documents;
   package Nodes renames Yoga.Nodes;

   use type Widgets.Widget_Access;

   Colors : constant Pomarine.Themes.Theme := Pomarine.Themes.Light;

   --  A window of a bar of three buttons above a text area, drawn in
   --  software:
   --
   --     Root ─┬─ Bar ─┬─ First, Second, Third
   --           └─ Page

   Density : constant Float := 2.0;
   Width   : constant := 360;
   Height  : constant := 200;
   --  In points.

   type Fixture is limited record
      Tree   : Widgets.Tree;
      Target : Renderers.Renderer;
      Doc    : aliased Docs.Document;
      Board  : Pomarine.Clipboards.Memory_Clipboard;
      Root   : aliased Panels.Panel;
      Bar    : aliased Panels.Panel;
      First  : aliased Pomarine.Widgets.Buttons.Button;
      Second : aliased Pomarine.Widgets.Buttons.Button;
      Third  : aliased Pomarine.Widgets.Buttons.Button;
      Page   : aliased Pomarine.Widgets.Editors.Editor;
      --  after Target and Doc
   end record;

   procedure Open
     (Item    : in out Fixture;
      Content : String := "Great skua";
      Wide    : Positive := Width) is
   begin
      Renderers.Create_Offscreen
        (Item.Target,
         Positive (Float (Wide) * Density),
         Positive (Float (Height) * Density));
      Docs.Load (Item.Doc, Content);
      Widgets.Set_Density (Item.Tree, Density);
      Widgets.Set_Clipboard (Item.Tree, Item.Board);

      Widgets.Set_Root (Item.Tree, Item.Root);
      Widgets.Add (Item.Root, Item.Bar);
      Widgets.Add (Item.Bar, Item.First);
      Widgets.Add (Item.Bar, Item.Second);
      Widgets.Add (Item.Bar, Item.Third);
      Widgets.Add (Item.Root, Item.Page);

      Panels.Set_Fill_Color (Item.Bar, (52, 54, 66, 255));
      Pomarine.Widgets.Buttons.Set_Label (Item.First, "One");
      Pomarine.Widgets.Buttons.Set_Label (Item.Second, "Two");
      Pomarine.Widgets.Buttons.Set_Label (Item.Third, "Three");
      Pomarine.Widgets.Editors.Configure
        (Item.Page, "Georgia", Size => 18.0, Measure => 640.0,
         Spacing => 8.0);
      Pomarine.Widgets.Editors.Attach (Item.Page, Item.Doc'Unchecked_Access);
      Widgets.Focus (Item.Page);

      Nodes.Set_Flex_Direction (Widgets.Node (Item.Root), Yoga.Column);
      Nodes.Set_Flex_Direction (Widgets.Node (Item.Bar), Yoga.Row);
      Nodes.Set_Height (Widgets.Node (Item.Bar), 32.0 * Density);
      Nodes.Set_Padding
        (Widgets.Node (Item.Bar), Yoga.All_Edges, 4.0 * Density);
      Nodes.Set_Gap (Widgets.Node (Item.Bar), Yoga.Column, 4.0 * Density);
      Nodes.Set_Width (Widgets.Node (Item.First), 80.0 * Density);
      Nodes.Set_Width (Widgets.Node (Item.Second), 80.0 * Density);
      Nodes.Set_Width (Widgets.Node (Item.Third), 80.0 * Density);
      Nodes.Set_Flex_Grow (Widgets.Node (Item.Page), 1.0);
      Nodes.Set_Margin (Widgets.Node (Item.Page), Yoga.All_Edges,
                        8.0 * Density);

      Widgets.Layout (Item.Tree, Item.Target);
   end Open;

   --  Where, in points, the middle of each button is, and of the text.

   First_At  : constant := 44.0;
   Second_At : constant := 128.0;
   Third_At  : constant := 212.0;
   Bar_Y     : constant := 16.0;
   Gap_At    : constant := 300.0;  --  in the bar, past the buttons
   Page_At   : constant := 100.0;  --  across and down

   --  Reading what is there

   function Image (Value : Integer) return String is
     (Ada.Strings.Fixed.Trim (Integer'Image (Value), Ada.Strings.Left));

   function Text_Of (Box : Widgets.Pixel_Box) return String is
     (Image (Box.Left) & "," & Image (Box.Top) & " "
      & Image (Box.Width) & "x" & Image (Box.Height));

   function Box_Of (Item : Widgets.Widget'Class) return Widgets.Pixel_Box is
     ((Left   => Integer (Widgets.Left_Of (Item)),
       Top    => Integer (Widgets.Top_Of (Item)),
       Width  => Integer (Widgets.Width_Of (Item)),
       Height => Integer (Widgets.Height_Of (Item))));

   procedure Check_Box
     (Name : String; Expected : String; Item : Widgets.Widget'Class) is
   begin
      Goldens.Check_Text (Name, Expected, Text_Of (Box_Of (Item)));
   end Check_Box;

   procedure Check_Flag (Name : String; Expected, Actual : Boolean) is
   begin
      Goldens.Check_Text (Name, Expected'Image, Actual'Image);
   end Check_Flag;

   --  Events, as SDL would give them, at X, Y points

   function Move (X, Y : Float; Held : Boolean := False) return Events.Event
   is ((Kind => Events.Mouse_Move, Mouse_X => X, Mouse_Y => Y,
        Left_Held => Held, others => <>));

   function Press (X, Y : Float) return Events.Event is
     ((Kind => Events.Mouse_Down, Button => 1, Clicks => 1,
       Mouse_X => X, Mouse_Y => Y, others => <>));

   function Release (X, Y : Float) return Events.Event is
     ((Kind => Events.Mouse_Up, Button => 1,
       Mouse_X => X, Mouse_Y => Y, others => <>));

   procedure Send
     (Item : in out Fixture; Event : Events.Event; Taken : Boolean) is
      Handled : Boolean;
   begin
      Widgets.Dispatch (Item.Tree, Event, Handled);
      pragma Assert
        (Handled = Taken, "an event was not taken as it should be");
   end Send;

   function Clicked (Item : in out Fixture; Which : Natural) return Boolean is
      Result : Boolean;
   begin
      case Which is
         when 1 => Pomarine.Widgets.Buttons.Take_Click (Item.First, Result);
         when 2 => Pomarine.Widgets.Buttons.Take_Click (Item.Second, Result);
         when others => Pomarine.Widgets.Buttons.Take_Click (Item.Third, Result);
      end case;
      return Result;
   end Clicked;

   --  Drawing

   procedure Paint (Item : in out Fixture; Keep : Boolean := True) is
   begin
      Widgets.Paint (Item.Tree, Item.Target, Colors, Retained => Keep);
   end Paint;

   procedure Check_Painted
     (Item : in out Fixture; Name : String; Golden : Boolean := True)
   is
      Incremental, Everything : Images.Image;
   begin
      --  What is drawn by drawing what changed is what is drawn by
      --  drawing it all.
      Paint (Item);
      Images.Read (Incremental, Item.Target);
      Widgets.Invalidate_All (Item.Tree);
      Paint (Item);
      Images.Read (Everything, Item.Target);
      Goldens.Check_Same (Name & "-retained", Everything, Incremental);
      if Golden then
         Goldens.Check (Name, Incremental);
      end if;
   end Check_Painted;

   --  The tests

   procedure Layout is
      Item : Fixture;
   begin
      Open (Item);
      Check_Box ("widgets-layout-root", "0,0 720x400", Item.Root);
      Check_Box ("widgets-layout-bar", "0,0 720x64", Item.Bar);
      Check_Box ("widgets-layout-first", "8,8 160x48", Item.First);
      Check_Box ("widgets-layout-second", "176,8 160x48", Item.Second);
      Check_Box ("widgets-layout-third", "344,8 160x48", Item.Third);
      Check_Box ("widgets-layout-page", "16,80 688x304", Item.Page);

      --  Everything was placed, so all is damaged, and the window is to
      --  be drawn.
      Goldens.Check_Text
        ("widgets-layout-damage", "0,0 720x400",
         Text_Of (Widgets.Damage (Item.Tree)));
      Check_Flag ("widgets-layout-needs-paint", True,
                  Widgets.Needs_Paint (Item.Tree));

      Paint (Item);
      Check_Flag ("widgets-layout-painted", False,
                  Widgets.Needs_Paint (Item.Tree));

      --  Laying out again, with nothing changed, damages nothing.
      Widgets.Layout (Item.Tree, Item.Target);
      Check_Flag ("widgets-layout-again", False,
                  Widgets.Needs_Paint (Item.Tree));

      --  Restyling moves only what it moves: the buttons after the first
      --  are pushed right, and the bar is not. Damage is where they were
      --  and where they are.
      Nodes.Set_Width (Widgets.Node (Item.First), 100.0 * Density);
      Widgets.Request_Layout (Item.First);
      Check_Flag ("widgets-layout-restyled", True,
                  Widgets.Needs_Paint (Item.Tree));
      Widgets.Layout (Item.Tree, Item.Target);
      Check_Box ("widgets-layout-wider", "8,8 200x48", Item.First);
      Check_Box ("widgets-layout-pushed", "216,8 160x48", Item.Second);
      Goldens.Check_Text
        ("widgets-layout-restyled-damage", "8,8 536x48",
         Text_Of (Widgets.Damage (Item.Tree)));
   end Layout;

   procedure Wild_Layout is
      Item : Fixture;
      Huge : constant Float := 1.0E12;
   begin
      Open (Item);
      Paint (Item);

      --  Beyond what an Integer holds: it was a Constraint_Error in placing.
      Nodes.Set_Height (Widgets.Node (Item.First), Huge);
      Widgets.Request_Layout (Item.First);
      Widgets.Layout (Item.Tree, Item.Target);
      Check_Flag ("widgets-wild-huge-damaged", True, Widgets.Needs_Paint (Item.Tree));
      Check_Flag
        ("widgets-wild-huge-kept", True,
         Widgets.Damage (Item.Tree).Height in 1 .. 2 ** 29);

      --  Wild in both ways, it is placed still.
      Nodes.Set_Width (Widgets.Node (Item.Second), Huge);
      Nodes.Set_Height (Widgets.Node (Item.Second), Huge);
      Widgets.Request_Layout (Item.Second);
      Widgets.Layout (Item.Tree, Item.Target);
      Check_Flag ("widgets-wild-both-damaged", True, Widgets.Needs_Paint (Item.Tree));

      --  And drawn, clipped to the window.
      Paint (Item);
      Check_Flag ("widgets-wild-painted", False, Widgets.Needs_Paint (Item.Tree));
   end Wild_Layout;

   procedure Idle is
      Item : Fixture;
   begin
      Open (Item);
      Check_Painted (Item, "widgets-idle");
   end Idle;

   procedure Buttons is
      Item : Fixture;
   begin
      Open (Item);
      Paint (Item);

      --  The pointer over a button changes how only it looks.
      Send (Item, Move (First_At, Bar_Y), Taken => False);
      Check_Flag ("widgets-buttons-hovered", True,
                  Widgets.Is_Hovered (Item.First));
      Check_Flag ("widgets-buttons-bar-hovered", True,
                  Widgets.Is_Hovered (Item.Bar));
      Check_Flag ("widgets-buttons-second-not", False,
                  Widgets.Is_Hovered (Item.Second));
      Goldens.Check_Text
        ("widgets-buttons-hover-damage", "8,8 160x48",
         Text_Of (Widgets.Damage (Item.Tree)));
      Check_Painted (Item, "widgets-buttons-hover");

      --  Moving within it changes nothing.
      Send (Item, Move (First_At + 5.0, Bar_Y), Taken => False);
      Check_Flag ("widgets-buttons-moved-within", False,
                  Widgets.Needs_Paint (Item.Tree));

      --  Pressing it, and letting go over it, is a click.
      Send (Item, Press (First_At, Bar_Y), Taken => True);
      Check_Flag ("widgets-buttons-pressed", True,
                  Pomarine.Widgets.Buttons.Is_Pressed (Item.First));
      Check_Painted (Item, "widgets-buttons-pressed");
      Send (Item, Release (First_At, Bar_Y), Taken => True);
      Check_Flag ("widgets-buttons-clicked", True, Clicked (Item, 1));
      Check_Flag ("widgets-buttons-clicked-once", False, Clicked (Item, 1));
      Check_Flag ("widgets-buttons-let-go", False,
                  Pomarine.Widgets.Buttons.Is_Pressed (Item.First));

      --  Pressing it and letting go elsewhere is not. The button still
      --  has the pointer's release, though it is over another.
      Send (Item, Press (First_At, Bar_Y), Taken => True);
      Send (Item, Move (Second_At, Bar_Y, Held => True), Taken => False);
      Check_Flag ("widgets-buttons-dragged-off", False,
                  Pomarine.Widgets.Buttons.Is_Pressed (Item.First));
      Check_Flag ("widgets-buttons-dragged-onto", True,
                  Widgets.Is_Hovered (Item.Second));
      Check_Painted (Item, "widgets-buttons-dragged-off", Golden => False);
      Send (Item, Release (Second_At, Bar_Y), Taken => True);
      Check_Flag ("widgets-buttons-not-clicked", False, Clicked (Item, 1));
      Check_Flag ("widgets-buttons-not-clicked-other", False,
                  Clicked (Item, 2));

      --  A press on the bar, which takes nothing, is taken by no one.
      Send (Item, Press (Gap_At, Bar_Y), Taken => True);
      --  (It took the text area's focus away: see Focus.)
      Send (Item, Release (Gap_At, Bar_Y), Taken => False);

      --  The label is changed with the usual care.
      Pomarine.Widgets.Buttons.Set_Label (Item.Third, "Three");
      Check_Flag ("widgets-buttons-same-label", False,
                  Widgets.Needs_Paint (Item.Tree) and then False);
      Paint (Item);
      Pomarine.Widgets.Buttons.Set_Label (Item.Third, "3");
      Goldens.Check_Text
        ("widgets-buttons-label-damage", "344,8 160x48",
         Text_Of (Widgets.Damage (Item.Tree)));
   end Buttons;

   procedure Focus is
      Item : Fixture;
   begin
      Open (Item);
      Check_Flag ("widgets-focus-initial", True,
                  Widgets.Has_Focus (Item.Page));

      --  A click on a button, which takes none, keeps the focus.
      Send (Item, Press (First_At, Bar_Y), Taken => True);
      Send (Item, Release (First_At, Bar_Y), Taken => True);
      Check_Flag ("widgets-focus-kept", True, Widgets.Has_Focus (Item.Page));
      Check_Flag ("widgets-focus-kept-in-editor", True,
                  Pomarine.Widgets.Editors.Is_Focused (Item.Page));

      --  Typing goes to the text area.
      Send (Item, Events.Text_Event ("!"), Taken => True);
      Goldens.Check_Text
        ("widgets-focus-typed", "!Great skua", Docs.Whole (Item.Doc));

      --  A click where nothing takes it takes the focus away, and is
      --  taken; typing then goes nowhere.
      Send (Item, Press (Gap_At, Bar_Y), Taken => True);
      Send (Item, Release (Gap_At, Bar_Y), Taken => False);
      Check_Flag ("widgets-focus-lost", False, Widgets.Has_Focus (Item.Page));
      Check_Flag ("widgets-focus-lost-in-editor", False,
                  Pomarine.Widgets.Editors.Is_Focused (Item.Page));
      Check_Flag ("widgets-focus-none", True,
                  Widgets.Focus_Of (Item.Tree) = null);
      Send (Item, Events.Text_Event ("?"), Taken => False);
      Goldens.Check_Text
        ("widgets-focus-not-typed", "!Great skua", Docs.Whole (Item.Doc));

      --  A click in the text area gives it back.
      Send (Item, Press (Page_At, Page_At), Taken => True);
      Send (Item, Release (Page_At, Page_At), Taken => False);
      Check_Flag ("widgets-focus-regained", True,
                  Widgets.Has_Focus (Item.Page));

      --  Escape leaves it, and the tree knows.
      Send (Item,
            (Kind => Events.Key_Down, Key => Events.Key_Escape,
             others => <>),
            Taken => True);
      Check_Flag ("widgets-focus-escaped", False,
                  Widgets.Has_Focus (Item.Page));

      --  Keys nobody has the focus for still reach the text area, which
      --  scrolls: a shortcut.
      Send (Item,
            (Kind => Events.Key_Down, Key => Events.Key_Page_Down,
             others => <>),
            Taken => True);
   end Focus;

   procedure Damage is
      Item : Fixture;
   begin
      Open (Item, "Great skua" & ASCII.LF & "Bonxie");
      Paint (Item);

      --  Nothing to do, nothing damaged. The time passing, within a
      --  blink, changes nothing.
      Widgets.Update (Item.Tree, 400);
      Check_Flag ("widgets-damage-quiet", False,
                  Widgets.Needs_Paint (Item.Tree));
      Goldens.Check_Text
        ("widgets-damage-wait", " 100",
         Integer'Image (Widgets.Until_Update (Item.Tree)));

      --  The caret hiding damages around the caret, not the text area.
      Widgets.Update (Item.Tree, 600);
      Check_Flag ("widgets-damage-blink", True,
                  Widgets.Needs_Paint (Item.Tree));
      declare
         Part : constant Widgets.Pixel_Box := Widgets.Damage (Item.Tree);
      begin
         Check_Flag ("widgets-damage-blink-small", True,
                     Part.Width < 40 and then Part.Height < 80);
         Check_Flag ("widgets-damage-blink-in-page", True,
                     Part.Left >= 16 and then Part.Top >= 80);
      end;
      Check_Painted (Item, "widgets-damage-blink-off");
      Widgets.Update (Item.Tree, 1100);
      Check_Painted (Item, "widgets-damage-blink-on", Golden => False);

      --  The document changed by someone else is noticed.
      Docs.Replace
        (Item.Doc, Docs.Text_End (Item.Doc), Docs.Text_End (Item.Doc),
         " and skua");
      Check_Flag ("widgets-damage-unseen", False,
                  Widgets.Needs_Paint (Item.Tree));
      Widgets.Update (Item.Tree, 1110);
      Goldens.Check_Text
        ("widgets-damage-document", "16,80 688x304",
         Text_Of (Widgets.Damage (Item.Tree)));
      Check_Painted (Item, "widgets-damage-edited");

      --  The wheel scrolls it, once there is more than fits.
      Docs.Replace
        (Item.Doc, Docs.Text_End (Item.Doc), Docs.Text_End (Item.Doc),
         [for Line in 1 .. 40 => ASCII.LF] & "last");
      Paint (Item);
      Send (Item,
            (Kind => Events.Mouse_Wheel, Wheel_Y => -2.0,
             Mouse_X => Page_At, Mouse_Y => Page_At, others => <>),
            Taken => True);
      Goldens.Check_Text
        ("widgets-damage-wheel", "16,80 688x304",
         Text_Of (Widgets.Damage (Item.Tree)));

      --  Over the bar it is not taken.
      Paint (Item);
      Send (Item,
            (Kind => Events.Mouse_Wheel, Wheel_Y => -2.0,
             Mouse_X => Gap_At, Mouse_Y => Bar_Y, others => <>),
            Taken => False);
      Check_Flag ("widgets-damage-wheel-bar", False,
                  Widgets.Needs_Paint (Item.Tree));

      --  A panel's colour, set to what it is, damages nothing; changed,
      --  only it.
      Panels.Set_Fill_Color (Item.Bar, (52, 54, 66, 255));
      Check_Flag ("widgets-damage-same-fill", False,
                  Widgets.Needs_Paint (Item.Tree));
      Panels.Set_Fill_Color (Item.Bar, (80, 60, 40, 255));
      Goldens.Check_Text
        ("widgets-damage-fill", "0,0 720x64",
         Text_Of (Widgets.Damage (Item.Tree)));
      Check_Painted (Item, "widgets-damage-fill");
   end Damage;

   procedure Retained is
      Item : Fixture;
   begin
      Open (Item, "Great skua" & ASCII.LF & "Bonxie" & ASCII.LF
            & "Arctic skua");
      Check_Painted (Item, "widgets-retained-start", Golden => False);

      --  A run of things, each drawn by drawing what it changed.
      Send (Item, Move (Second_At, Bar_Y), Taken => False);
      Check_Painted (Item, "widgets-retained-hover", Golden => False);
      Send (Item, Press (Second_At, Bar_Y), Taken => True);
      Check_Painted (Item, "widgets-retained-press", Golden => False);
      Send (Item, Move (Third_At, Bar_Y, Held => True), Taken => False);
      Check_Painted (Item, "widgets-retained-drag", Golden => False);
      Send (Item, Release (Third_At, Bar_Y), Taken => True);
      Check_Painted (Item, "widgets-retained-release", Golden => False);
      Send (Item, Press (Page_At, Page_At), Taken => True);
      Send (Item, Move (Page_At + 60.0, Page_At, Held => True),
            Taken => True);
      Check_Painted (Item, "widgets-retained-select", Golden => True);
      Send (Item, Release (Page_At + 60.0, Page_At), Taken => False);
      Send (Item, Events.Text_Event ("Bonxies"), Taken => True);
      Check_Painted (Item, "widgets-retained-typed", Golden => False);
      Widgets.Update (Item.Tree, 800);
      Check_Painted (Item, "widgets-retained-blink", Golden => False);
      Widgets.Set_Settled (Item.Tree, False);
      Check_Painted (Item, "widgets-retained-unsettled", Golden => False);
      Widgets.Set_Settled (Item.Tree, True);
      Pomarine.Widgets.Editors.Set_Zoom (Item.Page, 2.0);
      Widgets.Layout (Item.Tree, Item.Target);
      Check_Painted (Item, "widgets-retained-zoomed", Golden => True);
   end Retained;

   procedure Resized is
      Item : Fixture;
   begin
      Open (Item);
      Paint (Item);

      --  A target of another size is drawn all, and the widgets are
      --  fitted to it, though nothing said so.
      Renderers.Resize
        (Item.Target,
         Positive (Float (Width - 100) * Density),
         Positive (Float (Height + 40) * Density));
      Check_Painted (Item, "widgets-resized");
      Check_Box ("widgets-resized-page", "16,80 488x384", Item.Page);

      --  Another density puts them all again.
      Widgets.Set_Density (Item.Tree, 3.0);
      Check_Flag ("widgets-resized-density", True,
                  Widgets.Needs_Paint (Item.Tree));
   end Resized;

   procedure Tree_Walk is
      Item : Fixture;
   begin
      Open (Item);
      Goldens.Check_Text
        ("widgets-walk-count", " 2",
         Natural'Image (Widgets.Child_Count (Item.Root)));
      Goldens.Check_Text
        ("widgets-walk-bar", " 3",
         Natural'Image (Widgets.Child_Count (Item.Bar)));
      Check_Flag ("widgets-walk-child", True,
                  Widgets.Child_At (Item.Bar, 2)
                  = Widgets.Widget_Access'(Item.Second'Unchecked_Access));
      Check_Flag ("widgets-walk-parent", True,
                  Widgets.Parent_Of (Item.Page)
                  = Widgets.Widget_Access'(Item.Root'Unchecked_Access));

      --  What is where: the last of the deepest.
      Check_Flag ("widgets-walk-hit-button", True,
                  Widgets.Hit (Item.Tree, 20.0, 20.0)
                  = Widgets.Widget_Access'(Item.First'Unchecked_Access));
      Check_Flag ("widgets-walk-hit-bar", True,
                  Widgets.Hit (Item.Tree, 600.0, 20.0)
                  = Widgets.Widget_Access'(Item.Bar'Unchecked_Access));
      Check_Flag ("widgets-walk-hit-page", True,
                  Widgets.Hit (Item.Tree, 300.0, 300.0)
                  = Widgets.Widget_Access'(Item.Page'Unchecked_Access));
      Check_Flag ("widgets-walk-hit-outside", True,
                  Widgets.Hit (Item.Tree, 800.0, 20.0) = null);
   end Tree_Walk;

   procedure Toolbar is
      Item : Fixture;
      Lines : aliased Pomarine.Line_Texts.Drawer;
      Page : constant access Pomarine.Text_Areas.Text_Area := Pomarine.Widgets.Editors.Area (Item.Page);
      Height_Before, Content_Before : Float;

      function Visible_Buttons return Natural is
         Count : Natural := 0;
      begin
         for Each in 1 .. Widgets.Child_Count (Item.Page) loop
            if Widgets.Is_Visible (Widgets.Child_At (Item.Page, Each).all) then
               Count := Count + 1;
            end if;
         end loop;
         return Count;
      end Visible_Buttons;
   begin
      Open (Item, "Great skua" & ASCII.LF & "Bonxie");
      Widgets.Set_Line_Texts (Item.Tree, Lines);
      Check_Flag ("widgets-toolbar-none", True, Widgets.Child_Count (Item.Page) = 0);
      Height_Before := Widgets.Height_Of (Item.Page);
      Content_Before := Pomarine.Text_Areas.Content_Height (Page.all);

      --  Given one, there it is, whether or not it has the focus, below
      --  which the text is, and the layout does not move.
      Pomarine.Widgets.Editors.Set_Toolbar (Item.Page);
      Widgets.Layout (Item.Tree, Item.Target);
      Check_Flag ("widgets-toolbar-buttons", True, Visible_Buttons = 9);
      Check_Flag ("widgets-toolbar-same-height", True, Widgets.Height_Of (Item.Page) = Height_Before);
      Check_Flag ("widgets-toolbar-room", True,
                  Pomarine.Text_Areas.Content_Height (Page.all)
                  = Content_Before + Pomarine.Text_Areas.Toolbar_Points);
      Check_Painted (Item, "widgets-toolbar");
      Widgets.Release_Focus (Item.Page);
      Widgets.Layout (Item.Tree, Item.Target);
      Check_Flag ("widgets-toolbar-unfocused", True, Visible_Buttons = 9);
      Check_Painted (Item, "widgets-toolbar-unfocused");

      --  A button formats the selection, and the text keeps the focus.
      Widgets.Focus (Item.Page);
      Pomarine.Text_Areas.Select_Range (Page.all, (1, 1), (1, 6));
      declare
         Bold : constant Widgets.Widget_Access := Widgets.Child_At (Item.Page, 1);
         X : constant Float := (Widgets.Left_Of (Bold.all) + Widgets.Width_Of (Bold.all) / 2.0) / Density;
         Y : constant Float := (Widgets.Top_Of (Bold.all) + Widgets.Height_Of (Bold.all) / 2.0) / Density;
      begin
         Send (Item, Press (X, Y), Taken => True);
         Send (Item, Release (X, Y), Taken => True);
      end;
      Check_Flag ("widgets-toolbar-bold", True, Docs.Has_Format (Item.Doc, (1, 1), (1, 6), Docs.Bold));
      Check_Flag ("widgets-toolbar-focused", True, Pomarine.Widgets.Editors.Is_Focused (Item.Page));
      Check_Flag ("widgets-toolbar-selection", True, Pomarine.Text_Areas.Selected_Text (Page.all) = "Great");
      Check_Painted (Item, "widgets-toolbar-bold");

      --  Taken away, they go.
      Pomarine.Widgets.Editors.Set_Toolbar (Item.Page, False);
      Widgets.Layout (Item.Tree, Item.Target);
      Check_Flag ("widgets-toolbar-removed", True, Visible_Buttons = 0);
   end Toolbar;

   type Taps is limited record
      Count : Natural := 0;
   end record;

   package Counting is new Pomarine.Widgets.Callbacks (Taps);

   procedure Tapped
     (Item : in out Taps; From : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (From, Event);
   begin
      Item.Count := Item.Count + 1;
   end Tapped;

   type Uses is limited record
      Count : Natural := 0;
      Last  : Natural := 0;
   end record;

   package Using_Tools is new Pomarine.Widgets.Callbacks (Uses);

   procedure Used
     (Item : in out Uses; From : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (From);
   begin
      Item.Count := Item.Count + 1;
      Item.Last := Event.Row;
   end Used;

   function Key (Which : Events.Key_Code; Command : Boolean := False) return Events.Event is
     ((Kind => Events.Key_Down, Key => Which, Command => Command, others => <>));

   procedure Toolbar_Tools is
      use all type Widgets.Event_Kind;
      Item   : Fixture;
      Lines  : aliased Pomarine.Line_Texts.Drawer;
      Heard  : aliased Uses;
      Page   : constant access Pomarine.Text_Areas.Text_Area := Pomarine.Widgets.Editors.Area (Item.Page);
      Ignored : Boolean;
   begin
      Open (Item, "Great skua");
      Widgets.Set_Line_Texts (Item.Tree, Lines);
      Using_Tools.On (Item.Page, Use_Tool, Heard'Unrestricted_Access, Used'Access);
      Pomarine.Widgets.Editors.Set_Toolbar (Item.Page);
      Pomarine.Widgets.Editors.Add_Tool (Item.Page, "Plain", Key => 'p');
      Pomarine.Widgets.Editors.Add_Tool (Item.Page, "Picky", Key => 'j', Needs_Selection => True);
      Widgets.Layout (Item.Tree, Item.Target);
      Check_Flag ("widgets-tools-count", True, Pomarine.Widgets.Editors.Tool_Count (Item.Page) = 2);

      --  The key, with Command, while the text has the focus, and what is selected if it needs it.
      Widgets.Dispatch (Item.Tree, Key (Events.Key_Code (Character'Pos ('p')), True), Ignored);
      Widgets.Deliver (Item.Tree);
      Check_Flag ("widgets-tools-key", True, Heard.Count = 1 and then Heard.Last = 1);
      Widgets.Dispatch (Item.Tree, Key (Events.Key_Code (Character'Pos ('j')), True), Ignored);
      Widgets.Deliver (Item.Tree);
      Check_Flag ("widgets-tools-needs-selection", True, Heard.Count = 1);
      Pomarine.Text_Areas.Select_Range (Page.all, (1, 1), (1, 6));
      Widgets.Update (Item.Tree, 100);
      Widgets.Dispatch (Item.Tree, Key (Events.Key_Code (Character'Pos ('j')), True), Ignored);
      Widgets.Deliver (Item.Tree);
      Check_Flag ("widgets-tools-selected", True, Heard.Count = 2 and then Heard.Last = 2);
      Check_Flag ("widgets-tools-key-taken", True, Pomarine.Text_Areas.Selected_Text (Page.all) = "Great");
      Check_Painted (Item, "widgets-toolbar-tools");
   end Toolbar_Tools;

   procedure Toolbar_Editing is
      use type Texts.Paragraph_Kind;
      Item  : Fixture;
      Lines : aliased Pomarine.Line_Texts.Drawer;
      Page  : constant access Pomarine.Text_Areas.Text_Area := Pomarine.Widgets.Editors.Area (Item.Page);
      Bullet : constant String := Character'Val (16#E2#) & Character'Val (16#80#) & Character'Val (16#A2#) & " ";
      Undone, Redone : Texts.Position;

      procedure Check_Whole (Name, Expected : String) is
      begin
         Goldens.Check_Text (Name, Expected, Docs.Whole (Item.Doc));
      end Check_Whole;
   begin
      Open (Item, "one" & ASCII.LF & "two" & ASCII.LF & "three");
      Widgets.Set_Line_Texts (Item.Tree, Lines);
      Pomarine.Widgets.Editors.Set_Toolbar (Item.Page);
      Widgets.Layout (Item.Tree, Item.Target);

      --  Lists and quotations mark each paragraph the selection touches.
      Pomarine.Text_Areas.Select_Range (Page.all, (1, 2), (3, 3));
      Pomarine.Text_Areas.Toggle_Block (Page.all, Pomarine.Text_Areas.Bullets);
      Check_Whole ("editing-bullets", Bullet & "one" & ASCII.LF & Bullet & "two" & ASCII.LF & Bullet & "three");
      Check_Flag ("editing-bullets-active", True,
                  Pomarine.Text_Areas.Block_Active (Page.all, Pomarine.Text_Areas.Bullets));
      Pomarine.Text_Areas.Toggle_Block (Page.all, Pomarine.Text_Areas.Numbers);
      Check_Whole ("editing-numbers", "1. one" & ASCII.LF & "2. two" & ASCII.LF & "3. three");
      --  A quotation or an indent is how the paragraph sits, not its text.
      Pomarine.Text_Areas.Toggle_Block (Page.all, Pomarine.Text_Areas.Quote);
      Check_Whole ("editing-quote", "1. one" & ASCII.LF & "2. two" & ASCII.LF & "3. three");
      Check_Flag ("editing-quote-set", True,
                  Docs.Inset (Item.Doc, 1).Quoted and then Docs.Inset (Item.Doc, 3).Quoted
                  and then Pomarine.Text_Areas.Block_Active (Page.all, Pomarine.Text_Areas.Quote));
      declare
         Copy : Docs.Document;
      begin
         Check_Flag ("editing-quote-stored", True,
                     Ada.Strings.Fixed.Index (Docs.Stored (Item.Doc), "<p q=""1"">1. one</p>") > 0);
         Docs.Load_Stored (Copy, Docs.Stored (Item.Doc));
         Check_Flag ("editing-quote-reloaded", True,
                     Docs.Inset (Copy, 2).Quoted and then Docs.Whole (Copy) = Docs.Whole (Item.Doc));
      end;
      Pomarine.Text_Areas.Toggle_Block (Page.all, Pomarine.Text_Areas.Quote);
      Check_Flag ("editing-quote-off", True, not Docs.Inset (Item.Doc, 2).Quoted);

      --  One step each.
      Docs.Undo (Item.Doc, Undone, Redone);
      Check_Flag ("editing-undo", True, Docs.Inset (Item.Doc, 2).Quoted);

      --  Indent is steps, and does not touch the text or a mark.
      Pomarine.Text_Areas.Select_Range (Page.all, (2, 1), (2, 1));
      Pomarine.Text_Areas.Shift_Indent (Page.all, Outward => False);
      Pomarine.Text_Areas.Shift_Indent (Page.all, Outward => False);
      Check_Whole ("editing-indent", "1. one" & ASCII.LF & "2. two" & ASCII.LF & "3. three");
      Check_Flag ("editing-indent-steps", True,
                  Docs.Inset (Item.Doc, 2).Indent = 2 and then Docs.Inset (Item.Doc, 1).Indent = 0);
      Pomarine.Text_Areas.Shift_Indent (Page.all, Outward => True);
      Check_Flag ("editing-outdent", True, Docs.Inset (Item.Doc, 2).Indent = 1);
      Pomarine.Text_Areas.Shift_Indent (Page.all, Outward => True);
      Pomarine.Text_Areas.Shift_Indent (Page.all, Outward => True);
      Check_Flag ("editing-outdent-floor", True, Docs.Inset (Item.Doc, 2).Indent = 0);
      Pomarine.Text_Areas.Shift_Indent (Page.all, Outward => False);
      Pomarine.Text_Areas.Toggle_Block (Page.all, Pomarine.Text_Areas.Bullets);
      Check_Whole ("editing-indent-mark", "1. one" & ASCII.LF & Bullet & "two" & ASCII.LF & "1. three");

      --  A paragraph's style is kept in what is stored.
      Pomarine.Text_Areas.Select_Range (Page.all, (1, 1), (1, 1));
      Pomarine.Text_Areas.Set_Style (Page.all, Texts.Heading_2);
      Check_Flag ("editing-style", True, Docs.Kind (Item.Doc, 1) = Texts.Heading_2);
      Check_Flag ("editing-style-seen", True, Pomarine.Text_Areas.Paragraph_Style (Page.all) = Texts.Heading_2);
      declare
         Copy : Docs.Document;
      begin
         Docs.Load_Stored (Copy, Docs.Stored (Item.Doc));
         Check_Flag ("editing-style-stored", True,
                     Docs.Kind (Copy, 1) = Texts.Heading_2 and then Docs.Kind (Copy, 2) = Texts.Plain);
      end;
      Docs.Undo (Item.Doc, Undone, Redone);
      Check_Flag ("editing-style-undone", True, Docs.Kind (Item.Doc, 1) = Texts.Plain);
      Check_Painted (Item, "widgets-toolbar-editing");

      --  Return in a list starts the next item, on an empty item it ends the list; Shift+Return leaves it.
      declare
         Ignored : Boolean;

         procedure Press_Return (Shifted : Boolean) is
         begin
            Widgets.Dispatch
              (Item.Tree, (Kind => Events.Key_Down, Key => Events.Key_Return, Shift => Shifted, others => <>),
               Ignored);
         end Press_Return;
      begin
         Docs.Replace (Item.Doc, (1, 1), Docs.Text_End (Item.Doc), "1. one");
         Pomarine.Text_Areas.Select_Range (Page.all, (1, 7), (1, 7));
         Press_Return (False);
         Check_Whole ("editing-return-number", "1. one" & ASCII.LF & "2. ");
         Press_Return (False);
         Check_Whole ("editing-return-empty", "1. one" & ASCII.LF);
         Docs.Replace (Item.Doc, (1, 1), Docs.Text_End (Item.Doc), Bullet & "a");
         Pomarine.Text_Areas.Select_Range (Page.all, (1, 6), (1, 6));
         Press_Return (True);
         Check_Whole ("editing-shift-return", Bullet & "a" & ASCII.LF);
         Docs.Replace (Item.Doc, (1, 1), Docs.Text_End (Item.Doc), "1. a" & ASCII.LF & "2. b" & ASCII.LF & "3. c");
         Pomarine.Text_Areas.Select_Range (Page.all, (1, 5), (1, 5));
         Press_Return (False);
         Check_Whole ("editing-return-renumber", "1. a" & ASCII.LF & "2. " & ASCII.LF & "3. b" & ASCII.LF & "4. c");
         Press_Return (False);
         Check_Whole ("editing-return-end-renumber", "1. a" & ASCII.LF & ASCII.LF & "1. b" & ASCII.LF & "2. c");
         Pomarine.Text_Areas.Select_Range (Page.all, (3, 1), (3, 1));
         Pomarine.Text_Areas.Toggle_Block (Page.all, Pomarine.Text_Areas.Numbers);
         Check_Whole ("editing-toggle-renumber", "1. a" & ASCII.LF & ASCII.LF & "b" & ASCII.LF & "1. c");
         declare
            procedure Press_Back is
            begin
               Widgets.Dispatch
                 (Item.Tree, (Kind => Events.Key_Down, Key => Events.Key_Backspace, others => <>), Ignored);
            end Press_Back;
         begin
            Docs.Replace (Item.Doc, (1, 1), Docs.Text_End (Item.Doc), "1. a" & ASCII.LF & "2. b" & ASCII.LF & "3. c");
            Pomarine.Text_Areas.Select_Range (Page.all, (2, 1), (2, 1));
            Press_Back;
            Check_Whole ("editing-backspace-join", "1. ab" & ASCII.LF & "2. c");
            Docs.Replace (Item.Doc, (1, 1), Docs.Text_End (Item.Doc), "1. a" & ASCII.LF & "2. b" & ASCII.LF & "3. c");
            Pomarine.Text_Areas.Select_Range (Page.all, (2, 4), (2, 4));
            Press_Back;
            Check_Whole ("editing-backspace-mark", "1. a" & ASCII.LF & "b" & ASCII.LF & "1. c");
            Docs.Replace (Item.Doc, (1, 1), Docs.Text_End (Item.Doc), "1. a" & ASCII.LF & "2. b" & ASCII.LF & "3. c");
            Pomarine.Text_Areas.Select_Range (Page.all, (1, 1), (1, 1));
            Pomarine.Text_Areas.Insert (Page.all, "x");
            Check_Whole ("editing-type-before-mark", "1. xa" & ASCII.LF & "2. b" & ASCII.LF & "3. c");
         end;
      end;
   end Toolbar_Editing;

   procedure Toolbar_Fonts is
      use type Texts.Paragraph_Kind;
      Item    : Fixture;
      Lines   : aliased Pomarine.Line_Texts.Drawer;
      Page    : constant access Pomarine.Text_Areas.Text_Area := Pomarine.Widgets.Editors.Area (Item.Page);
      Ignored : Boolean;

      --  The middle of a point, in the editor, in points in the window.
      function X_At (Points : Float) return Float is (Widgets.Left_Of (Item.Page) / Density + Points);
      function Y_At (Points : Float) return Float is (Widgets.Top_Of (Item.Page) / Density + Points);

      procedure Click (X, Y : Float) is
      begin
         Widgets.Dispatch (Item.Tree, Press (X, Y), Ignored);
         Widgets.Dispatch (Item.Tree, Release (X, Y), Ignored);
         Widgets.Deliver (Item.Tree);
         Widgets.Layout (Item.Tree, Item.Target);
      end Click;

      function Visible_Count return Natural is
         Count : Natural := 0;
      begin
         for Each in 1 .. Widgets.Child_Count (Item.Page) loop
            if Widgets.Is_Visible (Widgets.Child_At (Item.Page, Each).all) then
               Count := Count + 1;
            end if;
         end loop;
         return Count;
      end Visible_Count;

      Closed : Natural;
      Before : Float;

      Size_X  : constant Float := 374.0 + 112.0 + 6.0 + 30.0;
      Style_X : constant Float := 374.0 + 112.0 + 6.0 + 68.0 + 6.0 + 48.0;
      Menu_Y  : constant Float := 39.0;
   begin
      Open (Item, "Great skua" & ASCII.LF & "Bonxie", Wide => 760);
      Widgets.Set_Line_Texts (Item.Tree, Lines);
      Pomarine.Widgets.Editors.Set_Toolbar (Item.Page);
      Widgets.Layout (Item.Tree, Item.Target);
      Closed := Visible_Count;
      Check_Flag ("fonts-controls", True, Closed = 13);
      Goldens.Check_Text ("fonts-family", "Georgia", Pomarine.Widgets.Editors.Font_Family (Item.Page));
      Check_Flag ("fonts-size", True, Pomarine.Widgets.Editors.Font_Size (Item.Page) = 18.0);
      Check_Painted (Item, "widgets-toolbar-fonts");

      --  The size's menu opens under it, and a click on its third row, 10 pt, sizes what is selected.
      Pomarine.Text_Areas.Select_Range (Page.all, (1, 1), (1, 6));
      Widgets.Update (Item.Tree, 100);
      Before := Pomarine.Text_Areas.Content_Height (Page.all);
      Click (X_At (Size_X), Y_At (21.0));
      Check_Flag ("fonts-size-menu", True, Visible_Count = Closed + 1);
      Check_Painted (Item, "widgets-toolbar-size-menu");
      Click (X_At (Size_X), Y_At (Menu_Y + 3.0 + 2.0 * 26.0 + 13.0));
      Check_Flag ("fonts-size-chosen", True, Docs.Size_At (Item.Doc, (1, 1), (1, 6)) = 10);
      Check_Flag ("fonts-size-only-selected", True, Docs.Size_At (Item.Doc, (2, 1), (2, 3)) = 0);
      Check_Flag ("fonts-size-base-kept", True, Pomarine.Widgets.Editors.Font_Size (Item.Page) = 18.0);
      Check_Painted (Item, "widgets-toolbar-sized");
      Check_Flag ("fonts-menu-closed", True, Visible_Count = Closed);
      --  The paragraph still has text of the larger size, so its lines are as high as ever.
      Check_Flag ("fonts-size-line-kept", True, Pomarine.Text_Areas.Content_Height (Page.all) = Before);

      --  Another opened and closed by clicking it again.
      Click (X_At (Size_X), Y_At (21.0));
      Click (X_At (Size_X), Y_At (21.0));
      Check_Flag ("fonts-menu-toggled", True, Visible_Count = Closed);

      --  The style's third row, Heading 2, for the paragraph the caret is in.
      Pomarine.Text_Areas.Select_Range (Page.all, (2, 1), (2, 1));
      Click (X_At (Style_X), Y_At (21.0));
      Click (X_At (Style_X), Y_At (Menu_Y + 3.0 + 2.0 * 26.0 + 13.0));
      Check_Flag ("fonts-style-chosen", True, Docs.Kind (Item.Doc, 2) = Texts.Heading_2);
      Check_Flag ("fonts-style-first-kept", True, Docs.Kind (Item.Doc, 1) = Texts.Plain);
      Check_Painted (Item, "widgets-toolbar-heading");

      --  A family of its own for part of a word, in the middle of the sized text.
      Pomarine.Text_Areas.Select_Range (Page.all, (1, 3), (1, 5));
      Pomarine.Text_Areas.Set_Family (Page.all, "Menlo");
      Goldens.Check_Text ("fonts-family-here", "Menlo", Pomarine.Text_Areas.Family_Here (Page.all));
      Check_Flag ("fonts-family-outside", True, Docs.Family_At (Item.Doc, (1, 1), (1, 2)) = "");
      Widgets.Update (Item.Tree, 200);
      Widgets.Layout (Item.Tree, Item.Target);
      Check_Painted (Item, "widgets-toolbar-mixed");
      declare
         Copy : Docs.Document;
      begin
         Docs.Load_Stored (Copy, Docs.Stored (Item.Doc));
         Check_Flag ("fonts-stored", True,
                     Docs.Family_At (Copy, (1, 3), (1, 5)) = "Menlo"
                     and then Docs.Size_At (Copy, (1, 1), (1, 2)) = 10
                     and then Docs.Size_At (Copy, (1, 5), (1, 6)) = 10
                     and then Docs.Family_At (Copy, (1, 5), (1, 6)) = "");
         Goldens.Check_Text ("fonts-stored-text", Docs.Whole (Item.Doc), Docs.Whole (Copy));
      end;

      --  Typed text takes the size and family of what is before it.
      Pomarine.Text_Areas.Select_Range (Page.all, (1, 4), (1, 4));
      Pomarine.Text_Areas.Insert (Page.all, "x");
      Check_Flag ("fonts-typed", True, Docs.Size_At (Item.Doc, (1, 4), (1, 5)) = 10
                  and then Docs.Family_At (Item.Doc, (1, 4), (1, 5)) = "Menlo");

      --  Any family, in code, for the text that has none of its own.
      Pomarine.Widgets.Editors.Set_Font (Item.Page, "Menlo", 14.0);
      Widgets.Layout (Item.Tree, Item.Target);
      Goldens.Check_Text ("fonts-set-family", "Menlo", Pomarine.Widgets.Editors.Font_Family (Item.Page));
   end Toolbar_Fonts;

   procedure Links is
      use all type Widgets.Event_Kind;
      Item    : Fixture;
      Asked   : aliased Taps;
      Before  : Natural;
      Lines   : aliased Pomarine.Line_Texts.Drawer;
      Page    : constant access Pomarine.Text_Areas.Text_Area := Pomarine.Widgets.Editors.Area (Item.Page);
      Ignored : Boolean;
      Plain   : constant String := "";

      function Button_X return Float is (Widgets.Left_Of (Item.Page) / Density + 343.0);
      function Button_Y return Float is (Widgets.Top_Of (Item.Page) / Density + 21.0);

      procedure Press_Key (Which : Events.Key_Code; Command : Boolean := False) is
      begin
         Widgets.Dispatch (Item.Tree, Key (Which, Command), Ignored);
         Widgets.Deliver (Item.Tree);
         Widgets.Layout (Item.Tree, Item.Target);
      end Press_Key;

      function Link_Of (Place : Texts.Position) return String is
        (Docs.Link_At (Item.Doc, Place, Place));
   begin
      Open (Item, "see here now", Wide => 760);
      Widgets.Set_Line_Texts (Item.Tree, Lines);
      Counting.On (Item.Page, Ask_Link, Asked'Unrestricted_Access, Tapped'Access);
      Pomarine.Widgets.Editors.Set_Toolbar (Item.Page);
      Widgets.Layout (Item.Tree, Item.Target);

      --  With nothing selected there is nothing to link.
      Press_Key (Events.Key_K, Command => True);
      Check_Flag ("widgets-link-needs-selection", False, Pomarine.Widgets.Editors.Is_Linking (Item.Page));

      --  Command+K asks, by a bubble, and nothing is linked until it is accepted.
      Pomarine.Text_Areas.Select_Range (Page.all, (1, 5), (1, 9));
      Press_Key (Events.Key_K, Command => True);
      Check_Flag ("widgets-link-asking", True, Pomarine.Widgets.Editors.Is_Linking (Item.Page));
      Goldens.Check_Text ("widgets-link-empty-field", Plain, Pomarine.Widgets.Editors.Link_Address (Item.Page));
      Pomarine.Widgets.Editors.Set_Link_Address (Item.Page, "example.org");
      Widgets.Layout (Item.Tree, Item.Target);
      Check_Painted (Item, "widgets-link-bubble");
      Check_Flag ("widgets-link-not-yet", True, Docs.Link_At (Item.Doc, (1, 5), (1, 9)) = "");

      --  Return accepts it; a domain with no scheme is made https.
      Press_Key (Events.Key_Return);
      Check_Flag ("widgets-link-accepted", False, Pomarine.Widgets.Editors.Is_Linking (Item.Page));
      Goldens.Check_Text ("widgets-link-made", "https://example.org", Link_Of ((1, 6)));
      Goldens.Check_Text ("widgets-link-outside", Plain, Link_Of ((1, 2)));
      Check_Painted (Item, "widgets-link-made");

      --  Asked again, the field has the address; Escape gives it up and leaves it.
      Pomarine.Text_Areas.Select_Range (Page.all, (1, 5), (1, 9));
      Press_Key (Events.Key_K, Command => True);
      Goldens.Check_Text
        ("widgets-link-prefilled", "https://example.org", Pomarine.Widgets.Editors.Link_Address (Item.Page));
      Pomarine.Widgets.Editors.Set_Link_Address (Item.Page, "https://other.org");
      Press_Key (Events.Key_Escape);
      Check_Flag ("widgets-link-escaped", False, Pomarine.Widgets.Editors.Is_Linking (Item.Page));
      Goldens.Check_Text ("widgets-link-kept", "https://example.org", Link_Of ((1, 6)));

      --  What is not an address is not taken: Return does nothing, and giving it up leaves the link.
      Press_Key (Events.Key_K, Command => True);
      Pomarine.Widgets.Editors.Set_Link_Address (Item.Page, "not an address");
      Press_Key (Events.Key_Return);
      Check_Flag ("widgets-link-refused", True, Pomarine.Widgets.Editors.Is_Linking (Item.Page));
      Pomarine.Widgets.Editors.Finish_Link (Item.Page, Keep => False);
      Goldens.Check_Text ("widgets-link-refused-kept", "https://example.org", Link_Of ((1, 6)));

      --  Accepted blank, the link goes; undo brings it back.
      Press_Key (Events.Key_K, Command => True);
      Pomarine.Widgets.Editors.Set_Link_Address (Item.Page, Plain);
      Press_Key (Events.Key_Return);
      Goldens.Check_Text ("widgets-link-taken-away", Plain, Link_Of ((1, 6)));
      Pomarine.Text_Areas.Undo (Page.all);
      Goldens.Check_Text ("widgets-link-undone", "https://example.org", Link_Of ((1, 6)));

      --  Blank, with no link to take away, is not taken.
      Pomarine.Text_Areas.Select_Range (Page.all, (1, 1), (1, 4));
      Press_Key (Events.Key_K, Command => True);
      Press_Key (Events.Key_Return);
      Check_Flag ("widgets-link-blank-refused", True, Pomarine.Widgets.Editors.Is_Linking (Item.Page));

      --  The toolbar's button, after the indent buttons, asks the same, and the tick is off while
      --  the field is not an address.
      Pomarine.Widgets.Editors.Finish_Link (Item.Page, Keep => False);
      Pomarine.Text_Areas.Select_Range (Page.all, (1, 10), (1, 13));
      Widgets.Update (Item.Tree, 100);
      Widgets.Layout (Item.Tree, Item.Target);
      Widgets.Dispatch (Item.Tree, Press (Button_X, Button_Y), Ignored);
      Widgets.Dispatch (Item.Tree, Release (Button_X, Button_Y), Ignored);
      Widgets.Deliver (Item.Tree);
      Widgets.Layout (Item.Tree, Item.Target);
      Check_Flag ("widgets-link-button", True, Pomarine.Widgets.Editors.Is_Linking (Item.Page));
      Pomarine.Widgets.Editors.Set_Link_Address (Item.Page, "mailto:a@b.org");
      Pomarine.Widgets.Editors.Finish_Link (Item.Page, Keep => True);
      Goldens.Check_Text ("widgets-link-button-made", "mailto:a@b.org", Link_Of ((1, 11)));

      --  The application may offer addresses: asked of it when the bubble begins, and the list is shown
      --  with the field, under it, once there are some.
      Pomarine.Text_Areas.Select_Range (Page.all, (1, 1), (1, 4));
      Before := Asked.Count;
      Press_Key (Events.Key_K, Command => True);
      Check_Flag ("widgets-link-asks", True, Asked.Count = Before + 1);
      Pomarine.Widgets.Editors.Add_Link_Choice (Item.Page, "Skua", "https://skua.org/");
      Pomarine.Widgets.Editors.Add_Link_Choice (Item.Page, "", "https://bonxie.org/");
      Widgets.Layout (Item.Tree, Item.Target);
      Check_Painted (Item, "widgets-link-sources");
      --  Its select, clicked, opens the list (over it, as there is no room under), and a row is the link.
      Widgets.Dispatch (Item.Tree, Press (225.0, 171.0), Ignored);
      Widgets.Dispatch (Item.Tree, Release (225.0, 171.0), Ignored);
      Widgets.Deliver (Item.Tree);
      Widgets.Layout (Item.Tree, Item.Target);
      Check_Painted (Item, "widgets-link-sources-open");
      Widgets.Dispatch (Item.Tree, Press (225.0, 133.0), Ignored);
      Widgets.Dispatch (Item.Tree, Release (225.0, 133.0), Ignored);
      Widgets.Deliver (Item.Tree);
      Widgets.Layout (Item.Tree, Item.Target);
      Check_Flag ("widgets-link-source-chosen", False, Pomarine.Widgets.Editors.Is_Linking (Item.Page));
      Goldens.Check_Text ("widgets-link-source-made", "https://bonxie.org/", Link_Of ((1, 2)));

      --  Saved and loaded, the links are as they were.
      declare
         Copy : Docs.Document;
      begin
         Docs.Load_Stored (Copy, Docs.Stored (Item.Doc));
         Goldens.Check_Text ("widgets-link-stored", Docs.Stored (Item.Doc), Docs.Stored (Copy));
      end;
   end Links;

   procedure Versions is
      Item   : Fixture;
      Lines  : aliased Pomarine.Line_Texts.Drawer;
      Page   : constant access Pomarine.Text_Areas.Text_Area := Pomarine.Widgets.Editors.Area (Item.Page);
      Ignored : Boolean;

      procedure Check_Stored (Name, Expected : String) is
      begin
         Goldens.Check_Text (Name, Expected, Docs.Stored (Item.Doc));
      end Check_Stored;

      procedure Press_Key (Which : Events.Key_Code) is
      begin
         Widgets.Dispatch (Item.Tree, Key (Which), Ignored);
      end Press_Key;

      procedure Click_Text (At_Place : Texts.Position) is
         X, Y, Wide, High : Float;
      begin
         Pomarine.Text_Areas.Select_Range (Page.all, At_Place, At_Place);
         Pomarine.Text_Areas.Caret_Box (Page.all, X, Y, Wide, High);
         Widgets.Dispatch (Item.Tree, Press ((X + 2.0) / Density, (Y + High / 2.0) / Density), Ignored);
         Widgets.Dispatch (Item.Tree, Release ((X + 2.0) / Density, (Y + High / 2.0) / Density), Ignored);
      end Click_Text;
   begin
      Open (Item, "say it plain");
      Widgets.Set_Line_Texts (Item.Tree, Lines);
      Pomarine.Widgets.Editors.Set_Toolbar (Item.Page);
      Widgets.Layout (Item.Tree, Item.Target);

      --  The text goes, and what is typed is the new version, taken by Return.
      Pomarine.Text_Areas.Select_Range (Page.all, (1, 5), (1, 7));
      Pomarine.Widgets.Editors.Begin_Version (Item.Page);
      Check_Flag ("widgets-versions-writing", True, Pomarine.Widgets.Editors.Is_Writing_Version (Item.Page));
      Goldens.Check_Text ("widgets-versions-gone", "say  plain", Docs.Whole (Item.Doc));
      Check_Flag ("widgets-versions-caret", True, Texts."=" (Pomarine.Text_Areas.Caret (Page.all), (1, 5)));
      Pomarine.Text_Areas.Insert (Page.all, "this");
      Widgets.Update (Item.Tree, 100);
      Widgets.Layout (Item.Tree, Item.Target);
      Check_Painted (Item, "widgets-versions-writing");
      Press_Key (Events.Key_Return);
      Check_Flag ("widgets-versions-done", False, Pomarine.Widgets.Editors.Is_Writing_Version (Item.Page));
      Check_Stored ("widgets-versions-kept", "<version>1</version><p>say <v sel=""2""><o>it</o>this</v> plain</p>");
      Widgets.Layout (Item.Tree, Item.Target);
      Check_Painted (Item, "widgets-versions-marked");

      --  Given up with Escape, it is as it was.
      Pomarine.Text_Areas.Select_Range (Page.all, (1, 6), (1, 7));
      Pomarine.Widgets.Editors.Begin_Version (Item.Page);
      Goldens.Check_Text ("widgets-versions-gone-all", "say  plain", Docs.Whole (Item.Doc));
      Pomarine.Text_Areas.Insert (Page.all, "zzz");
      Press_Key (Events.Key_Escape);
      Check_Stored ("widgets-versions-given-up", "<version>1</version><p>say <v sel=""2""><o>it</o>this</v> plain</p>");
      Check_Flag ("widgets-versions-not-redone", False, Docs.Can_Redo (Item.Doc));

      --  Nothing typed is nothing to keep.
      Pomarine.Text_Areas.Select_Range (Page.all, (1, 1), (1, 4));
      Pomarine.Widgets.Editors.Begin_Version (Item.Page);
      Press_Key (Events.Key_Return);
      Check_Stored ("widgets-versions-blank", "<version>1</version><p>say <v sel=""2""><o>it</o>this</v> plain</p>");

      --  Another version of the text that has them, from a selection of part of it.
      Pomarine.Text_Areas.Select_Range (Page.all, (1, 6), (1, 7));
      Pomarine.Widgets.Editors.Begin_Version (Item.Page);
      Pomarine.Text_Areas.Insert (Page.all, "that");
      Press_Key (Events.Key_Return);
      Check_Stored
        ("widgets-versions-third",
         "<version>1</version><p>say <v sel=""3""><o>it</o><o>this</o>that</v> plain</p>");

      --  Clicking it shows the bar, and the arrow keys, round the end.
      Click_Text ((1, 6));
      Widgets.Layout (Item.Tree, Item.Target);
      Check_Painted (Item, "widgets-versions-bar");
      Press_Key (Events.Key_Right_Arrow);
      Check_Stored
        ("widgets-versions-first-again",
         "<version>1</version><p>say <v sel=""1""><o>this</o><o>that</o>it</v> plain</p>");
      Press_Key (Events.Key_Left_Arrow);
      Check_Stored
        ("widgets-versions-last-again",
         "<version>1</version><p>say <v sel=""3""><o>it</o><o>this</o>that</v> plain</p>");
      Press_Key (Events.Key_Left_Arrow);
      Check_Stored
        ("widgets-versions-second-again",
         "<version>1</version><p>say <v sel=""2""><o>it</o><o>that</o>this</v> plain</p>");

      --  Escape puts the bar away, and the arrow keys are the caret's again.
      Press_Key (Events.Key_Escape);
      Widgets.Dispatch (Item.Tree, Move (300.0, 150.0), Ignored);
      Pomarine.Text_Areas.Select_Range (Page.all, (1, 1), (1, 1));
      Press_Key (Events.Key_Right_Arrow);
      Check_Flag ("widgets-versions-arrow-moves", True, Texts."=" (Pomarine.Text_Areas.Caret (Page.all), (1, 2)));

      --  Typed in bold, it is a bold version, and goes through with it.
      Pomarine.Text_Areas.Select_Range (Page.all, (1, 5), (1, 9));
      Pomarine.Widgets.Editors.Begin_Version (Item.Page);
      Pomarine.Text_Areas.Toggle_Format (Page.all, Docs.Bold);
      Pomarine.Text_Areas.Insert (Page.all, "bold");
      Press_Key (Events.Key_Return);
      Check_Stored
        ("widgets-versions-bold",
         "<version>1</version><p>say <v sel=""4""><o>it</o><o>this</o><o>that</o><b>bold</b></v> plain</p>");
      Click_Text ((1, 6));
      Press_Key (Events.Key_Right_Arrow);
      Check_Stored
        ("widgets-versions-bold-gone",
         "<version>1</version><p>say <v sel=""1""><o>this</o><o>that</o><o><b>bold</b></o>it</v> plain</p>");
      Press_Key (Events.Key_Left_Arrow);
      Check_Stored
        ("widgets-versions-bold-back",
         "<version>1</version><p>say <v sel=""4""><o>it</o><o>this</o><o>that</o><b>bold</b></v> plain</p>");
      Check_Flag ("widgets-versions-pointer", True,
                  SDL3.Cursors."=" (Pomarine.Widgets.Editors.Cursor (Item.Page), SDL3.Cursors.Pointer));
      Widgets.Dispatch (Item.Tree, Move (300.0, 150.0), Ignored);
      Check_Flag ("widgets-versions-text-cursor", True,
                  SDL3.Cursors."=" (Pomarine.Widgets.Editors.Cursor (Item.Page), SDL3.Cursors.Text));
   end Versions;

   procedure Caret_Only is
      Item : Fixture;
      Text : constant String :=
        "Great skua" & ASCII.LF & "Bonxie" & ASCII.LF & "Arctic skua"
        & ASCII.LF & "Pomarine skua" & ASCII.LF & "Long-tailed skua";
      Before, After : Natural;

      function Drawn return Natural is
        (Pomarine.Text_Areas.Lines_Drawn (Pomarine.Widgets.Editors.Area (Item.Page).all));
   begin
      Open (Item, Text);
      Paint (Item);
      Before := Drawn;
      Check_Flag ("widgets-caret-all-lines", True, Before >= 5);

      --  The caret hiding and showing draws the line it is in, and no
      --  more of the page.
      Widgets.Update (Item.Tree, 600);
      Paint (Item);
      After := Drawn;
      Goldens.Check_Text
        ("widgets-caret-hides", " 1", Natural'Image (After - Before));
      Widgets.Update (Item.Tree, 1100);
      Paint (Item);
      Goldens.Check_Text
        ("widgets-caret-shows", " 1", Natural'Image (Drawn - After));
      Check_Painted (Item, "widgets-caret-same", Golden => False);

      --  Anything else of the text area is drawn as before: its text is.
      Send (Item, Events.Text_Event ("!"), Taken => True);
      Before := Drawn;
      Paint (Item);
      Check_Flag ("widgets-caret-typed-all", True, Drawn - Before >= 5);
   end Caret_Only;

   procedure Hiding is
      Item  : Fixture;
      Start : Images.Image;
      Again : Images.Image;
   begin
      Open (Item);
      Paint (Item);
      Images.Read (Start, Item.Target);

      --  Hidden, a button takes no room: the next moves up to it.
      Widgets.Set_Visible (Item.Second, False);
      Check_Flag ("widgets-hiding-hidden", False,
                  Widgets.Is_Visible (Item.Second));
      Check_Flag ("widgets-hiding-needs-paint", True,
                  Widgets.Needs_Paint (Item.Tree));
      Widgets.Layout (Item.Tree, Item.Target);
      Check_Box ("widgets-hiding-first", "8,8 160x48", Item.First);
      Check_Box ("widgets-hiding-second", "0,0 0x0", Item.Second);
      Check_Box ("widgets-hiding-third", "176,8 160x48", Item.Third);
      Goldens.Check_Text
        ("widgets-hiding-damage", "176,8 328x48",
         Text_Of (Widgets.Damage (Item.Tree)));
      Check_Painted (Item, "widgets-hiding");

      --  What was there is now what moved up to it.
      Check_Flag ("widgets-hiding-hit", True,
                  Widgets.Hit (Item.Tree, Second_At * Density, Bar_Y * Density)
                  = Widgets.Widget_Access'(Item.Third'Unchecked_Access));
      Send (Item, Press (Second_At, Bar_Y), Taken => True);
      Send (Item, Release (Second_At, Bar_Y), Taken => True);
      Check_Flag ("widgets-hiding-clicked-third", True, Clicked (Item, 3));
      Check_Flag ("widgets-hiding-not-second", False, Clicked (Item, 2));

      --  Shown again, it is as it was, the pointer being off it.
      Send (Item, Move (Gap_At, Bar_Y), Taken => False);
      Widgets.Set_Visible (Item.Second, True);
      Paint (Item);
      Images.Read (Again, Item.Target);
      Goldens.Check_Same ("widgets-hiding-shown", Start, Again);
      Check_Box ("widgets-hiding-shown-second", "176,8 160x48", Item.Second);

      --  Hiding what holds others hides them, whose own settings stay.
      Widgets.Set_Visible (Item.Bar, False);
      Check_Flag ("widgets-hiding-child-visible", True,
                  Widgets.Is_Visible (Item.First));
      Check_Flag ("widgets-hiding-child-shown", False,
                  Widgets.Is_Shown (Item.First));
      Check_Painted (Item, "widgets-hiding-bar", Golden => False);
      Check_Flag ("widgets-hiding-bar-hit", True,
                  Widgets.Hit (Item.Tree, 4.0, 4.0)
                  = Widgets.Widget_Access'(Item.Root'Unchecked_Access));
      Check_Flag ("widgets-hiding-bar-page-up", True,
                  Widgets.Hit (Item.Tree, 20.0, 20.0)
                  = Widgets.Widget_Access'(Item.Page'Unchecked_Access));

      --  A hidden widget has not the focus, and does not wake the loop.
      Check_Flag ("widgets-hiding-focused", True,
                  Widgets.Has_Focus (Item.Page));
      Check_Flag ("widgets-hiding-wakes", True,
                  Widgets.Until_Update (Item.Tree) >= 0);
      Widgets.Set_Visible (Item.Page, False);
      Check_Flag ("widgets-hiding-lost-focus", False,
                  Widgets.Has_Focus (Item.Page));
      Check_Flag ("widgets-hiding-no-focus", True,
                  Widgets.Focus_Of (Item.Tree) = null);
      Check_Flag ("widgets-hiding-quiet", True,
                  Widgets.Until_Update (Item.Tree) < 0);
      Send (Item, Events.Text_Event ("?"), Taken => False);
      Goldens.Check_Text
        ("widgets-hiding-not-typed", "Great skua", Docs.Whole (Item.Doc));
      Check_Painted (Item, "widgets-hiding-all", Golden => False);

      Widgets.Set_Visible (Item.Page, True);
      Widgets.Set_Visible (Item.Bar, True);
      Check_Painted (Item, "widgets-hiding-restored", Golden => False);
      Check_Box ("widgets-hiding-restored-page", "16,80 688x304", Item.Page);
   end Hiding;

   procedure Removing is
      Item : Fixture;
   begin
      Open (Item);
      Paint (Item);

      Widgets.Remove (Item.Second);
      Check_Flag ("widgets-removing-attached", False,
                  Widgets.Is_Attached (Item.Second));
      Check_Flag ("widgets-removing-parent", True,
                  Widgets.Parent_Of (Item.Second) = null);
      Goldens.Check_Text
        ("widgets-removing-count", " 2",
         Natural'Image (Widgets.Child_Count (Item.Bar)));
      Check_Flag ("widgets-removing-needs-paint", True,
                  Widgets.Needs_Paint (Item.Tree));
      Widgets.Layout (Item.Tree, Item.Target);
      Check_Box ("widgets-removing-third", "176,8 160x48", Item.Third);
      Goldens.Check_Text
        ("widgets-removing-damage", "176,8 328x48",
         Text_Of (Widgets.Damage (Item.Tree)));
      Check_Flag ("widgets-removing-child", True,
                  Widgets.Child_At (Item.Bar, 2)
                  = Widgets.Widget_Access'(Item.Third'Unchecked_Access));
      Check_Painted (Item, "widgets-removing");

      --  Put back, it is last, and is styled again.
      Widgets.Add (Item.Bar, Item.Second);
      Nodes.Set_Width (Widgets.Node (Item.Second), 80.0 * Density);
      Widgets.Layout (Item.Tree, Item.Target);
      Check_Box ("widgets-removing-added-third", "176,8 160x48", Item.Third);
      Check_Box ("widgets-removing-added", "344,8 160x48", Item.Second);
      Check_Painted (Item, "widgets-removing-added", Golden => False);

      --  A press, taken by what is removed before it is let go, goes
      --  nowhere, and the pointer is over what it was in.
      Send (Item, Move (First_At, Bar_Y), Taken => False);
      Send (Item, Press (First_At, Bar_Y), Taken => True);
      Widgets.Remove (Item.First);
      Check_Flag ("widgets-removing-unhovered", False,
                  Widgets.Is_Hovered (Item.First));
      Check_Flag ("widgets-removing-bar-hovered", True,
                  Widgets.Is_Hovered (Item.Bar));
      Send (Item, Release (First_At, Bar_Y), Taken => False);
      Check_Flag ("widgets-removing-not-clicked", False, Clicked (Item, 1));
      Check_Painted (Item, "widgets-removing-first", Golden => False);

      --  The focus goes with what had it, and so with what it is in.
      Check_Flag ("widgets-removing-focused", True,
                  Widgets.Has_Focus (Item.Page));
      Widgets.Remove (Item.Page);
      Check_Flag ("widgets-removing-no-focus", True,
                  Widgets.Focus_Of (Item.Tree) = null);
      Check_Flag ("widgets-removing-unfocused", False,
                  Pomarine.Widgets.Editors.Is_Focused (Item.Page));
      Check_Painted (Item, "widgets-removing-page", Golden => False);

      --  A whole branch goes, and is not in the tree: nor are its parts.
      Widgets.Remove (Item.Bar);
      Check_Flag ("widgets-removing-branch", False,
                  Widgets.Is_Attached (Item.Third));
      Goldens.Check_Text
        ("widgets-removing-branch-count", " 0",
         Natural'Image (Widgets.Child_Count (Item.Bar)));
      Goldens.Check_Text
        ("widgets-removing-root-count", " 0",
         Natural'Image (Widgets.Child_Count (Item.Root)));
      Check_Painted (Item, "widgets-removing-bare", Golden => False);

      --  And can be built again, below another, and show as before.
      Widgets.Add (Item.Root, Item.Bar);
      Widgets.Add (Item.Bar, Item.Third);
      Nodes.Set_Flex_Direction (Widgets.Node (Item.Bar), Yoga.Row);
      Nodes.Set_Height (Widgets.Node (Item.Bar), 32.0 * Density);
      Nodes.Set_Padding
        (Widgets.Node (Item.Bar), Yoga.All_Edges, 4.0 * Density);
      Nodes.Set_Width (Widgets.Node (Item.Third), 80.0 * Density);
      Panels.Set_Fill_Color (Item.Bar, (52, 54, 66, 255));
      Widgets.Layout (Item.Tree, Item.Target);
      Check_Box ("widgets-removing-rebuilt", "8,8 160x48", Item.Third);
      Check_Painted (Item, "widgets-removing-rebuilt");
   end Removing;

   --  A window, to draw in as it keeps the frame: with SDL's dummy video
   --  driver, unless another is asked for, so that it needs no display.

   procedure In_Window;
   --  The body of Window_Frame, which has SDL initialized for it.

   procedure Window_Frame is
   begin
      if not Ada.Environment_Variables.Exists ("SDL_VIDEODRIVER") then
         Ada.Environment_Variables.Set ("SDL_VIDEODRIVER", "dummy");
      end if;
      SDL3.Initialize;
      In_Window;
      --  After the window and its renderer are gone.
      SDL3.Shutdown;
   end Window_Frame;

   procedure In_Window is
      Win    : SDL3.Windows.Window;
      Target : Renderers.Renderer;  --  after Win
      Tree   : Widgets.Tree;
      Root   : aliased Panels.Panel;
      Side   : aliased Panels.Panel;
      Main   : aliased Panels.Panel;
      Incremental, Everything : Images.Image;
      Changed : Boolean;
      Wide, High : Natural;

      procedure Frame is
      begin
         Widgets.Paint (Tree, Target, Colors, Retained => True);
         Renderers.Present (Target);
      end Frame;

      procedure Check_Frame (Name : String) is
      begin
         --  After the frame was presented, what is drawn is still there.
         Images.Read (Incremental, Target);
         Widgets.Invalidate_All (Tree);
         Widgets.Paint (Tree, Target, Colors, Retained => True);
         Images.Read (Everything, Target);
         Goldens.Check_Same (Name, Everything, Incremental);
      end Check_Frame;
   begin
      SDL3.Windows.Create (Win, "test", 360, 200, Resizable => True);
      Renderers.Create (Target, Win, VSync => False);
      Check_Flag ("widgets-window-keeps", True,
                  Renderers.Keeps_Frame (Target));

      Widgets.Set_Density (Tree, SDL3.Windows.Pixel_Density (Win));
      Widgets.Set_Root (Tree, Root);
      Widgets.Add (Root, Side);
      Widgets.Add (Root, Main);
      Nodes.Set_Flex_Direction (Widgets.Node (Root), Yoga.Row);
      Nodes.Set_Width (Widgets.Node (Side), 100.0);
      Nodes.Set_Flex_Grow (Widgets.Node (Main), 1.0);
      Panels.Set_Fill_Color (Side, (52, 54, 66, 255));
      Panels.Set_Fill_Color (Main, (200, 120, 40, 255));
      Frame;

      --  A change drawn after the frame went to the window draws only
      --  that, over what the last frame left.
      Panels.Set_Fill_Color (Side, (40, 80, 120, 255));
      Goldens.Check_Text
        ("widgets-window-damage", "0,0 100x200",
         Text_Of (Widgets.Damage (Tree)));
      Frame;
      Check_Frame ("widgets-window-retained");

      --  Not being the size of the window, it is fitted.
      Renderers.Fit (Target, Changed);
      Check_Flag ("widgets-window-fit-same", False, Changed);
      SDL3.Windows.Set_Size (Win, 300, 150);
      Renderers.Fit (Target, Changed);
      Check_Flag ("widgets-window-fit", True, Changed);
      Renderers.Output_Size (Target, Wide, High);
      Goldens.Check_Text
        ("widgets-window-fit-size", "300x150",
         Image (Wide) & "x" & Image (High));
      Frame;
      Check_Frame ("widgets-window-resized");
      Check_Box ("widgets-window-main", "100,0 200x150", Main);
   end In_Window;

end Widget_Tests;
