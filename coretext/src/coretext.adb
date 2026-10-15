package body CoreText is

   function Valid_Size (Text : String; At_Index : Positive) return Natural is
      Lead : constant Natural := Character'Pos (Text (At_Index));
      Size : constant Natural :=
        (if Lead < 16#80# then 1
         elsif Lead in 16#C2# .. 16#DF# then 2
         elsif Lead in 16#E0# .. 16#EF# then 3
         elsif Lead in 16#F0# .. 16#F4# then 4
         else 0);
   begin
      if Size <= 1 then
         return Size;
      elsif At_Index + Size - 1 > Text'Last then
         return 0;
      end if;
      for Offset in 1 .. Size - 1 loop
         if Character'Pos (Text (At_Index + Offset)) not in 16#80# .. 16#BF# then
            return 0;
         end if;
      end loop;
      declare
         Second : constant Natural := Character'Pos (Text (At_Index + 1));
      begin
         if (Lead = 16#E0# and then Second < 16#A0#)
           or else (Lead = 16#ED# and then Second > 16#9F#)
           or else (Lead = 16#F0# and then Second < 16#90#)
           or else (Lead = 16#F4# and then Second > 16#8F#)
         then
            return 0;
         end if;
      end;
      return Size;
   end Valid_Size;

   function Is_BOM (Text : String; At_Index : Positive; Size : Natural) return Boolean is
     (Size = 3 and then Character'Pos (Text (At_Index)) = 16#EF#
      and then Character'Pos (Text (At_Index + 1)) = 16#BB#
      and then Character'Pos (Text (At_Index + 2)) = 16#BF#);

   function Is_Clean (Text : String) return Boolean is
      At_Index : Natural := Text'First;
   begin
      while At_Index <= Text'Last loop
         declare
            Size : constant Natural := Valid_Size (Text, At_Index);
         begin
            if Size = 0 or else Is_BOM (Text, At_Index, Size) then
               return False;
            end if;
            At_Index := At_Index + Size;
         end;
      end loop;
      return True;
   end Is_Clean;

   function Sanitized (Text : String) return String is
      Result   : String (1 .. Text'Length) := Text;
      At_Index : Natural := Text'First;
   begin
      while At_Index <= Text'Last loop
         declare
            Size : constant Natural := Valid_Size (Text, At_Index);
            To   : constant Positive := At_Index - Text'First + 1;
         begin
            if Size = 0 then
               Result (To) := '?';
               At_Index := At_Index + 1;
            else
               if Is_BOM (Text, At_Index, Size) then
                  Result (To .. To + 2) :=
                    [Character'Val (16#E2#), Character'Val (16#81#), Character'Val (16#A0#)];
               end if;
               At_Index := At_Index + Size;
            end if;
         end;
      end loop;
      return Result;
   end Sanitized;

   function UTF16_Length (Text : String) return Natural is
      Count    : Natural := 0;
      At_Index : Natural := Text'First;
   begin
      while At_Index <= Text'Last loop
         declare
            Size : constant Natural := Valid_Size (Text, At_Index);
         begin
            Count := Count + (if Size = 4 then 2 else 1);
            At_Index := At_Index + Natural'Max (Size, 1);
         end;
      end loop;
      return Count;
   end UTF16_Length;

end CoreText;
