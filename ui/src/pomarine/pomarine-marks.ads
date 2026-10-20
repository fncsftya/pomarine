with Pomarine.Mark_Paths;

--  Picture and document marks, and their bounded, per-source edit history.
package Pomarine.Marks is
   Max_Marks : constant := 256;
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
   type History is private;
   Empty_History : constant History;

   function Can_Undo (Past : History) return Boolean;
   function Can_Redo (Past : History) return Boolean;

   procedure Record_Add (Past : in out History; Value : Mark; Index : Positive)
     with Pre => Index <= Max_Marks,
          Post => Can_Undo (Past) and then not Can_Redo (Past);
   procedure Record_Remove (Past : in out History; Value : Mark; Index : Positive)
     with Pre => Index <= Max_Marks,
          Post => Can_Undo (Past) and then not Can_Redo (Past);
   --  One complete gesture is one step. A new edit discards the redo branch.
   --  When full, the oldest step is forgotten; no allocation is required.

   procedure Undo (Past : in out History; Shown : in out Mark_Array; Count : in out Natural)
     with Pre => Can_Undo (Past) and then Shown'First = 1 and then Shown'Length >= Max_Marks
                 and then Count <= Max_Marks,
          Post => Can_Redo (Past);
   procedure Redo (Past : in out History; Shown : in out Mark_Array; Count : in out Natural)
     with Pre => Can_Redo (Past) and then Shown'First = 1 and then Shown'Length >= Max_Marks
                 and then Count <= Max_Marks,
          Post => Can_Undo (Past);
   --  Marks and Count must describe the state belonging to Past.

private
   type Edit is record
      Added : Boolean := False;
      Value : Mark;
      Index : Positive range 1 .. Max_Marks := 1;
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
