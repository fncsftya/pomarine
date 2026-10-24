with Pomarine.Marks;
with Pomarine.Pages;
with Pomarine.Page_Builds;
with Pomarine.Widgets.Page_Views;
with Pomarine.Mark_Paths;
with Pomarine.Events;
with SDL3.Pictures.Jobs;
with SDL3.Windows.Renderers;
with Goldens;
with Pomarine.Clipboards;
with Pomarine.Themes;
with Pomarine.Words;
with Pomarine.Widgets.Panels;
with Pomarine.Widgets.Pictures;
with Yoga.Nodes;

package body Picture_Tests is

   package Events renames Pomarine.Events;
   package Renderers renames SDL3.Windows.Renderers;
   package Images renames Goldens.Images;
   package Widgets renames Pomarine.Widgets;
   package Pictures renames Pomarine.Widgets.Pictures;
   package Nodes renames Yoga.Nodes;

   Colors  : constant Pomarine.Themes.Theme := Pomarine.Themes.Light;
   Density : constant Float := 2.0;
   Width   : constant := 360;
   Height  : constant := 200;
   --  In points.

   Picture_File : constant String := "golden/textarea-typing.png";
   --  Any picture will do: the words are made up.

   --  Three lines of words, where a picture's text would be.
   Text_Of_Words : constant String :=
     "alphabetagammadeltaepsilonzeta";

   Found : aliased Pomarine.Words.Result;

   procedure Word
     (Index : Positive; First, Last, Line : Positive;
      Left, Top, Wide : Float) is
   begin
      Found.Words (Index) :=
        (Line => Line, First => First, Last => Last,
         Left => Left, Top => Top, Width => Wide, Height => 0.06);
   end Word;

   procedure Make_Words is
   begin
      Pomarine.Words.Reserve (Found, 6, Text_Of_Words'Length);
      Found.Text (1 .. Text_Of_Words'Length) := Text_Of_Words;
      Found.Length := Text_Of_Words'Length;
      Found.Count := 6;
      Word (1, 1, 5, 1, 0.05, 0.10, 0.20);    --  alpha
      Word (2, 6, 9, 1, 0.30, 0.10, 0.15);    --  beta
      Word (3, 10, 14, 1, 0.50, 0.10, 0.25);  --  gamma
      Word (4, 15, 19, 2, 0.05, 0.25, 0.20);  --  delta
      Word (5, 20, 26, 2, 0.30, 0.25, 0.30);  --  epsilon
      Word (6, 27, 30, 3, 0.05, 0.40, 0.15);  --  zeta
   end Make_Words;

   type Fixture is limited record
      Tree    : Widgets.Tree;
      Target  : Renderers.Renderer;
      Board   : Pomarine.Clipboards.Memory_Clipboard;
      Root    : aliased Pomarine.Widgets.Panels.Panel;
      Picture : aliased Pictures.Picture;
   end record;

   procedure Open (Item : in out Fixture) is
   begin
      Make_Words;
      Renderers.Create_Offscreen
        (Item.Target,
         Positive (Float (Width) * Density),
         Positive (Float (Height) * Density));
      Widgets.Set_Density (Item.Tree, Density);
      Widgets.Set_Clipboard (Item.Tree, Item.Board);
      Widgets.Set_Root (Item.Tree, Item.Root);
      Widgets.Add (Item.Root, Item.Picture);
      Nodes.Set_Flex_Grow (Widgets.Node (Item.Picture), 1.0);
      Pictures.Set_File (Item.Picture, Picture_File);
      Pictures.Set_Words (Item.Picture, Found'Access);
      Widgets.Layout (Item.Tree, Item.Target);
      Widgets.Paint (Item.Tree, Item.Target, Colors);
      --  The picture is read in the background, when first drawn.
      SDL3.Pictures.Jobs.Wait_Until_Idle;
      Widgets.Invalidate (Item.Picture);
      Widgets.Paint (Item.Tree, Item.Target, Colors);
   end Open;

   --  Where, in points, the middle of a word is.

   function At_X (Item : Fixture; Index : Positive) return Float is
     (Float (Pictures.Word_Box (Item.Picture, Index).Left
             + Pictures.Word_Box (Item.Picture, Index).Width / 2) / Density);

   function At_Y (Item : Fixture; Index : Positive) return Float is
     (Float (Pictures.Word_Box (Item.Picture, Index).Top
             + Pictures.Word_Box (Item.Picture, Index).Height / 2) / Density);

   procedure Send
     (Item : in out Fixture; Event : Events.Event; Taken : Boolean) is
      Handled : Boolean;
   begin
      Widgets.Dispatch (Item.Tree, Event, Handled);
      pragma Assert
        (Handled = Taken, "an event was not taken as it should be");
      Widgets.Paint (Item.Tree, Item.Target, Colors);
   end Send;

   function Press (X, Y : Float; Clicks : Natural := 1) return Events.Event is
     ((Kind => Events.Mouse_Down, Button => 1, Clicks => Clicks,
       Mouse_X => X, Mouse_Y => Y, others => <>));

   function Move (X, Y : Float) return Events.Event is
     ((Kind => Events.Mouse_Move, Mouse_X => X, Mouse_Y => Y,
       Left_Held => True, others => <>));

   function Release (X, Y : Float) return Events.Event is
     ((Kind => Events.Mouse_Up, Button => 1,
       Mouse_X => X, Mouse_Y => Y, others => <>));

   function Chord (Key : Events.Key_Code) return Events.Event is
     ((Kind => Events.Key_Down, Key => Key, Command => True, others => <>));

   procedure Check_Selected (Name, Expected : String; Item : Fixture) is
   begin
      Goldens.Check_Text
        (Name, Expected, Pictures.Selected_Text (Item.Picture));
   end Check_Selected;

   procedure Selecting is
      Item  : Fixture;
      Plain : Images.Image;
   begin
      Open (Item);
      Images.Read (Plain, Item.Target);
      Goldens.Check_Text
        ("picture-words", " 6",
         Natural'Image (Pictures.Word_Count (Item.Picture)));
      Goldens.Check_Text
        ("picture-none-selected", "",
         Pictures.Selected_Text (Item.Picture));

      --  A drag from one word to another selects those between, in
      --  reading order, with a space within a line and a break between.
      Send (Item, Press (At_X (Item, 2), At_Y (Item, 2)), Taken => True);
      Send (Item, Move (At_X (Item, 4), At_Y (Item, 4)), Taken => True);
      Send (Item, Release (At_X (Item, 4), At_Y (Item, 4)), Taken => True);
      Check_Selected
        ("picture-dragged", "beta gamma" & ASCII.LF & "delta", Item);
      declare
         Drawn : Images.Image;
      begin
         Images.Read (Drawn, Item.Target);
         Goldens.Check ("picture-selection", Drawn);
      end;

      --  The other way round is the same words.
      Send (Item, Press (At_X (Item, 4), At_Y (Item, 4)), Taken => True);
      Send (Item, Move (At_X (Item, 2), At_Y (Item, 2)), Taken => True);
      Send (Item, Release (At_X (Item, 2), At_Y (Item, 2)), Taken => True);
      Check_Selected
        ("picture-dragged-back", "beta gamma" & ASCII.LF & "delta", Item);

      --  Off the words, a drag goes to the nearest.
      Send (Item, Press (At_X (Item, 1), At_Y (Item, 1)), Taken => True);
      Send
        (Item, Move (At_X (Item, 6), At_Y (Item, 6) + 12.0), Taken => True);
      Send (Item, Release (At_X (Item, 6), At_Y (Item, 6)), Taken => True);
      Check_Selected
        ("picture-dragged-off", "alpha beta gamma" & ASCII.LF & "delta epsilon"
         & ASCII.LF & "zeta", Item);

      --  A double click is a word, a triple a line.
      Send (Item, Press (At_X (Item, 5), At_Y (Item, 5), 2), Taken => True);
      Send (Item, Release (At_X (Item, 5), At_Y (Item, 5)), Taken => True);
      Check_Selected ("picture-word", "epsilon", Item);
      Send (Item, Press (At_X (Item, 5), At_Y (Item, 5), 2), Taken => True);
      Send (Item, Move (At_X (Item, 6), At_Y (Item, 6)), Taken => True);
      Check_Selected ("picture-word-drag-forward", "epsilon" & ASCII.LF & "zeta", Item);
      Send (Item, Move (At_X (Item, 4), At_Y (Item, 4)), Taken => True);
      Check_Selected ("picture-word-drag-back", "delta epsilon", Item);
      Send (Item, Move (At_X (Item, 5), At_Y (Item, 5)), Taken => True);
      Check_Selected ("picture-word-drag-origin", "epsilon", Item);
      Send (Item, Release (At_X (Item, 5), At_Y (Item, 5)), Taken => True);
      Send (Item, Press (At_X (Item, 5), At_Y (Item, 5), 3), Taken => True);
      Send (Item, Release (At_X (Item, 5), At_Y (Item, 5)), Taken => False);
      Check_Selected ("picture-line", "delta epsilon", Item);

      --  Copied.
      Send (Item, Chord (Events.Key_C), Taken => True);
      Goldens.Check_Text
        ("picture-copied", "delta epsilon", Pomarine.Clipboards.Text (Item.Board));

      --  All, then none: a click that is on no word clears it.
      Send (Item, Chord (Events.Key_A), Taken => True);
      Check_Selected
        ("picture-all",
         "alpha beta gamma" & ASCII.LF & "delta epsilon" & ASCII.LF & "zeta",
         Item);
      Send (Item, Press (1.0, 1.0), Taken => False);
      Check_Selected ("picture-cleared", "", Item);
      declare
         Drawn : Images.Image;
      begin
         --  Nothing of the selection is left on the picture.
         Images.Read (Drawn, Item.Target);
         Goldens.Check_Same ("picture-plain", Plain, Drawn);
      end;
   end Selecting;

   type Empty_Source is new Pomarine.Pages.Source with null record;
   overriding procedure Build
     (Item : in out Empty_Source; Index : Positive; Content : out Pomarine.Pages.Page_Access;
      Words : in out Pomarine.Words.Result; Ok : out Boolean);
   overriding procedure Measure
     (Item : in out Empty_Source; Count : Positive; Sizes : out Pomarine.Pages.Size_Array_Access;
      Ok : out Boolean);

   overriding procedure Build
     (Item : in out Empty_Source; Index : Positive; Content : out Pomarine.Pages.Page_Access;
      Words : in out Pomarine.Words.Result; Ok : out Boolean)
   is
      pragma Unreferenced (Item, Index, Words);
   begin
      Content := null;
      Ok := False;
   end Build;

   overriding procedure Measure
     (Item : in out Empty_Source; Count : Positive; Sizes : out Pomarine.Pages.Size_Array_Access;
      Ok : out Boolean)
   is
      pragma Unreferenced (Item, Count);
   begin
      Sizes := null;
      Ok := False;
   end Measure;

   Source : aliased Empty_Source;

   procedure Freehand_Pages is
      package Views renames Pomarine.Widgets.Page_Views;
      Tree : Widgets.Tree;
      Target : Renderers.Renderer;
      Root : aliased Pomarine.Widgets.Panels.Panel;
      View : aliased Views.Page_View;
      Sizes : Pomarine.Pages.Size_Array_Access := new Pomarine.Pages.Size_Array'[(360.0, 500.0)];
      Taken : Boolean;
      procedure Send_Page (Event : Events.Event) is
      begin
         Widgets.Dispatch (Tree, Event, Taken);
         Widgets.Paint (Tree, Target, Colors);
      end Send_Page;
   begin
      Renderers.Create_Offscreen (Target, Width, Height);
      Widgets.Set_Root (Tree, Root);
      Widgets.Add (Root, View);
      Nodes.Set_Flex_Grow (Widgets.Node (View), 1.0);
      Views.Set_Document (View, Sizes, Source'Access);
      Widgets.Layout (Tree, Target);
      Widgets.Paint (Tree, Target, Colors);
      Views.Set_Tool (View, Pictures.Highlighter);
      Send_Page (Press (80.0, 40.0));
      Send_Page (Move (80.0, 100.0));
      Send_Page (Move (140.0, 120.0));
      Send_Page (Release (100.0, 60.0));
      pragma Assert (Views.Mark_Count (View) = 1);
      pragma Assert (Views.Mark_At (View, 1).Trace.Count = 4);
      pragma Assert (Views.Mark_At (View, 1).Page = 1);
      Views.Set_Zoom (View, 2.0);
      Widgets.Paint (Tree, Target, Colors);
      pragma Assert (Views.Mark_At (View, 1).Trace.Count = 4);
      Views.Set_Zoom (View, 1.0);
      Widgets.Paint (Tree, Target, Colors);
      Views.Set_Tool (View, Pictures.Eraser);
      Send_Page (Press (80.0, 70.0));
      Send_Page (Release (80.0, 70.0));
      pragma Assert (Views.Mark_Count (View) = 0);
      --  No OCR words are available: the picture still receives edit commands.
      Send_Page (Chord (Events.Key_Z));
      pragma Assert (Views.Mark_Count (View) = 1);
      Send_Page (Chord (Events.Key_Z));
      pragma Assert (Views.Mark_Count (View) = 0);
      Widgets.Perform_Command (Tree, Widgets.Edit_Redo, Taken);
      pragma Assert (Taken and then Views.Mark_Count (View) = 1);
      Send_Page ((Kind => Events.Key_Down, Key => Events.Key_Z, Command => True, Shift => True, others => <>));
      pragma Assert (Views.Mark_Count (View) = 0);
      Pomarine.Page_Builds.Wait_Until_Idle;
      Views.Clear_Document (View);
      pragma Assert (not Views.Can_Undo (View) and then not Views.Can_Redo (View));
      Pomarine.Pages.Free (Sizes);
   end Freehand_Pages;

   procedure Freehand is
      Item : Fixture;
      Trace : Pomarine.Mark_Paths.Path;
      use type Pomarine.Mark_Paths.Point;
   begin
      Open (Item);
      Pictures.Set_Tool (Item.Picture, Pictures.Highlighter);
      Send (Item, Press (80.0, 40.0), Taken => True);
      Send (Item, Move (80.0, 80.0), Taken => True);
      Send (Item, Move (140.0, 100.0), Taken => True);
      Send (Item, Move (100.0, 60.0), Taken => True);
      Send (Item, Release (60.0, 100.0), Taken => True);
      pragma Assert (Pictures.Mark_Count (Item.Picture) = 1);
      Trace := Pictures.Mark_At (Item.Picture, 1).Trace;
      pragma Assert (Trace.Count = 5);
      pragma Assert (Trace.Points (1).X = Trace.Points (2).X);
      pragma Assert (Trace.Points (1).Y < Trace.Points (2).Y);
      pragma Assert (Trace.Points (3).X > Trace.Points (4).X);
      declare
         Drawn : Images.Image;
      begin
         Images.Read (Drawn, Item.Target);
         Goldens.Check ("picture-freehand", Drawn);
      end;
      --  Retracing a mark has exactly the same pixels as drawing it once.
      declare
         Original : constant Pictures.Mark := Pictures.Mark_At (Item.Picture, 1);
         Drawn : Images.Image;
      begin
         Pictures.Set_Marks (Item.Picture, [Original, Original]);
         Widgets.Paint (Item.Tree, Item.Target, Colors);
         Images.Read (Drawn, Item.Target);
         Goldens.Check ("picture-freehand", Drawn);
         Pictures.Set_Marks (Item.Picture, [Original]);
      end;
      Pictures.Set_Tool (Item.Picture, Pictures.Eraser);
      Send (Item, Press (200.0, 150.0), Taken => True);
      Send (Item, Release (200.0, 150.0), Taken => False);
      pragma Assert (Pictures.Mark_Count (Item.Picture) = 1);
      Send (Item, Press (80.0, 60.0), Taken => True);
      Send (Item, Release (80.0, 60.0), Taken => False);
      pragma Assert (Pictures.Mark_Count (Item.Picture) = 0);

      --  A purely vertical drag is a stroke, whereas a click is not.
      Pictures.Set_Tool (Item.Picture, Pictures.Highlighter);
      Send (Item, Press (80.0, 40.0), Taken => True);
      Send (Item, Release (80.0, 100.0), Taken => True);
      pragma Assert (Pictures.Mark_Count (Item.Picture) = 1);
      Send (Item, Press (120.0, 40.0), Taken => True);
      Send (Item, Release (120.0, 40.0), Taken => True);
      pragma Assert (Pictures.Mark_Count (Item.Picture) = 1);

      --  On dark paper, white lettering becomes yellow and the paper stays dark.
      declare
         Dark_Page, Once, Twice : Images.Image;
         use type Renderers.Color_Component;
         File : constant String := Goldens.Scratch ("picture-dark-source.png");
         Band : constant Pictures.Mark := (Left => 0.0, Right => 1.0, Y => 0.25, others => <>);
         Ink, Paper : Renderers.Color;
      begin
         Images.Create (Dark_Page, 720, 400);
         for Y in 0 .. 399 loop
            for X in 0 .. 719 loop
               Images.Set_Pixel
                 (Dark_Page, X, Y, (if X in 50 .. 200 and then Y in 90 .. 110
                                then (255, 255, 255, 255) else (20, 20, 20, 255)));
            end loop;
         end loop;
         Images.Save_PNG (Dark_Page, File);
         Pictures.Set_File (Item.Picture, File);
         Widgets.Paint (Item.Tree, Item.Target, Pomarine.Themes.Dark);
         SDL3.Pictures.Jobs.Wait_Until_Idle;
         Widgets.Invalidate (Item.Picture);
         Pictures.Set_Marks (Item.Picture, [Band]);
         Widgets.Paint (Item.Tree, Item.Target, Pomarine.Themes.Dark);
         Images.Read (Once, Item.Target);
         Ink := Images.Pixel (Once, 100, 100);
         Paper := Images.Pixel (Once, 300, 100);
         pragma Assert (Ink.Red > 150 and then Ink.Blue < Ink.Red);
         pragma Assert (Paper.Red < 50 and then Paper.Green < 50 and then Paper.Blue < 50);
         Pictures.Set_Marks (Item.Picture, [Band, Band]);
         Widgets.Paint (Item.Tree, Item.Target, Pomarine.Themes.Dark);
         Images.Read (Twice, Item.Target);
         Goldens.Check_Same ("picture-dark-overlap", Once, Twice);
      end;

      --  Storage stays bounded even when there are many pointer events.
      Trace := (others => <>);
      for Index in 0 .. 1024 loop
         Pomarine.Mark_Paths.Append (Trace, Float (Index) / 1024.0, Float (Index mod 7) / 7.0);
      end loop;
      pragma Assert (Trace.Count <= Pomarine.Mark_Paths.Max_Points);
      pragma Assert (Trace.Points (1) = Pomarine.Mark_Paths.Point'(0.0, 0.0));
      pragma Assert (Trace.Points (Trace.Count).X = 1.0);
      pragma Assert (Pomarine.Mark_Paths.Contains (Trace, 100.0, Trace.Points (Trace.Count).Y * 100.0,
                                                 100.0, 100.0, 2.0));
   end Freehand;

   procedure Undoing_Marks is
      Item : Fixture;
      Taken : Boolean;
      First, Second : Pictures.Mark;
      Version : Natural;
      use type Pomarine.Marks.Mark;
   begin
      Open (Item);
      Pictures.Set_Words (Item.Picture, null);
      pragma Assert (not Pictures.Has_Words (Item.Picture));
      Pictures.Set_Tool (Item.Picture, Pictures.Highlighter);
      Send (Item, Press (80.0, 40.0), Taken => True);
      Send (Item, Move (80.0, 100.0), Taken => True);
      Send (Item, Release (120.0, 100.0), Taken => True);
      First := Pictures.Mark_At (Item.Picture, 1);
      Send (Item, Press (160.0, 40.0), Taken => True);
      Send (Item, Release (160.0, 100.0), Taken => True);
      Second := Pictures.Mark_At (Item.Picture, 2);
      pragma Assert (Pictures.Mark_Count (Item.Picture) = 2);
      Version := Pictures.Marks_Version (Item.Picture);
      Send (Item, Chord (Events.Key_Z), Taken => True);
      pragma Assert (Pictures.Mark_Count (Item.Picture) = 1 and then Pictures.Can_Redo (Item.Picture));
      pragma Assert (Pictures.Mark_At (Item.Picture, 1) = First);
      pragma Assert (Pictures.Marks_Version (Item.Picture) = Version + 1);
      Send (Item, Chord (Events.Key_Z), Taken => True);
      pragma Assert (Pictures.Mark_Count (Item.Picture) = 0);
      --  Empty history consumes Undo without changing the version.
      Version := Pictures.Marks_Version (Item.Picture);
      Send (Item, Chord (Events.Key_Z), Taken => True);
      pragma Assert (Pictures.Marks_Version (Item.Picture) = Version);
      Widgets.Perform_Command (Item.Tree, Widgets.Edit_Redo, Taken);
      pragma Assert (Taken and then Pictures.Mark_Count (Item.Picture) = 1);
      Send (Item, (Kind => Events.Key_Down, Key => Events.Key_Z, Command => True, Shift => True,
                   others => <>), Taken => True);
      pragma Assert (Pictures.Mark_At (Item.Picture, 2) = Second);

      Pictures.Set_Tool (Item.Picture, Pictures.Eraser);
      Send (Item, Press (80.0, 70.0), Taken => True);
      Send (Item, Release (80.0, 70.0), Taken => False);
      pragma Assert (Pictures.Mark_Count (Item.Picture) = 1);
      Send (Item, Chord (Events.Key_Z), Taken => True);
      pragma Assert (Pictures.Mark_Count (Item.Picture) = 2);
      pragma Assert (Pictures.Mark_At (Item.Picture, 1) = First);
      pragma Assert (Pictures.Mark_At (Item.Picture, 2) = Second);
      Widgets.Perform_Command (Item.Tree, Widgets.Edit_Redo, Taken);
      pragma Assert (Taken and then Pictures.Mark_Count (Item.Picture) = 1);
      Send (Item, Chord (Events.Key_Z), Taken => True);

      --  A new stroke after undo discards the redo branch; cancelling a
      --  preview or making a click does not consume an undo step.
      Pictures.Set_Tool (Item.Picture, Pictures.Highlighter);
      Send (Item, Press (200.0, 40.0), Taken => True);
      Send (Item, Move (200.0, 100.0), Taken => True);
      Send (Item, Chord (Events.Key_Z), Taken => True);
      Send (Item, Release (200.0, 100.0), Taken => False);
      pragma Assert (Pictures.Mark_Count (Item.Picture) = 2 and then Pictures.Can_Redo (Item.Picture));
      Send (Item, Press (200.0, 40.0), Taken => True);
      Send (Item, Release (200.0, 40.0), Taken => True);
      pragma Assert (Pictures.Can_Redo (Item.Picture));
      Send (Item, Press (200.0, 40.0), Taken => True);
      Send (Item, Release (200.0, 100.0), Taken => True);
      pragma Assert (Pictures.Mark_Count (Item.Picture) = 3 and then not Pictures.Can_Redo (Item.Picture));
      Pictures.Clear_Marks (Item.Picture);
      pragma Assert (not Pictures.Can_Undo (Item.Picture) and then not Pictures.Can_Redo (Item.Picture));

      --  The oldest edits expire within the fixed history capacity.
      for Index in 1 .. Pomarine.Marks.Undo_Depth + 1 loop
         Send (Item, Press (80.0, 40.0), Taken => True);
         Send (Item, Release (80.0, 100.0), Taken => True);
      end loop;
      for Index in 1 .. Pomarine.Marks.Undo_Depth loop
         Send (Item, Chord (Events.Key_Z), Taken => True);
      end loop;
      pragma Assert (Pictures.Mark_Count (Item.Picture) = 1 and then not Pictures.Can_Undo (Item.Picture));
      Pictures.Set_Marks (Item.Picture, [First]);
      pragma Assert (not Pictures.Can_Undo (Item.Picture) and then not Pictures.Can_Redo (Item.Picture));
   end Undoing_Marks;

   procedure Following_The_Picture is
      Item : Fixture;
   begin
      Open (Item);
      Send (Item, Press (At_X (Item, 1), At_Y (Item, 1)), Taken => True);
      Send (Item, Move (At_X (Item, 3), At_Y (Item, 3)), Taken => True);
      Send (Item, Release (At_X (Item, 3), At_Y (Item, 3)), Taken => True);
      Check_Selected ("picture-before-zoom", "alpha beta gamma", Item);

      --  Zoomed: the same words are under the pointer, wherever they have
      --  gone, and the highlight is drawn on them.
      Pictures.Set_Zoom (Item.Picture, 2.0);
      Widgets.Paint (Item.Tree, Item.Target, Colors);
      Check_Selected ("picture-zoomed", "alpha beta gamma", Item);
      declare
         Drawn : Images.Image;
      begin
         Images.Read (Drawn, Item.Target);
         Goldens.Check ("picture-zoomed-selection", Drawn);
      end;
      Send (Item, Press (At_X (Item, 5), At_Y (Item, 5), 2), Taken => True);
      Send (Item, Release (At_X (Item, 5), At_Y (Item, 5)), Taken => True);
      Check_Selected ("picture-zoomed-word", "epsilon", Item);

      --  Scrolled across: the same again.
      Send
        (Item,
         (Kind => Events.Mouse_Wheel, Wheel_X => -3.0, Wheel_Y => 0.0,
          Mouse_X => 100.0, Mouse_Y => 100.0, others => <>),
         Taken => True);
      Send (Item, Press (At_X (Item, 2), At_Y (Item, 2), 2), Taken => True);
      Send (Item, Release (At_X (Item, 2), At_Y (Item, 2)), Taken => True);
      Check_Selected ("picture-scrolled-word", "beta", Item);
   end Following_The_Picture;

end Picture_Tests;
