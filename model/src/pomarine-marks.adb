with Ada.Unchecked_Deallocation;

package body Pomarine.Marks is
   procedure Free is new Ada.Unchecked_Deallocation (Mark_Array, Mark_Array_Access);

   procedure Reserve (Store : in out Mark_Store; Count : Natural) is
   begin
      if Store.Data = null or else Store.Data'Length < Count then
         declare
            Room   : constant Positive :=
              Positive'Max (16, Positive'Max (Count, (if Store.Data = null then 0 else 2 * Store.Data'Length)));
            Bigger : constant Mark_Array_Access := new Mark_Array (1 .. Room);
         begin
            if Store.Data /= null then
               Bigger (Store.Data'Range) := Store.Data.all;
               Free (Store.Data);
            end if;
            Store.Data := Bigger;
         end;
      end if;
   end Reserve;

   overriding procedure Adjust (Store : in out Mark_Store) is
   begin
      if Store.Data /= null then
         Store.Data := new Mark_Array'(Store.Data.all);
      end if;
   end Adjust;

   overriding procedure Finalize (Store : in out Mark_Store) is
   begin
      Free (Store.Data);
   end Finalize;

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

   procedure Apply (Change : Edit; Shown : in out Mark_Store; Count : in out Natural; Insert : Boolean) is
   begin
      if Insert then
         pragma Assert (Change.Index <= Count + 1);
         Reserve (Shown, Count + 2);
         Shown.Data (Change.Index + 1 .. Count + 1) := Shown.Data (Change.Index .. Count);
         Shown.Data (Change.Index) := Change.Value;
         Count := Count + 1;
      else
         pragma Assert (Change.Index <= Count);
         Shown.Data (Change.Index .. Count - 1) := Shown.Data (Change.Index + 1 .. Count);
         Count := Count - 1;
      end if;
   end Apply;

   procedure Undo (Past : in out History; Shown : in out Mark_Store; Count : in out Natural) is
   begin
      Apply (Past.Steps (Past.Position), Shown, Count, Insert => not Past.Steps (Past.Position).Added);
      Past.Position := Past.Position - 1;
   end Undo;

   procedure Redo (Past : in out History; Shown : in out Mark_Store; Count : in out Natural) is
   begin
      Past.Position := Past.Position + 1;
      Apply (Past.Steps (Past.Position), Shown, Count, Insert => Past.Steps (Past.Position).Added);
   end Redo;
end Pomarine.Marks;
