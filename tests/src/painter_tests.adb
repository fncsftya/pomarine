with SDL3.Painters;
with SDL3.Windows.Renderers;
with Goldens;
with Pomarine.Line_Texts;

package body Painter_Tests is

   package Renderers renames SDL3.Windows.Renderers;
   package Painters renames SDL3.Painters;
   package Images renames Goldens.Images;

   use all type Painters.Painter;

   Red   : constant Renderers.Color := (200, 30, 30, 255);
   Blue  : constant Renderers.Color := (30, 30, 200, 255);
   Paper : constant Renderers.Color := (240, 240, 230, 255);

   Recorded : Painters.Recording;
   --  Large, so not on the stack.

   procedure Scene (Onto : Painters.Painter'Class) is
      Outer : constant Renderers.Clip := Onto.Current_Clip;
   begin
      Onto.Clear (Paper);
      Onto.Fill_Rect (Red, 10.0, 10.0, 60.0, 40.0);
      Onto.Draw_Line (Blue, 5.0, 5.0, 90.0, 70.0, 3.0);
      Onto.Fill_Circle (Blue, 70.0, 60.0, 12.0);
      Onto.Narrow_Clip (20, 20, 30, 30);
      Onto.Fill_Rect (Blue, 0.0, 0.0, 100.0, 100.0);
      Onto.Restore_Clip (Outer);
      Onto.Draw_Text (Red, 8.0, 80.0, "ok");
   end Scene;

   procedure Recording_Kept is
      Seen : Painters.Recorder;
   begin
      Painters.Reset (Recorded);
      Seen := Painters.Recording_To (Recorded, 100, 100);
      Scene (Seen);
      Goldens.Check_Text ("painters-count", "8", Natural'Image (Painters.Count (Recorded)) (2 .. 2));
      Goldens.Check_Text
        ("painters-summary",
         "clear 240,240,230,255"
         & ASCII.LF
         & "fill 200,30,30,255 10 10 60 40"
         & ASCII.LF
         & "line 5 5 90 70"
         & ASCII.LF
         & "disc 70 60 12"
         & ASCII.LF
         & "clip 20 20 30 30"
         & ASCII.LF
         & "fill 30,30,200,255 0 0 100 100"
         & ASCII.LF
         & "unclip"
         & ASCII.LF
         & "text 'ok' 8 80"
         & ASCII.LF,
         Painters.Summary (Recorded));
   end Recording_Kept;

   procedure Replay_Is_Drawing is
      Direct, Again : Renderers.Renderer;
      Seen          : Painters.Recorder;
      Left, Right   : Images.Image;
   begin
      Renderers.Create_Offscreen (Direct, 100, 100);
      Renderers.Create_Offscreen (Again, 100, 100);
      Scene (Painters.To (Direct));
      Images.Read (Left, Direct);

      Painters.Reset (Recorded);
      Seen := Painters.Recording_To (Recorded, Again);
      Scene (Seen);
      Painters.Replay (Recorded, Painters.To (Again));
      Images.Read (Right, Again);
      Goldens.Check_Same ("painters-replay", Left, Right);
   end Replay_Is_Drawing;

   procedure Clips_Nest is
      Seen : Painters.Recorder;
   begin
      Painters.Reset (Recorded);
      Seen := Painters.Recording_To (Recorded, 100, 100);
      Seen.Narrow_Clip (10, 10, 50, 50);
      Seen.Narrow_Clip (30, 30, 50, 50);
      declare
         Now  : constant Renderers.Clip := Seen.Current_Clip;
         Same : constant Renderers.Clip :=
           Renderers.Narrowed (Renderers.Narrowed (Renderers.No_Clip, 10, 10, 50, 50), 30, 30, 50, 50);
      begin
         Goldens.Check_Text
           ("painters-clips-nest",
            Boolean'Image (True),
            Boolean'Image (Renderers.Is_Clipped (Now) and then Renderers.Is_Clipped (Same)));
      end;
   end Clips_Nest;

   procedure Character_Sizes is
      Drawer : Pomarine.Line_Texts.Drawer;
      Target : Renderers.Renderer;
      Seen   : Images.Image;
      Sizes  : constant array (Positive range <>) of Positive := [12, 24, 48, 12];
      use type Renderers.Color;
   begin
      Renderers.Create_Offscreen (Target, 100, 100);
      for Size of Sizes loop
         declare
            Onto : constant Painters.Renderer_Painter := Painters.To (Target);
            Top  : Natural := 100;
         begin
            Onto.Clear (Paper);
            Pomarine.Line_Texts.Draw_Character
              (Drawer, Onto, Blue, "Helvetica", Character'Pos ('H'), 10.0, 80.0, Float (Size));
            Pomarine.Line_Texts.Flush (Drawer, Onto);
            Images.Read (Seen, Target);
            for Y in 0 .. 99 loop
               for X in 0 .. 99 loop
                  if Images.Pixel (Seen, X, Y) /= Paper then
                     Top := Natural'Min (Top, Y);
                  end if;
               end loop;
            end loop;
            --  A capital reaches above half the requested em, and stays
            --  within it, including when the cached glyph is drawn again.
            Goldens.Check_Text
              ("character-size" & Positive'Image (Size),
               "TRUE",
               Boolean'Image (Top >= 80 - Size and then Top < 80 - Size / 2));
         end;
      end loop;
   end Character_Sizes;

   procedure Full_Recording is
      Seen : Painters.Recorder;
   begin
      Painters.Reset (Recorded);
      Seen := Painters.Recording_To (Recorded, 10, 10);
      for I in 1 .. Painters.Command_Capacity + 5 loop
         Seen.Fill_Rect (Red, 0.0, 0.0, 1.0, 1.0);
      end loop;
      Goldens.Check_Text
        ("painters-full",
         "TRUE" & Natural'Image (Painters.Command_Capacity),
         Boolean'Image (Painters.Overflowed (Recorded)) & Natural'Image (Painters.Count (Recorded)));
   end Full_Recording;

end Painter_Tests;
