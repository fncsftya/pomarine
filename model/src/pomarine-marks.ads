with Ada.Finalization;
with Pomarine.Mark_Paths;

--  Picture and document marks, and their bounded, per-source edit history.
package Pomarine.Marks is
   Undo_Depth : constant := 64;

   type Mark is record
      Left, Right, Y : Float := 0.0;
      Trace : Mark_Paths.Path;
      Page : Positive := 1;
   end record
     with Dynamic_Predicate =>
       Mark.Left in 0.0 .. 1.0 and then Mark.Right in Mark.Left .. 1.0
       and then Mark.Y in 0.0 .. 1.0;
   --  Trace is the freehand path; an empty Trace denotes an older horizontal band.

   type Mark_Array is array (Positive range <>) of Mark;
   type Mark_Array_Access is access Mark_Array;

   type Mark_Store is new Ada.Finalization.Controlled with record
      Data : Mark_Array_Access;
      --  Marks (1 .. Count) are in Data, which has room for more: see Reserve.
   end record;
   --  What holds the marks of a picture or a page, as many as are made.

   procedure Reserve (Store : in out Mark_Store; Count : Natural)
     with Post => Store.Data /= null and then Store.Data'Length >= Count;
   --  Have room for Count marks, and keep those there are.

   overriding procedure Adjust (Store : in out Mark_Store);
   overriding procedure Finalize (Store : in out Mark_Store);
   type History is private;
   Empty_History : constant History;

   function Can_Undo (Past : History) return Boolean;
   function Can_Redo (Past : History) return Boolean;

   procedure Record_Add (Past : in out History; Value : Mark; Index : Positive)
     with Post => Can_Undo (Past) and then not Can_Redo (Past);
   procedure Record_Remove (Past : in out History; Value : Mark; Index : Positive)
     with Post => Can_Undo (Past) and then not Can_Redo (Past);
   --  One complete gesture is one step. A new edit discards the redo branch.
   --  When full, the oldest step is forgotten; no allocation is required.

   procedure Undo (Past : in out History; Shown : in out Mark_Store; Count : in out Natural)
     with Pre => Can_Undo (Past),
          Post => Can_Redo (Past);
   procedure Redo (Past : in out History; Shown : in out Mark_Store; Count : in out Natural)
     with Pre => Can_Redo (Past),
          Post => Can_Undo (Past);
   --  Marks and Count must describe the state belonging to Past.

private
   type Edit is record
      Added : Boolean := False;
      Value : Mark;
      Index : Positive := 1;
   end record;
   type Edit_Array is array (Positive range <>) of Edit;
   type History is record
      Steps : Edit_Array (1 .. Undo_Depth);
      Count : Natural range 0 .. Undo_Depth := 0;
      Position : Natural range 0 .. Undo_Depth := 0;
   end record
     with Dynamic_Predicate => History.Position <= History.Count;
   Empty_History : constant History := (others => <>);
end Pomarine.Marks;
