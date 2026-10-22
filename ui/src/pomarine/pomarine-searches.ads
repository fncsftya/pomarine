with Ada.Containers.Vectors;
with Pomarine.Words;
with SDL3.Painters;

--  Transient find results, separate from selections and saved pen marks.
package Pomarine.Searches is
   type Match is record
      First, Last : Positive;
      Page : Positive := 1;
   end record;
   package Match_Lists is new Ada.Containers.Vectors (Positive, Match);
   type Box is record
      Hit, Page : Positive;
      Left, Top, Width, Height : Float;
   end record;
   package Box_Lists is new Ada.Containers.Vectors (Positive, Box);
   type Results is record
      Matches : Match_Lists.Vector;
      Boxes : Box_Lists.Vector;
      Current : Natural := 0;
   end record;
   procedure Clear (Item : in out Results)
     with Post => Item.Matches.Is_Empty and then Item.Boxes.Is_Empty and then Item.Current = 0;
   procedure Find (Item : in out Results; Text, Term : String; Page : Positive := 1);
   procedure Find_Words
     (Item : in out Results; Found : Words.Result; Term : String; Page : Positive := 1);
   procedure Step (Item : in out Results; Backwards : Boolean := False)
     with Pre => Item.Current <= Natural (Item.Matches.Length),
          Post => Item.Current <= Natural (Item.Matches.Length);
   procedure Draw
     (Item : Results; Target : SDL3.Painters.Painter'Class;
      Page : Positive; Left, Top, Width, Height : Float);
end Pomarine.Searches;
