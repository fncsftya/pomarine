with SDL3.Windows.Renderers;
with SDL3.Windows.Renderers.Textures;

--  What a widget draws with: a few primitives (boxes, lines, discs, clips,
--  text of the debug font, and images from textures), so that what is
--  drawn does not depend on where it goes. A Renderer_Painter draws at
--  once into a renderer; a Recorder keeps the commands, to replay into
--  any painter later: to see what was drawn without pixels, as a test,
--  or to draw the same thing again.
--
--  A painter is a small value that refers to what it paints into, so
--  it is passed by value, as Painter'Class, and its operations are not
--  "in out". Whatever it refers to must be there as long as it is used.
--
--  Textures are made for a renderer, not a painter: Device gives the
--  renderer to make them with, for painters that have one.
package SDL3.Painters is

   package Renderers renames SDL3.Windows.Renderers;
   package Textures renames SDL3.Windows.Renderers.Textures;

   subtype Color is Renderers.Color;
   subtype Blends is Renderers.Blends;
   subtype Clip is Renderers.Clip;

   type Painter is interface;

   type Device_Access is access constant Renderers.Renderer;

   function Device (Item : Painter) return Device_Access is abstract;
   --  The renderer textures are made for; null if none.

   procedure Output_Size
     (Item : Painter; Width, Height : out Natural) is abstract;
   --  Size of the drawable area in pixels.

   procedure Clear (Item : Painter; Value : Color) is abstract;

   procedure Fill_Rect
     (Item : Painter; Value : Color; X, Y, Width, Height : Float) is abstract;

   procedure Fill_Rect
     (Item  : Painter;
      Value : Color;
      Blend : Blends;
      X, Y, Width, Height : Float) is abstract;

   procedure Draw_Line
     (Item  : Painter;
      Value : Color;
      From_X, From_Y, To_X, To_Y : Float;
      Width : Float := 1.0) is abstract;

   procedure Fill_Circle
     (Item : Painter; Value : Color; Centre_X, Centre_Y, Radius : Float)
   is abstract;

   subtype Point is Renderers.Point;
   subtype Point_Array is Renderers.Point_Array;

   procedure Fill_Triangles
     (Item           : Painter;
      Value          : Color;
      Points         : Point_Array;
      Triangle_Count : Natural) is abstract;
   --  As Renderers.Fill_Triangles.

   procedure Set_Clip
     (Item : Painter; X, Y, Width, Height : Integer) is abstract;

   procedure Clear_Clip (Item : Painter) is abstract;

   function Current_Clip (Item : Painter) return Clip is abstract;

   procedure Restore_Clip (Item : Painter; Value : Clip) is abstract;

   procedure Narrow_Clip
     (Item : Painter; X, Y, Width, Height : Integer) is abstract;

   procedure Draw_Text
     (Item  : Painter;
      Value : Color;
      X, Y  : Float;
      Text  : String;
      Scale : Positive := 1) is abstract;

   procedure Draw_Tinted
     (Item  : Painter;
      Image : Textures.Texture;
      X, Y  : Float;
      Value : Color) is abstract;

   procedure Draw_Image
     (Item : Painter; Image : Textures.Texture; X, Y : Float) is abstract;

   procedure Draw_Scaled
     (Item : Painter;
      Image : Textures.Texture;
      X, Y, Wide, High : Float) is abstract;

   procedure Draw_Quads
     (Item       : Painter;
      Image      : Textures.Texture;
      Vertices   : Textures.Vertex_Array;
      Quad_Count : Natural) is abstract;

   --  Into a renderer

   type Renderer_Painter is new Painter with private;

   function To (Target : Renderers.Renderer) return Renderer_Painter;
   --  Draws into Target, which must be there as long as it is used.

   overriding function Device (Item : Renderer_Painter) return Device_Access;
   overriding procedure Output_Size
     (Item : Renderer_Painter; Width, Height : out Natural);
   overriding procedure Clear (Item : Renderer_Painter; Value : Color);
   overriding procedure Fill_Rect
     (Item : Renderer_Painter; Value : Color; X, Y, Width, Height : Float);
   overriding procedure Fill_Rect
     (Item  : Renderer_Painter;
      Value : Color;
      Blend : Blends;
      X, Y, Width, Height : Float);
   overriding procedure Draw_Line
     (Item  : Renderer_Painter;
      Value : Color;
      From_X, From_Y, To_X, To_Y : Float;
      Width : Float := 1.0);
   overriding procedure Fill_Circle
     (Item : Renderer_Painter; Value : Color; Centre_X, Centre_Y, Radius : Float);
   overriding procedure Fill_Triangles
     (Item           : Renderer_Painter;
      Value          : Color;
      Points         : Point_Array;
      Triangle_Count : Natural);
   overriding procedure Set_Clip
     (Item : Renderer_Painter; X, Y, Width, Height : Integer);
   overriding procedure Clear_Clip (Item : Renderer_Painter);
   overriding function Current_Clip (Item : Renderer_Painter) return Clip;
   overriding procedure Restore_Clip (Item : Renderer_Painter; Value : Clip);
   overriding procedure Narrow_Clip
     (Item : Renderer_Painter; X, Y, Width, Height : Integer);
   overriding procedure Draw_Text
     (Item  : Renderer_Painter;
      Value : Color;
      X, Y  : Float;
      Text  : String;
      Scale : Positive := 1);
   overriding procedure Draw_Tinted
     (Item  : Renderer_Painter;
      Image : Textures.Texture;
      X, Y  : Float;
      Value : Color);
   overriding procedure Draw_Image
     (Item : Renderer_Painter; Image : Textures.Texture; X, Y : Float);
   overriding procedure Draw_Scaled
     (Item : Renderer_Painter;
      Image : Textures.Texture;
      X, Y, Wide, High : Float);
   overriding procedure Draw_Quads
     (Item       : Renderer_Painter;
      Image      : Textures.Texture;
      Vertices   : Textures.Vertex_Array;
      Quad_Count : Natural);

   --  Into a list

   Command_Capacity : constant := 8192;
   Vertex_Capacity  : constant := 32768;
   Text_Capacity    : constant := 8192;
   --  What a recording holds: commands, glyph and image vertices, and
   --  characters of text.

   type Recording is limited private;
   --  The commands a Recorder has kept.

   procedure Reset (Item : in out Recording)
     with Post => Count (Item) = 0 and then not Overflowed (Item);

   function Count (Item : Recording) return Natural;
   --  How many commands.

   function Overflowed (Item : Recording) return Boolean;
   --  Whether something was drawn when it was full, and so not kept.

   type Recorder is new Painter with private;

   function Recording_To
     (Into : in out Recording; Size : Renderers.Renderer) return Recorder;
   --  Keeps what is drawn in Into, for a target the size of Size's, and
   --  makes textures for it.

   function Recording_To
     (Into : in out Recording; Width, Height : Natural) return Recorder;
   --  The same, with no renderer: for a test of what is drawn.

   procedure Replay (Item : Recording; Onto : Painter'Class);
   --  Draw what was kept, in order. The textures it drew must be there
   --  and be as they were.

   function Summary (Item : Recording) return String;
   --  A line to a command: what was drawn and where, to compare.

   overriding function Device (Item : Recorder) return Device_Access;
   overriding procedure Output_Size
     (Item : Recorder; Width, Height : out Natural);
   overriding procedure Clear (Item : Recorder; Value : Color);
   overriding procedure Fill_Rect
     (Item : Recorder; Value : Color; X, Y, Width, Height : Float);
   overriding procedure Fill_Rect
     (Item  : Recorder;
      Value : Color;
      Blend : Blends;
      X, Y, Width, Height : Float);
   overriding procedure Draw_Line
     (Item  : Recorder;
      Value : Color;
      From_X, From_Y, To_X, To_Y : Float;
      Width : Float := 1.0);
   overriding procedure Fill_Circle
     (Item : Recorder; Value : Color; Centre_X, Centre_Y, Radius : Float);
   overriding procedure Fill_Triangles
     (Item           : Recorder;
      Value          : Color;
      Points         : Point_Array;
      Triangle_Count : Natural);
   overriding procedure Set_Clip
     (Item : Recorder; X, Y, Width, Height : Integer);
   overriding procedure Clear_Clip (Item : Recorder);
   overriding function Current_Clip (Item : Recorder) return Clip;
   overriding procedure Restore_Clip (Item : Recorder; Value : Clip);
   overriding procedure Narrow_Clip
     (Item : Recorder; X, Y, Width, Height : Integer);
   overriding procedure Draw_Text
     (Item  : Recorder;
      Value : Color;
      X, Y  : Float;
      Text  : String;
      Scale : Positive := 1);
   overriding procedure Draw_Tinted
     (Item  : Recorder;
      Image : Textures.Texture;
      X, Y  : Float;
      Value : Color);
   overriding procedure Draw_Image
     (Item : Recorder; Image : Textures.Texture; X, Y : Float);
   overriding procedure Draw_Scaled
     (Item : Recorder;
      Image : Textures.Texture;
      X, Y, Wide, High : Float);
   overriding procedure Draw_Quads
     (Item       : Recorder;
      Image      : Textures.Texture;
      Vertices   : Textures.Vertex_Array;
      Quad_Count : Natural);

private

   type Renderer_Access is access constant Renderers.Renderer;

   type Renderer_Painter is new Painter with record
      Target : Renderer_Access;
   end record;

   type Texture_Access is access constant Textures.Texture;

   type Command_Kind is
     (Do_Clear, Do_Fill, Do_Fill_Blended, Do_Line, Do_Disc, Do_Clip_To,
      Do_Clip_Off, Do_Clip_Back, Do_Clip_Narrower, Do_Text, Do_Tinted,
      Do_Image, Do_Scaled, Do_Quads, Do_Triangles);

   type Command is record
      Kind   : Command_Kind := Do_Clear;
      Value  : Color := (0, 0, 0, 255);
      Blend  : Blends := Renderers.Solid;
      A, B, C, D : Float := 0.0;
      --  Where: the box (A, B, C, D), a line's ends, a disc's centre
      --  and radius (A, B, C), an image's place.
      Thick  : Float := 1.0;
      Left, Top, Wide, High : Integer := 0;
      --  A clip's rectangle.
      Saved  : Clip := Renderers.No_Clip;
      First  : Natural := 0;
      Cells  : Natural := 0;
      --  Text: where its characters start in the letters, and how many;
      --  Quads: where the first vertex is, and how many quads; Triangles:
      --  where the first corner is (its X, Y), and how many triangles.
      Scale  : Positive := 1;
      Source : Texture_Access;
   end record;

   type Command_Array is array (1 .. Command_Capacity) of Command;
   type Vertex_Store is array (1 .. Vertex_Capacity) of Textures.Vertex
     with Convention => C;
   type Text_Store is array (1 .. Text_Capacity) of Character;

   type Recording is limited record
      Made     : Natural := 0;
      Verts    : Natural := 0;
      Chars    : Natural := 0;
      Full     : Boolean := False;
      Wide, High : Natural := 0;
      Now      : Clip := Renderers.No_Clip;
      Commands : Command_Array;
      Vertices : Vertex_Store;
      Letters  : Text_Store;
   end record;

   type Recording_Access is access all Recording;

   type Recorder is new Painter with record
      Into   : Recording_Access;
      Size   : Renderer_Access;
   end record;

end SDL3.Painters;
