with Ada.Strings.Unbounded;

package body SDL3.Painters is

      --  Into a renderer

   function To (Target : Renderers.Renderer) return Renderer_Painter is
     (Target => Target'Unrestricted_Access);

   overriding function Device (Item : Renderer_Painter) return Device_Access is
     (Device_Access (Item.Target));

   overriding procedure Output_Size
     (Item : Renderer_Painter; Width, Height : out Natural) is
   begin
      Renderers.Output_Size (Item.Target.all, Width, Height);
   end Output_Size;

   overriding procedure Clear (Item : Renderer_Painter; Value : Color) is
   begin
      Renderers.Clear (Item.Target.all, Value);
   end Clear;

   overriding procedure Fill_Rect
     (Item : Renderer_Painter; Value : Color; X, Y, Width, Height : Float) is
   begin
      Renderers.Fill_Rect (Item.Target.all, Value, X, Y, Width, Height);
   end Fill_Rect;

   overriding procedure Fill_Rect
     (Item  : Renderer_Painter;
      Value : Color;
      Blend : Blends;
      X, Y, Width, Height : Float) is
   begin
      Renderers.Fill_Rect (Item.Target.all, Value, Blend, X, Y, Width, Height);
   end Fill_Rect;

   overriding procedure Draw_Line
     (Item  : Renderer_Painter;
      Value : Color;
      From_X, From_Y, To_X, To_Y : Float;
      Width : Float := 1.0) is
   begin
      Renderers.Draw_Line
        (Item.Target.all, Value, From_X, From_Y, To_X, To_Y, Width);
   end Draw_Line;

   overriding procedure Fill_Circle
     (Item : Renderer_Painter; Value : Color; Centre_X, Centre_Y, Radius : Float) is
   begin
      Renderers.Fill_Circle (Item.Target.all, Value, Centre_X, Centre_Y, Radius);
   end Fill_Circle;

   overriding procedure Fill_Triangles
     (Item           : Renderer_Painter;
      Value          : Color;
      Points         : Point_Array;
      Triangle_Count : Natural) is
   begin
      Renderers.Fill_Triangles (Item.Target.all, Value, Points, Triangle_Count);
   end Fill_Triangles;

   overriding procedure Set_Clip
     (Item : Renderer_Painter; X, Y, Width, Height : Integer) is
   begin
      Renderers.Set_Clip (Item.Target.all, X, Y, Width, Height);
   end Set_Clip;

   overriding procedure Clear_Clip (Item : Renderer_Painter) is
   begin
      Renderers.Clear_Clip (Item.Target.all);
   end Clear_Clip;

   overriding function Current_Clip (Item : Renderer_Painter) return Clip is
     (Renderers.Current_Clip (Item.Target.all));

   overriding procedure Restore_Clip (Item : Renderer_Painter; Value : Clip) is
   begin
      Renderers.Restore_Clip (Item.Target.all, Value);
   end Restore_Clip;

   overriding procedure Narrow_Clip
     (Item : Renderer_Painter; X, Y, Width, Height : Integer) is
   begin
      Renderers.Narrow_Clip (Item.Target.all, X, Y, Width, Height);
   end Narrow_Clip;

   overriding procedure Draw_Text
     (Item  : Renderer_Painter;
      Value : Color;
      X, Y  : Float;
      Text  : String;
      Scale : Positive := 1) is
   begin
      Renderers.Draw_Text (Item.Target.all, Value, X, Y, Text, Scale);
   end Draw_Text;

   overriding procedure Draw_Tinted
     (Item  : Renderer_Painter;
      Image : Textures.Texture;
      X, Y  : Float;
      Value : Color) is
   begin
      Textures.Draw_Tinted (Item.Target.all, Image, X, Y, Value);
   end Draw_Tinted;

   overriding procedure Draw_Image
     (Item : Renderer_Painter; Image : Textures.Texture; X, Y : Float) is
   begin
      Textures.Draw (Item.Target.all, Image, X, Y);
   end Draw_Image;

   overriding procedure Draw_Scaled
     (Item : Renderer_Painter;
      Image : Textures.Texture;
      X, Y, Wide, High : Float) is
   begin
      Textures.Draw_Scaled (Item.Target.all, Image, X, Y, Wide, High);
   end Draw_Scaled;

   overriding procedure Draw_Quads
     (Item       : Renderer_Painter;
      Image      : Textures.Texture;
      Vertices   : Textures.Vertex_Array;
      Quad_Count : Natural) is
   begin
      Textures.Draw_Quads (Item.Target.all, Image, Vertices, Quad_Count);
   end Draw_Quads;

   --  Into a list

   procedure Reset (Item : in out Recording) is
   begin
      Item.Made := 0;
      Item.Verts := 0;
      Item.Chars := 0;
      Item.Full := False;
      Item.Now := Renderers.No_Clip;
   end Reset;

   function Count (Item : Recording) return Natural is (Item.Made);

   function Overflowed (Item : Recording) return Boolean is (Item.Full);

   function Recording_To
     (Into : in out Recording; Size : Renderers.Renderer) return Recorder
   is
      Wide, High : Natural;
   begin
      Renderers.Output_Size (Size, Wide, High);
      Into.Wide := Wide;
      Into.High := High;
      return (Into => Into'Unrestricted_Access,
              Size => Size'Unrestricted_Access);
   end Recording_To;

   function Recording_To
     (Into : in out Recording; Width, Height : Natural) return Recorder is
   begin
      Into.Wide := Width;
      Into.High := Height;
      return (Into => Into'Unrestricted_Access, Size => null);
   end Recording_To;

   overriding function Device (Item : Recorder) return Device_Access is
     (Device_Access (Item.Size));

   overriding procedure Output_Size
     (Item : Recorder; Width, Height : out Natural) is
   begin
      Width := Item.Into.Wide;
      Height := Item.Into.High;
   end Output_Size;

   procedure Add (Item : Recorder; Kind : Command_Kind; Cmd : out Command;
                  Ok : out Boolean) is
   begin
      Ok := Item.Into.Made < Command_Capacity;
      Cmd := (Kind => Kind, Source => null, others => <>);
      if not Ok then
         Item.Into.Full := True;
      end if;
   end Add;

   procedure Keep (Item : Recorder; Cmd : Command) is
   begin
      Item.Into.Made := Item.Into.Made + 1;
      Item.Into.Commands (Item.Into.Made) := Cmd;
   end Keep;

   overriding procedure Clear (Item : Recorder; Value : Color) is
      Cmd : Command;
      Ok  : Boolean;
   begin
      Add (Item, Do_Clear, Cmd, Ok);
      if Ok then
         Cmd.Value := Value;
         Keep (Item, Cmd);
      end if;
   end Clear;

   overriding procedure Fill_Rect
     (Item : Recorder; Value : Color; X, Y, Width, Height : Float)
   is
      Cmd : Command;
      Ok  : Boolean;
   begin
      Add (Item, Do_Fill, Cmd, Ok);
      if Ok then
         Cmd.Value := Value;
         Cmd.A := X;
         Cmd.B := Y;
         Cmd.C := Width;
         Cmd.D := Height;
         Keep (Item, Cmd);
      end if;
   end Fill_Rect;

   overriding procedure Fill_Rect
     (Item  : Recorder;
      Value : Color;
      Blend : Blends;
      X, Y, Width, Height : Float)
   is
      Cmd : Command;
      Ok  : Boolean;
   begin
      Add (Item, Do_Fill_Blended, Cmd, Ok);
      if Ok then
         Cmd.Value := Value;
         Cmd.Blend := Blend;
         Cmd.A := X;
         Cmd.B := Y;
         Cmd.C := Width;
         Cmd.D := Height;
         Keep (Item, Cmd);
      end if;
   end Fill_Rect;

   overriding procedure Draw_Line
     (Item  : Recorder;
      Value : Color;
      From_X, From_Y, To_X, To_Y : Float;
      Width : Float := 1.0)
   is
      Cmd : Command;
      Ok  : Boolean;
   begin
      Add (Item, Do_Line, Cmd, Ok);
      if Ok then
         Cmd.Value := Value;
         Cmd.A := From_X;
         Cmd.B := From_Y;
         Cmd.C := To_X;
         Cmd.D := To_Y;
         Cmd.Thick := Width;
         Keep (Item, Cmd);
      end if;
   end Draw_Line;

   overriding procedure Fill_Circle
     (Item : Recorder; Value : Color; Centre_X, Centre_Y, Radius : Float)
   is
      Cmd : Command;
      Ok  : Boolean;
   begin
      Add (Item, Do_Disc, Cmd, Ok);
      if Ok then
         Cmd.Value := Value;
         Cmd.A := Centre_X;
         Cmd.B := Centre_Y;
         Cmd.C := Radius;
         Keep (Item, Cmd);
      end if;
   end Fill_Circle;

   overriding procedure Fill_Triangles
     (Item           : Recorder;
      Value          : Color;
      Points         : Point_Array;
      Triangle_Count : Natural)
   is
      Cmd  : Command;
      Ok   : Boolean;
      Used : constant Natural := 3 * Triangle_Count;
   begin
      Add (Item, Do_Triangles, Cmd, Ok);
      if Ok and then Item.Into.Verts + Used > Vertex_Capacity then
         Item.Into.Full := True;
         Ok := False;
      end if;
      if Ok then
         Cmd.Value := Value;
         Cmd.First := Item.Into.Verts + 1;
         Cmd.Cells := Triangle_Count;
         for I in 1 .. Used loop
            Item.Into.Vertices (Item.Into.Verts + I) :=
              (X => Points (Points'First + I - 1).X,
               Y => Points (Points'First + I - 1).Y,
               others => 0.0);
         end loop;
         Item.Into.Verts := Item.Into.Verts + Used;
         Keep (Item, Cmd);
      end if;
   end Fill_Triangles;

   overriding procedure Set_Clip
     (Item : Recorder; X, Y, Width, Height : Integer)
   is
      Cmd : Command;
      Ok  : Boolean;
   begin
      Item.Into.Now := Renderers.Narrowed
        (Renderers.No_Clip, X, Y, Width, Height);
      Add (Item, Do_Clip_To, Cmd, Ok);
      if Ok then
         Cmd.Left := X;
         Cmd.Top := Y;
         Cmd.Wide := Width;
         Cmd.High := Height;
         Keep (Item, Cmd);
      end if;
   end Set_Clip;

   overriding procedure Clear_Clip (Item : Recorder) is
      Cmd : Command;
      Ok  : Boolean;
   begin
      Item.Into.Now := Renderers.No_Clip;
      Add (Item, Do_Clip_Off, Cmd, Ok);
      if Ok then
         Keep (Item, Cmd);
      end if;
   end Clear_Clip;

   overriding function Current_Clip (Item : Recorder) return Clip is
     (Item.Into.Now);

   overriding procedure Restore_Clip (Item : Recorder; Value : Clip) is
      Cmd : Command;
      Ok  : Boolean;
   begin
      Item.Into.Now := Value;
      Add (Item, Do_Clip_Back, Cmd, Ok);
      if Ok then
         Cmd.Saved := Value;
         Keep (Item, Cmd);
      end if;
   end Restore_Clip;

   overriding procedure Narrow_Clip
     (Item : Recorder; X, Y, Width, Height : Integer)
   is
      Cmd : Command;
      Ok  : Boolean;
   begin
      Item.Into.Now := Renderers.Narrowed (Item.Into.Now, X, Y, Width, Height);
      Add (Item, Do_Clip_Narrower, Cmd, Ok);
      if Ok then
         Cmd.Left := X;
         Cmd.Top := Y;
         Cmd.Wide := Width;
         Cmd.High := Height;
         Keep (Item, Cmd);
      end if;
   end Narrow_Clip;

   overriding procedure Draw_Text
     (Item  : Recorder;
      Value : Color;
      X, Y  : Float;
      Text  : String;
      Scale : Positive := 1)
   is
      Cmd : Command;
      Ok  : Boolean;
   begin
      Add (Item, Do_Text, Cmd, Ok);
      if Ok and then Item.Into.Chars + Text'Length > Text_Capacity then
         Item.Into.Full := True;
         Ok := False;
      end if;
      if Ok then
         Cmd.Value := Value;
         Cmd.A := X;
         Cmd.B := Y;
         Cmd.Scale := Scale;
         Cmd.First := Item.Into.Chars + 1;
         Cmd.Cells := Text'Length;
         for I in Text'Range loop
            Item.Into.Letters (Cmd.First + I - Text'First) := Text (I);
         end loop;
         Item.Into.Chars := Item.Into.Chars + Text'Length;
         Keep (Item, Cmd);
      end if;
   end Draw_Text;

   overriding procedure Draw_Tinted
     (Item  : Recorder;
      Image : Textures.Texture;
      X, Y  : Float;
      Value : Color)
   is
      Cmd : Command;
      Ok  : Boolean;
   begin
      Add (Item, Do_Tinted, Cmd, Ok);
      if Ok then
         Cmd.Source := Image'Unrestricted_Access;
         Cmd.A := X;
         Cmd.B := Y;
         Cmd.Value := Value;
         Keep (Item, Cmd);
      end if;
   end Draw_Tinted;

   overriding procedure Draw_Image
     (Item : Recorder; Image : Textures.Texture; X, Y : Float)
   is
      Cmd : Command;
      Ok  : Boolean;
   begin
      Add (Item, Do_Image, Cmd, Ok);
      if Ok then
         Cmd.Source := Image'Unrestricted_Access;
         Cmd.A := X;
         Cmd.B := Y;
         Keep (Item, Cmd);
      end if;
   end Draw_Image;

   overriding procedure Draw_Scaled
     (Item : Recorder;
      Image : Textures.Texture;
      X, Y, Wide, High : Float)
   is
      Cmd : Command;
      Ok  : Boolean;
   begin
      Add (Item, Do_Scaled, Cmd, Ok);
      if Ok then
         Cmd.Source := Image'Unrestricted_Access;
         Cmd.A := X;
         Cmd.B := Y;
         Cmd.C := Wide;
         Cmd.D := High;
         Keep (Item, Cmd);
      end if;
   end Draw_Scaled;

   overriding procedure Draw_Quads
     (Item       : Recorder;
      Image      : Textures.Texture;
      Vertices   : Textures.Vertex_Array;
      Quad_Count : Natural)
   is
      Cmd : Command;
      Ok  : Boolean;
      Used : constant Natural := 4 * Quad_Count;
   begin
      Add (Item, Do_Quads, Cmd, Ok);
      if Ok and then Item.Into.Verts + Used > Vertex_Capacity then
         Item.Into.Full := True;
         Ok := False;
      end if;
      if Ok then
         Cmd.Source := Image'Unrestricted_Access;
         Cmd.First := Item.Into.Verts + 1;
         Cmd.Cells := Quad_Count;
         for I in 1 .. Used loop
            Item.Into.Vertices (Item.Into.Verts + I) :=
              Vertices (Vertices'First + I - 1);
         end loop;
         Item.Into.Verts := Item.Into.Verts + Used;
         Keep (Item, Cmd);
      end if;
   end Draw_Quads;

   procedure Replay (Item : Recording; Onto : Painter'Class) is
   begin
      for I in 1 .. Item.Made loop
         declare
            C : Command renames Item.Commands (I);
         begin
            case C.Kind is
               when Do_Clear =>
                  Onto.Clear (C.Value);
               when Do_Fill =>
                  Onto.Fill_Rect (C.Value, C.A, C.B, C.C, C.D);
               when Do_Fill_Blended =>
                  Onto.Fill_Rect (C.Value, C.Blend, C.A, C.B, C.C, C.D);
               when Do_Line =>
                  Onto.Draw_Line (C.Value, C.A, C.B, C.C, C.D, C.Thick);
               when Do_Disc =>
                  Onto.Fill_Circle (C.Value, C.A, C.B, C.C);
               when Do_Triangles =>
                  declare
                     Corners : Point_Array (1 .. 3 * C.Cells);
                  begin
                     for I in Corners'Range loop
                        Corners (I) :=
                          (X => Item.Vertices (C.First + I - 1).X,
                           Y => Item.Vertices (C.First + I - 1).Y);
                     end loop;
                     Onto.Fill_Triangles (C.Value, Corners, C.Cells);
                  end;
               when Do_Clip_To =>
                  Onto.Set_Clip (C.Left, C.Top, C.Wide, C.High);
               when Do_Clip_Off =>
                  Onto.Clear_Clip;
               when Do_Clip_Back =>
                  Onto.Restore_Clip (C.Saved);
               when Do_Clip_Narrower =>
                  Onto.Narrow_Clip (C.Left, C.Top, C.Wide, C.High);
               when Do_Text =>
                  Onto.Draw_Text
                    (C.Value, C.A, C.B,
                     String (Item.Letters (C.First .. C.First + C.Cells - 1)),
                     C.Scale);
               when Do_Tinted =>
                  Onto.Draw_Tinted (C.Source.all, C.A, C.B, C.Value);
               when Do_Image =>
                  Onto.Draw_Image (C.Source.all, C.A, C.B);
               when Do_Scaled =>
                  Onto.Draw_Scaled (C.Source.all, C.A, C.B, C.C, C.D);
               when Do_Quads =>
                  Onto.Draw_Quads
                    (C.Source.all,
                     Textures.Vertex_Array
                       (Item.Vertices (C.First .. C.First + 4 * C.Cells - 1)),
                     C.Cells);
            end case;
         end;
      end loop;
   end Replay;

   function Summary (Item : Recording) return String is
      use Ada.Strings.Unbounded;

      Result : Unbounded_String;

      function Img (Value : Float) return String is
         Text : constant String := Integer'Image (Integer (Value));
      begin
         return Text (Text'First + 1 .. Text'Last);
      end Img;

      function Img (Value : Color) return String is
        (Img (Float (Value.Red)) & "," & Img (Float (Value.Green)) & ","
         & Img (Float (Value.Blue)) & "," & Img (Float (Value.Alpha)));
   begin
      for I in 1 .. Item.Made loop
         declare
            C : Command renames Item.Commands (I);
         begin
            case C.Kind is
               when Do_Clear =>
                  Append (Result, "clear " & Img (C.Value));
               when Do_Fill | Do_Fill_Blended =>
                  Append (Result, "fill " & Img (C.Value) & " "
                          & Img (C.A) & " " & Img (C.B) & " "
                          & Img (C.C) & " " & Img (C.D));
               when Do_Line =>
                  Append (Result, "line " & Img (C.A) & " " & Img (C.B) & " "
                          & Img (C.C) & " " & Img (C.D));
               when Do_Disc =>
                  Append (Result, "disc " & Img (C.A) & " " & Img (C.B)
                          & " " & Img (C.C));
               when Do_Clip_To | Do_Clip_Narrower =>
                  Append (Result, "clip" & Integer'Image (C.Left)
                          & Integer'Image (C.Top) & Integer'Image (C.Wide)
                          & Integer'Image (C.High));
               when Do_Clip_Off | Do_Clip_Back =>
                  Append (Result, "unclip");
               when Do_Text =>
                  Append (Result, "text '"
                          & String (Item.Letters
                                      (C.First .. C.First + C.Cells - 1))
                          & "' " & Img (C.A) & " " & Img (C.B));
               when Do_Tinted | Do_Image | Do_Scaled =>
                  Append (Result, "image " & Img (C.A) & " " & Img (C.B));
               when Do_Quads =>
                  Append (Result, "quads" & Natural'Image (C.Cells));
               when Do_Triangles =>
                  Append (Result, "triangles" & Natural'Image (C.Cells));
            end case;
            Append (Result, ASCII.LF);
         end;
      end loop;
      return To_String (Result);
   end Summary;

end SDL3.Painters;
