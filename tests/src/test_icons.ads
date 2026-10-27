with Pomarine.Icons;

--  The icons the tests draw with: plain shapes in tests/icons, standing in
--  for whatever an application would give. The library has no pictures.

package Test_Icons is

   Square   : constant Pomarine.Icons.Icon := Pomarine.Icons.Custom (0);
   Circle   : constant Pomarine.Icons.Icon := Pomarine.Icons.Custom (1);
   Triangle : constant Pomarine.Icons.Icon := Pomarine.Icons.Custom (2);
   Diamond  : constant Pomarine.Icons.Icon := Pomarine.Icons.Custom (3);
   Plus     : constant Pomarine.Icons.Icon := Pomarine.Icons.Custom (4);
   Bars     : constant Pomarine.Icons.Icon := Pomarine.Icons.Custom (5);
   Ring     : constant Pomarine.Icons.Icon := Pomarine.Icons.Custom (6);
   Slash    : constant Pomarine.Icons.Icon := Pomarine.Icons.Custom (7);
   Arrow    : constant Pomarine.Icons.Icon := Pomarine.Icons.Custom (8);

   procedure Install (Library : in out Pomarine.Icons.Library);
   --  Their folder and files.

end Test_Icons;
