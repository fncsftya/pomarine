package body Pomarine.Themes is

   Black : constant Color := (0, 0, 0, 255);

   function Make (From : Palette) return Theme is
      Result : Theme :=
        (Slots => [others => Black],
         Tones => [others => [others => Black]],
         Bevelled => True);

      On_Accent_Ink      : constant Color := (16#1E#, 16#27#, 16#23#, 255);

      function Dulled (Base : Color) return Color is
        (Mix (Base, From.Background, 0.55));

      procedure Set_Role
        (Which        : Tone;
         Base         : Color;
         Hover_Face   : Color;
         Pressed_Face : Color;
         Edge_Color   : Color;
         Ink_Color    : Color;
         Rest_Light   : Color;
         Rest_Shade   : Color)
      is
         Faint : constant Color := Dulled (Base);
      begin
         Result.Tones (Which, Fill)      := Base;
         Result.Tones (Which, Hover)     := Hover_Face;
         Result.Tones (Which, Pressed)   := Pressed_Face;
         Result.Tones (Which, Edge)      := Edge_Color;
         Result.Tones (Which, Ink)       := Ink_Color;
         Result.Tones (Which, Ink_Hover) := Ink_Color;
         Result.Tones (Which, Off)       := Faint;
         Result.Tones (Which, Off_Edge)  := Dulled (Edge_Color);
         Result.Tones (Which, Off_Ink)   := Mix (Ink_Color, Faint, 0.6);
         Result.Tones (Which, Lit)       := Rest_Light;
         Result.Tones (Which, Shaded)    := Rest_Shade;
         Result.Tones (Which, Hover_Lit)     := Highlight (Hover_Face);
         Result.Tones (Which, Hover_Shaded)  := Shadow_Of (Hover_Face);
         Result.Tones (Which, Pressed_Lit)   := Highlight (Pressed_Face);
         Result.Tones (Which, Pressed_Shaded) := Shadow_Of (Pressed_Face);
      end Set_Role;

      procedure Set_Made
        (Which : Tone; Base, Ink_Color : Color; Hover_Amount : Float) is
      begin
         Set_Role
           (Which, Base,
            Hover_Face   => Mix (Base, White, Hover_Amount),
            Pressed_Face => Mix (Base, From.Foreground, 0.12),
            Edge_Color   => Mix (Base, From.Foreground, 0.3),
            Ink_Color    => Ink_Color,
            Rest_Light   => Highlight (Base),
            Rest_Shade   => Shadow_Of (Base));
      end Set_Made;
   begin
      Result.Bevelled := From.Bevelled;
      Result.Slots (Background)  := From.Background;
      Result.Slots (Foreground)  := From.Foreground;
      Result.Slots (Muted)       :=
        Mix (From.Foreground, From.Background, (if From.Dark then 0.30 else 0.27));
      Result.Slots (Hint)        := Mix (From.Foreground, From.Background, 0.35);
      Result.Slots (Page)        := From.Page;
      Result.Slots (Face)        := From.Face;
      Result.Slots (Border)      := From.Border;
      Result.Slots (Shadow)      := From.Shadow;
      Result.Slots (Focus)       := From.Focus;
      Result.Slots (Accent)      := From.Accent;
      Result.Slots (On_Accent)   := On_Accent_Ink;
      Result.Slots (Primary)     := From.Primary;
      Result.Slots (Danger)      := From.Danger;
      Result.Slots (Primary_Ink) := From.Primary_Ink;
      Result.Slots (Danger_Ink)  := From.Danger_Ink;
      Result.Slots (Bar)         := From.Bar;
      Result.Slots (Bar_Ink)     := Soft_White;
      Result.Slots (Rule)        := Mix (From.Bar, Soft_White, 0.3);
      Result.Slots (Tint)        := From.Tint;
      Result.Slots (Strip)       := From.Strip;
      Result.Slots (Hover_Row)   := Mix (From.Face, White, 0.3);
      Result.Slots (Marker)      := From.Marker;
      Result.Slots (Selection)   := Mix (From.Background, From.Accent, 0.4);
      Result.Slots (Scrim)       := From.Scrim;

      Result.Slots (Drop_Shadow) := From.Drop_Shadow;

      Set_Role
        (Normal_Tone, From.Face, From.Face_Hover, From.Face_Pressed, From.Edge,
         From.Foreground, From.Face_Light, From.Face_Shade);
      Set_Made (Primary_Tone, From.Primary, Soft_White, 0.12);
      Result.Tones (Primary_Tone, Lit)    := From.Primary_Light;
      Result.Tones (Primary_Tone, Shaded) := From.Primary_Shade;
      Result.Tones (Primary_Tone, Off_Ink) := Mix (White, Dulled (From.Primary), 0.3);
      Set_Made (Danger_Tone, From.Danger, Soft_White, 0.12);
      Result.Tones (Danger_Tone, Lit)    := From.Danger_Light;
      Result.Tones (Danger_Tone, Shaded) := From.Danger_Shade;
      Result.Tones (Danger_Tone, Off_Ink) := Mix (White, Dulled (From.Danger), 0.3);
      Set_Made (AI_Tone, From.AI, Soft_White, 0.12);
      Set_Made (Warning_Tone, (16#D4#, 16#85#, 16#0F#, 255), Black, 0.12);
      Result.Tones (AI_Tone, Lit)    := From.AI_Light;
      Result.Tones (AI_Tone, Shaded) := From.AI_Shade;
      Result.Tones (AI_Tone, Off_Ink) := Mix (White, Dulled (From.AI), 0.3);
      Set_Made (Selected_Tone, From.Accent, On_Accent_Ink, 0.22);
      Result.Tones (Selected_Tone, Off_Ink) := Mix (From.Foreground, Dulled (From.Accent), 0.6);

      --  No face: only its ink, light on a dark bar.
      Set_Role
        (Quiet_Tone, From.Face, From.Face_Hover, From.Face_Pressed, From.Face,
         Mix (From.Face, White, 0.35), From.Face_Light, From.Face_Shade);
      Result.Tones (Quiet_Tone, Ink_Hover) := Soft_White;
      Result.Tones (Quiet_Tone, Off_Ink)   := Result.Tones (Quiet_Tone, Ink);
      return Result;
   end Make;

   Light_Theme : constant Theme := Make (Light_Palette);
   Dark_Theme  : constant Theme := Make (Dark_Palette);

   function Light return Theme is (Light_Theme);
   function Dark  return Theme is (Dark_Theme);

   function With_Slot (Item : Theme; Which : Slot; To : Color) return Theme is
   begin
      return Result : Theme := Item do
         Result.Slots (Which) := To;
      end return;
   end With_Slot;

   procedure Set_Custom (Item : in out Theme; Offset : Natural; To : Color) is
   begin
      Item.Slots (Custom (Offset)) := To;
   end Set_Custom;

end Pomarine.Themes;
