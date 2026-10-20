with SDL3.Windows.Renderers;
with Pomarine_Ui_Config;

--  The colours components are drawn in.
--
--  A theme is a colour for each slot. The slots a widget keeps (Background,
--  Border, Primary and so on) are resolved to the theme's colour when it is
--  drawn, so a widget need not be built again to change theme. An application
--  has slots of its own, for what only it draws: Custom (0), Custom (1) and
--  so on, which it names and sets in the theme (Set_Custom).
--
--  A theme is not written colour by colour. Make builds one from a palette of
--  the dozen or so colours that make a look, and works out the rest: the
--  states of a control (resting, under the pointer, pressed, turned off) in
--  each of its Tones, and the inks, muted or faint, that go with a surface.
--  Everything is made once, here, and drawing looks it up.
package Pomarine.Themes is

   subtype Color is SDL3.Windows.Renderers.Color;

   Custom_Capacity : constant := Pomarine_Ui_Config.Custom_Colors;
   --  Slots an application may have of its own.

   Core_Count : constant := 24;

   type Slot is range 1 .. Core_Count + Custom_Capacity;

   Background : constant Slot := 1;   --  of the desk, the canvas
   Foreground : constant Slot := 2;   --  text
   Muted      : constant Slot := 3;   --  what is said of something, as a count
   Hint       : constant Slot := 4;   --  a hint in a field
   Page       : constant Slot := 5;   --  pages, windows and fields
   Face       : constant Slot := 6;   --  of a button
   Border     : constant Slot := 7;   --  the outline of a box, a point wide
   Shadow     : constant Slot := 8;   --  cast by a box: solid, offset, never blurred
   Focus      : constant Slot := 9;   --  the ring round what has the keyboard's focus
   Accent     : constant Slot := 10;  --  what is chosen or switched on, and the caret
   On_Accent  : constant Slot := 11;  --  text on the accent
   Primary    : constant Slot := 12;  --  the main, positive action, as making
   Danger     : constant Slot := 13;  --  what cannot be undone, as deleting
   Primary_Ink : constant Slot := 14; --  the primary colour as text
   Danger_Ink  : constant Slot := 15; --  the danger colour as text
   Bar        : constant Slot := 16;  --  the dark bars: a window's title, the top
   Bar_Ink    : constant Slot := 17;  --  text on a dark bar
   Rule       : constant Slot := 18;  --  a line on a dark bar
   Tint       : constant Slot := 19;  --  a strip of a box, as a status line
   Hover_Row  : constant Slot := 20;  --  a row of a list, under the pointer
   Marker     : constant Slot := 21;  --  the highlighter's
   Selection  : constant Slot := 22;  --  behind selected text, when it has focus
   Scrim      : constant Slot := 23;  --  over what is behind a dialog, to grey it out
   Drop_Shadow : constant Slot := 24; --  cast by what stands up, as a menu

   function Custom (Offset : Natural) return Slot is
     (Slot (Core_Count + 1 + Offset))
     with Pre => Offset < Custom_Capacity;
   --  The application's own slots start at 0.

   --  How a control looks in each state.

   type Tone is
     (Normal_Tone, Primary_Tone, Danger_Tone, Selected_Tone, Quiet_Tone, AI_Tone, Warning_Tone);
   --  A tone is what a control is for. Normal has the theme's face, for most
   --  things; Primary is in the primary colour, for the main action; Danger
   --  in the danger colour, for what cannot be undone; Selected in the
   --  accent, for what is on or chosen; Quiet has no face, only its ink,
   --  for a dark bar; AI is purple, for what is done by a language model.

   type Shade is
     (Fill,       --  of the face at rest
      Hover,      --  under the pointer
      Pressed,    --  held down
      Edge,       --  its outline
      Ink,        --  text and icons on it
      Ink_Hover,  --  under the pointer
      Off,        --  the face when turned off: flat and faint
      Off_Edge,
      Off_Ink,
      Lit,        --  the bevel's light edge, at the top and left, at rest
      Shaded,     --  its dark edge, at the foot and right
      Hover_Lit,  --  the same, under the pointer
      Hover_Shaded,
      Pressed_Lit,  --  and held down
      Pressed_Shaded);

   type Tone_Array is array (Tone, Shade) of Color;

   type Color_Array is array (Slot) of Color;

   type Theme is tagged record
      Slots    : Color_Array;
      Tones    : Tone_Array;
      Bevelled : Boolean := True;
      --  Whether a control has a bevel: a line of light along its top and
      --  left, and of shade along its foot and right, turned over when it
      --  is held down. Without, it is flat.
   end record
     with Constant_Indexing => Resolve;
   --  So that a theme is read as Colors (Border).

   type Palette is record
      Dark       : Boolean := False;
      Bevelled   : Boolean := True;
      Background : Color;
      Foreground : Color;
      Page       : Color;
      Face       : Color;
      Edge       : Color;   --  the outline of a control
      Border     : Color;
      Shadow     : Color;
      Focus      : Color;
      Accent     : Color;
      Primary    : Color;
      Danger     : Color;
      Primary_Ink : Color;
      Danger_Ink  : Color;
      Bar        : Color;
      Tint       : Color;
      Marker     : Color;
      Scrim      : Color;
      Drop_Shadow : Color;
      Face_Hover   : Color;  --  of a neutral control, under the pointer
      Face_Pressed : Color;  --  and held down
      Face_Light   : Color;  --  its bevel, at rest
      Face_Shade   : Color;
      Primary_Light : Color;  --  the bevel of the main action
      Primary_Shade : Color;
      Danger_Light  : Color;  --  the bevel of what cannot be undone
      Danger_Shade  : Color;
      AI            : Color;  --  what a language model does, purple
      AI_Light      : Color;  --  its bevel
      AI_Shade      : Color;
   end record;
   --  What makes a look. A light palette lightens a face under the pointer
   --  and darkens it pressed; a dark one the other way.

   function Make (From : Palette) return Theme;

   function Light return Theme;
   function Dark  return Theme;
   --  The library's own, made by Make from Light_Palette and Dark_Palette.

   Light_Palette : constant Palette;
   Dark_Palette  : constant Palette;

   function With_Slot (Item : Theme; Which : Slot; To : Color) return Theme;
   --  Item, but with Which the colour To: for a widget that draws what is
   --  inside it in other colours (as a field, on its paper).

   procedure Set_Custom (Item : in out Theme; Offset : Natural; To : Color)
     with Pre => Offset < Custom_Capacity;
   --  Give the application's slot Custom (Offset) the colour To in Item. A
   --  theme made has them all black.

   function Resolve (Item : Theme; Which : Slot) return Color is
     (Item.Slots (Which));
   --  The colour Which is in the theme Item: Item (Which).

   function Tone_Color (Item : Theme; Of_Tone : Tone; Of_Shade : Shade) return Color is
     (Item.Tones (Of_Tone, Of_Shade));

   function Face_For
     (Item    : Theme;
      Of_Tone : Tone := Normal_Tone;
      Enabled : Boolean := True;
      Hovered : Boolean := False;
      Held    : Boolean := False) return Color is
     (if not Enabled then Item.Tones (Of_Tone, Off)
      elsif Held then Item.Tones (Of_Tone, Pressed)
      elsif Hovered then Item.Tones (Of_Tone, Hover)
      else Item.Tones (Of_Tone, Fill));
   --  The face of a control of a tone, in its state: turned off, held down
   --  (and over it), under the pointer, or at rest.

   function Edge_For
     (Item    : Theme;
      Of_Tone : Tone := Normal_Tone;
      Enabled : Boolean := True) return Color is
     (if Enabled then Item.Tones (Of_Tone, Edge) else Item.Tones (Of_Tone, Off_Edge));

   type Bevel_Colors is record
      Light, Dark : Color;
   end record;

   function Bevel_For
     (Item    : Theme;
      Of_Tone : Tone := Normal_Tone;
      Hovered : Boolean := False;
      Held    : Boolean := False) return Bevel_Colors is
     (if Held then (Item.Tones (Of_Tone, Pressed_Lit), Item.Tones (Of_Tone, Pressed_Shaded))
      elsif Hovered then (Item.Tones (Of_Tone, Hover_Lit), Item.Tones (Of_Tone, Hover_Shaded))
      else (Item.Tones (Of_Tone, Lit), Item.Tones (Of_Tone, Shaded)));
   --  The edges of the bevel of a control in its state, which are made from
   --  the face it shows.

   function Ink_For
     (Item    : Theme;
      Of_Tone : Tone := Normal_Tone;
      Enabled : Boolean := True;
      Hovered : Boolean := False) return Color is
     (if not Enabled then Item.Tones (Of_Tone, Off_Ink)
      elsif Hovered then Item.Tones (Of_Tone, Ink_Hover)
      else Item.Tones (Of_Tone, Ink));
   --  The ink on it.

   White : constant Color := (255, 255, 255, 255);
   Paper : constant Color := (16#FC#, 16#FC#, 16#FA#, 255);
   --  Of a page, a window, a field: white, softened.
   Soft_White : constant Color := (16#F6#, 16#F8#, 16#F6#, 255);
   --  Of the light text on a dark bar or a coloured button.

   Shadow_Offset : constant Float := 3.0;
   --  In points, down and to the right, of a shadow.

   Raise_Offset : constant Float := 2.0;
   --  In points, of the room a control that stands up is given for it.

   function Channel
     (A, B : SDL3.Windows.Renderers.Color_Component; Amount : Float)
      return SDL3.Windows.Renderers.Color_Component is
     (SDL3.Windows.Renderers.Color_Component
        (Float'Rounding (Float (A) + (Float (B) - Float (A)) * Amount)))
     with Pre => Amount in 0.0 .. 1.0;

   function Mix (From, To : Color; Amount : Float) return Color is
     ((Red   => Channel (From.Red, To.Red, Amount),
       Green => Channel (From.Green, To.Green, Amount),
       Blue  => Channel (From.Blue, To.Blue, Amount),
       Alpha => Channel (From.Alpha, To.Alpha, Amount)))
     with Pre => Amount in 0.0 .. 1.0;
   --  Amount of the way from From to To.

   function Highlight (Base : Color) return Color is
     (Mix (Base, (255, 255, 255, 255), 0.55));
   function Shadow_Of (Base : Color) return Color is
     (Mix (Base, (0, 0, 0, 255), 0.35));
   --  The edges of a bevel round a face: of the light, from above and
   --  the left, and away from it.

   function Dull (Item : Theme; Base : Color) return Color is
     (Mix (Base, Item.Slots (Background), 0.55));
   --  A face, or an ink, of what is turned off: flat, and faint.

   function Inactive_Selection (Item : Theme) return Color is
     (Mix (Item.Slots (Background), Item.Slots (Foreground), 0.15));
   --  Behind selected text, when it has not the focus.

private

   Light_Foreground : constant Color := (16#1E#, 16#27#, 16#23#, 255);
   Light_Background : constant Color := (16#D5#, 16#DB#, 16#D7#, 255);
   Light_Face       : constant Color := (16#A9#, 16#B1#, 16#AD#, 255);
   Light_Border     : constant Color := (16#A9#, 16#B2#, 16#AD#, 255);
   Light_Edge       : constant Color := (16#8B#, 16#96#, 16#90#, 255);
   Light_Green      : constant Color := (16#3D#, 16#7A#, 16#4C#, 255);
   Light_Red        : constant Color := (16#B4#, 16#48#, 16#3F#, 255);
   Dark_Green       : constant Color := (16#3A#, 16#78#, 16#46#, 255);
   Dark_Red         : constant Color := (16#C2#, 16#47#, 16#3F#, 255);

   Light_Palette : constant Palette :=
     (Dark        => False,
      Bevelled    => True,
      Background  => Light_Background,
      Foreground  => Light_Foreground,
      Page        => Paper,
      Face        => Light_Face,
      Edge        => Light_Edge,
      Border      => Light_Border,
      Shadow      => (16#BC#, 16#C5#, 16#C0#, 255),
      Focus       => (16#45#, 16#70#, 16#B8#, 255),
      Accent      => (16#DD#, 16#B2#, 16#7C#, 255),
      Primary     => Light_Green,
      Danger      => Light_Red,
      Primary_Ink => Light_Green,
      Danger_Ink  => Light_Red,
      Bar         => (16#5C#, 16#6A#, 16#64#, 255),
      Tint        => (16#E4#, 16#E8#, 16#E5#, 255),
      Marker      => (16#F0#, 16#D0#, 16#60#, 255),
      Scrim       => (16#1E#, 16#27#, 16#23#, 128),
      Drop_Shadow => Mix (Light_Border, Light_Foreground, 0.4),
      Face_Hover  => Mix (Light_Face, White, 0.22),
      Face_Pressed => Mix (Light_Face, Light_Foreground, 0.12),
      Face_Light  => (16#EA#, 16#EE#, 16#EC#, 255),
      Face_Shade  => (16#9E#, 16#A9#, 16#A3#, 255),
      Primary_Light => Highlight (Light_Green),
      Primary_Shade => Shadow_Of (Light_Green),
      Danger_Light  => Highlight (Light_Red),
      Danger_Shade  => Shadow_Of (Light_Red),
      AI            => (16#6B#, 16#3F#, 16#B8#, 255),
      AI_Light      => Highlight ((16#6B#, 16#3F#, 16#B8#, 255)),
      AI_Shade      => Shadow_Of ((16#6B#, 16#3F#, 16#B8#, 255)));

   Dark_Palette : constant Palette :=
     (Dark        => True,
      Bevelled    => True,
      Background  => (16#1C#, 16#22#, 16#20#, 255),
      Foreground  => (16#E3#, 16#E9#, 16#E5#, 255),
      Page        => (16#32#, 16#3B#, 16#37#, 255),
      Face        => (16#4A#, 16#55#, 16#50#, 255),
      Edge        => (16#15#, 16#1A#, 16#18#, 255),
      Border      => (16#4A#, 16#55#, 16#50#, 255),
      Shadow      => (16#0D#, 16#11#, 16#10#, 255),
      Focus       => (16#7D#, 16#A6#, 16#FF#, 255),
      Accent      => (16#DD#, 16#B2#, 16#7C#, 255),
      Primary     => Dark_Green,
      Danger      => Dark_Red,
      Primary_Ink => (16#7F#, 16#C4#, 16#8A#, 255),
      Danger_Ink  => (16#F0#, 16#98#, 16#8E#, 255),
      Bar         => (16#12#, 16#16#, 16#14#, 255),
      Tint        => (16#2B#, 16#33#, 16#30#, 255),
      Marker      => (16#E6#, 16#C8#, 16#5A#, 255),
      Scrim       => (16#0D#, 16#11#, 16#10#, 160),
      Drop_Shadow => (16#0D#, 16#11#, 16#10#, 255),
      Face_Hover  => (16#54#, 16#60#, 16#59#, 255),
      Face_Pressed => (16#3E#, 16#48#, 16#43#, 255),
      Face_Light  => (16#6A#, 16#77#, 16#71#, 255),
      Face_Shade  => (16#2D#, 16#35#, 16#32#, 255),
      Primary_Light => (16#66#, 16#AE#, 16#74#, 255),
      Primary_Shade => (16#1B#, 16#44#, 16#25#, 255),
      Danger_Light  => (16#E0#, 16#8A#, 16#82#, 255),
      Danger_Shade  => (16#7C#, 16#25#, 16#20#, 255),
      AI            => (16#8A#, 16#5C#, 16#E0#, 255),
      AI_Light      => (16#B0#, 16#8C#, 16#F2#, 255),
      AI_Shade      => (16#4E#, 16#2C#, 16#8A#, 255));

end Pomarine.Themes;
