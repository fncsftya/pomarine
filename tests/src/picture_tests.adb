with SDL3.Events;
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

   package Events renames SDL3.Events;
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
      Send (Item, Release (At_X (Item, 5), At_Y (Item, 5)), Taken => False);
      Check_Selected ("picture-word", "epsilon", Item);
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
      Send (Item, Release (At_X (Item, 5), At_Y (Item, 5)), Taken => False);
      Check_Selected ("picture-zoomed-word", "epsilon", Item);

      --  Scrolled across: the same again.
      Send
        (Item,
         (Kind => Events.Mouse_Wheel, Wheel_X => -3.0, Wheel_Y => 0.0,
          Mouse_X => 100.0, Mouse_Y => 100.0, others => <>),
         Taken => True);
      Send (Item, Press (At_X (Item, 2), At_Y (Item, 2), 2), Taken => True);
      Send (Item, Release (At_X (Item, 2), At_Y (Item, 2)), Taken => False);
      Check_Selected ("picture-scrolled-word", "beta", Item);
   end Following_The_Picture;

end Picture_Tests;
