with Ada.Unchecked_Deallocation;

package body Pomarine.Words is

   procedure Free is new Ada.Unchecked_Deallocation (Word_Array, Word_Array_Access);
   procedure Free is new Ada.Unchecked_Deallocation (String, Text_Access);

   procedure Reserve (Item : in out Result; Words_Wanted : Natural; Bytes : Natural) is
   begin
      if Item.Words = null or else Item.Words'Length < Words_Wanted then
         declare
            Room   : constant Positive :=
              Positive'Max (64, Positive'Max (Words_Wanted, (if Item.Words = null then 0 else 2 * Item.Words'Length)));
            Bigger : constant Word_Array_Access := new Word_Array (1 .. Room);
         begin
            if Item.Words /= null then
               Bigger (1 .. Item.Count) := Item.Words (1 .. Item.Count);
               Free (Item.Words);
            end if;
            Item.Words := Bigger;
         end;
      end if;
      if Item.Text = null or else Item.Text'Length < Bytes then
         declare
            Room   : constant Positive :=
              Positive'Max (1_024, Positive'Max (Bytes, (if Item.Text = null then 0 else 2 * Item.Text'Length)));
            Bigger : constant Text_Access := new String'(1 .. Room => ' ');
         begin
            if Item.Text /= null then
               Bigger (1 .. Item.Length) := Item.Text (1 .. Item.Length);
               Free (Item.Text);
            end if;
            Item.Text := Bigger;
         end;
      end if;
   end Reserve;

   procedure Clear (Item : in out Result) is
   begin
      Item.Count := 0;
      Item.Length := 0;
      Item.Truncated := False;
   end Clear;

   overriding
   procedure Adjust (Item : in out Result) is
   begin
      if Item.Words /= null then
         Item.Words := new Word_Array'(Item.Words (1 .. Item.Words'Length));
      end if;
      if Item.Text /= null then
         Item.Text := new String'(Item.Text.all);
      end if;
   end Adjust;

   overriding
   procedure Finalize (Item : in out Result) is
   begin
      Free (Item.Words);
      Free (Item.Text);
   end Finalize;

end Pomarine.Words;
