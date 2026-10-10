package body Test_Icons is

   procedure Install (Library : in out Pomarine.Icons.Library) is
   begin
      Pomarine.Icons.Set_Directory (Library, "icons");
      Pomarine.Icons.Set_File (Library, Square, "square.svg");
      Pomarine.Icons.Set_File (Library, Circle, "circle.svg");
      Pomarine.Icons.Set_File (Library, Triangle, "triangle.svg");
      Pomarine.Icons.Set_File (Library, Diamond, "diamond.svg");
      Pomarine.Icons.Set_File (Library, Plus, "plus.svg");
      Pomarine.Icons.Set_File (Library, Bars, "bars.svg");
      Pomarine.Icons.Set_File (Library, Ring, "ring.svg");
      Pomarine.Icons.Set_File (Library, Slash, "slash.svg");
      Pomarine.Icons.Set_File (Library, Arrow, "arrow.svg");
   end Install;

end Test_Icons;
