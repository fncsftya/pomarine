with Interfaces.C;
with System;
with SDL3.Errors;
with SDL3.Thin;

package body SDL3.Cursors is

   use type Thin.Cursor;
   use type System.Address;

   Made : array (Kind) of Thin.Cursor := [others => Thin.Cursor (System.Null_Address)];
   --  Each system cursor lives as long as the program.

   function System_Id (Which : Kind) return Interfaces.C.int
   is (case Which is
         when Default         => 0,   --  SDL_SYSTEM_CURSOR_DEFAULT
         when Move            => 9,   --  SDL_SYSTEM_CURSOR_MOVE
         when Pointer         => 11,  --  SDL_SYSTEM_CURSOR_POINTER
         when Resize          => 5,   --  SDL_SYSTEM_CURSOR_NWSE_RESIZE
         when Crosshair       => 3,   --  SDL_SYSTEM_CURSOR_CROSSHAIR
         when Resize_Across   => 7,  --  SDL_SYSTEM_CURSOR_EW_RESIZE
         when Resize_Up_Down  => 8,  --  SDL_SYSTEM_CURSOR_NS_RESIZE
         when Text            => 1,   --  SDL_SYSTEM_CURSOR_TEXT
         when Grab | Grabbing => 11);  --  the hand, where there is no picture

   --  The hands are drawn here, as SVG: each shape twice, in black, wider,
   --  then in white, so that only the outline is left of the first.
   Hand_Head : constant String :=
     "<svg xmlns='http://www.w3.org/2000/svg' width='24' height='24' " & "viewBox='0 0 24 24'>";

   function Hand_Shapes (Open : Boolean; Ink : String; Edge : String) return String is
      Style : constant String := " fill='" & Ink & "' " & Edge;
   begin
      if Open then
         return
           "<rect x='7.5' y='3.5' width='3' height='11' rx='1.5'"
           & Style
           & "/>"
           & "<rect x='10.5' y='2.5' width='3' height='12' rx='1.5'"
           & Style
           & "/>"
           & "<rect x='13.5' y='3.5' width='3' height='11' rx='1.5'"
           & Style
           & "/>"
           & "<rect x='16.5' y='5.5' width='3' height='9' rx='1.5'"
           & Style
           & "/>"
           & "<rect x='6' y='10' width='13.5' height='10' rx='4.5'"
           & Style
           & "/>"
           & "<rect x='3' y='10.5' width='3.2' height='7.5' rx='1.6'"
           & " transform='rotate(-28 4.6 14)'"
           & Style
           & "/>";
      else
         return
           "<rect x='5.5' y='8' width='3' height='6' rx='1.5'"
           & Style
           & "/>"
           & "<rect x='8.5' y='7' width='3' height='7' rx='1.5'"
           & Style
           & "/>"
           & "<rect x='11.5' y='7' width='3' height='7' rx='1.5'"
           & Style
           & "/>"
           & "<rect x='14.5' y='8' width='3' height='6' rx='1.5'"
           & Style
           & "/>"
           & "<rect x='5' y='10' width='14' height='9.5' rx='4.5'"
           & Style
           & "/>"
           & "<rect x='3.5' y='12' width='3.2' height='6' rx='1.6'"
           & " transform='rotate(-20 5 15)'"
           & Style
           & "/>";
      end if;
   end Hand_Shapes;

   function Hand_Markup (Open : Boolean) return String
   is (Hand_Head
       & Hand_Shapes (Open, "black", "stroke='black' stroke-width='2.4' stroke-linejoin='round'")
       & Hand_Shapes (Open, "white", "")
       & "</svg>");

   function Hand_Picture (Open : Boolean; Size : Interfaces.C.int) return Thin.Surface_Access is
      Markup : aliased constant String := Hand_Markup (Open);
      Stream : constant System.Address := Thin.IO_From_Const_Mem (Markup'Address, Markup'Length);
      Result : constant Thin.Surface_Access :=
        (if Stream = System.Null_Address then null else Thin.Load_Sized_SVG_IO (Stream, Size, Size));
      Closed : constant Interfaces.C.C_bool :=
        (if Stream = System.Null_Address then Interfaces.C.C_bool (False) else Thin.Close_IO (Stream));
      pragma Unreferenced (Closed);
   begin
      return Result;
   end Hand_Picture;

   function Make_Hand (Open : Boolean) return Thin.Cursor;
   --  The hand as a cursor, 20 points across, finer on a dense display; the
   --  system's pointing hand if it cannot be drawn.

   function Make_Hand (Open : Boolean) return Thin.Cursor is
      use type Thin.Surface_Access;
      Base : constant Thin.Surface_Access := Hand_Picture (Open, 20);
      Fine : constant Thin.Surface_Access := Hand_Picture (Open, 40);
   begin
      if Base = null then
         return Thin.Create_System_Cursor (System_Id (Pointer));
      end if;
      if Fine /= null then
         declare
            Added : constant Interfaces.C.C_bool := Thin.Add_Alternate_Image (Base, Fine);
            pragma Unreferenced (Added);
         begin
            null;
         end;
      end if;
      return Thin.Create_Color_Cursor (Base, 10, 10);
   end Make_Hand;

   procedure Set (Which : Kind) is
   begin
      if Made (Which) = Thin.Cursor (System.Null_Address) then
         Made (Which) :=
           (case Which is
              when Grab     => Make_Hand (Open => True),
              when Grabbing => Make_Hand (Open => False),
              when others   => Thin.Create_System_Cursor (System_Id (Which)));
         if Made (Which) = Thin.Cursor (System.Null_Address) then
            Errors.Raise_Last_Error ("SDL_CreateSystemCursor");
         end if;
      end if;
      Errors.Check (Thin.Set_Cursor (Made (Which)), "SDL_SetCursor");
   end Set;

end SDL3.Cursors;
