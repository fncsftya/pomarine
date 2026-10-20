package body Pomarine.Marks is
   function Can_Undo (Past : History) return Boolean is (Past.Position > 0);
   function Can_Redo (Past : History) return Boolean is (Past.Position < Past.Count);

   procedure Record_Edit (Past : in out History; Value : Mark; Index : Positive; Added : Boolean) is
   begin
      Past.Count := Past.Position;
      if Past.Count = Undo_Depth then
         Past.Steps (1 .. Undo_Depth - 1) := Past.Steps (2 .. Undo_Depth);
         Past.Position := Past.Position - 1;
         Past.Count := Past.Count - 1;
      end if;
      Past.Count := Past.Count + 1;
      Past.Position := Past.Count;
      Past.Steps (Past.Count) := (Added, Value, Index);
   end Record_Edit;

   procedure Record_Add (Past : in out History; Value : Mark; Index : Positive) is
   begin
      Record_Edit (Past, Value, Index, Added => True);
   end Record_Add;

   procedure Record_Remove (Past : in out History; Value : Mark; Index : Positive) is
   begin
      Record_Edit (Past, Value, Index, Added => False);
   end Record_Remove;

   procedure Apply (Change : Edit; Shown : in out Mark_Array; Count : in out Natural; Insert : Boolean) is
   begin
      if Insert then
         pragma Assert (Count < Max_Marks and then Change.Index <= Count + 1);
         Shown (Change.Index + 1 .. Count + 1) := Shown (Change.Index .. Count);
         Shown (Change.Index) := Change.Value;
         Count := Count + 1;
      else
         pragma Assert (Change.Index <= Count);
         Shown (Change.Index .. Count - 1) := Shown (Change.Index + 1 .. Count);
         Count := Count - 1;
      end if;
   end Apply;

   procedure Undo (Past : in out History; Shown : in out Mark_Array; Count : in out Natural) is
   begin
      Apply (Past.Steps (Past.Position), Shown, Count, Insert => not Past.Steps (Past.Position).Added);
      Past.Position := Past.Position - 1;
   end Undo;

   procedure Redo (Past : in out History; Shown : in out Mark_Array; Count : in out Natural) is
   begin
      Past.Position := Past.Position + 1;
      Apply (Past.Steps (Past.Position), Shown, Count, Insert => Past.Steps (Past.Position).Added);
   end Redo;
end Pomarine.Marks;
