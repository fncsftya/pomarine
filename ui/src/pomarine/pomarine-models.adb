package body Pomarine.Models is

   procedure Cut (Into : out String; Length : out Natural; Text : String) is
      Last : Natural := Natural'Min (Text'Length, Into'Length);
   begin
      --  Not in the middle of a UTF-8 character.
      if Last < Text'Length then
         while Last > 0 and then Character'Pos (Text (Text'First + Last)) in 16#80# .. 16#BF# loop
            Last := Last - 1;
         end loop;
      end if;
      Length := Last;
      Into (Into'First .. Into'First + Last - 1) := Text (Text'First .. Text'First + Last - 1);
   end Cut;

   procedure Set_Text (Item : in out Row_Content; Text : String) is
   begin
      Cut (Item.Text, Item.Text_Length, Text);
   end Set_Text;

   procedure Set_Detail (Item : in out Row_Content; Text : String) is
   begin
      Cut (Item.Detail, Item.Detail_Length, Text);
   end Set_Detail;

   procedure Set_Action
     (Item   : in out Row_Content;
      Number : Positive;
      Icon   : Pomarine.Icons.Icon;
      Name   : String;
      Danger : Boolean := False) is
   begin
      Item.Actions (Number) := (Present => True, Icon => Icon, Danger => Danger, others => <>);
      Cut (Item.Actions (Number).Name, Item.Actions (Number).Name_Length, Name);
   end Set_Action;

   function Count_Actions (Item : Row_Content) return Natural is
      Found : Natural := 0;
   begin
      for Each of Item.Actions loop
         if Each.Present then
            Found := Found + 1;
         end if;
      end loop;
      return Found;
   end Count_Actions;

   function Action_Name (Item : Row_Content; Number : Positive) return String
   is (Item.Actions (Number).Name (1 .. Item.Actions (Number).Name_Length));

   function Text_Of (Item : Row_Content) return String
   is (Item.Text (1 .. Item.Text_Length));

   function Detail_Of (Item : Row_Content) return String
   is (Item.Detail (1 .. Item.Detail_Length));

   procedure Clear (Item : in out Text_List) is
   begin
      Item.Used := 0;
      Item.Changed := Item.Changed + 1;
   end Clear;

   procedure Append (Item : in out Text_List; Text : String; Detail : String := "") is
   begin
      Item.Used := Item.Used + 1;
      Item.Rows (Item.Used) := (others => <>);
      Set_Text (Item.Rows (Item.Used), Text);
      Set_Detail (Item.Rows (Item.Used), Detail);
      Item.Ids (Item.Used) := Item.Next_Id;
      Item.Next_Id := Item.Next_Id + 1;
      Item.Changed := Item.Changed + 1;
   end Append;

   procedure Replace (Item : in out Text_List; Row : Positive; Text : String; Detail : String := "") is
   begin
      Item.Rows (Row) := (others => <>);
      Set_Text (Item.Rows (Row), Text);
      Set_Detail (Item.Rows (Row), Detail);
      Item.Changed := Item.Changed + 1;
   end Replace;

   procedure Delete (Item : in out Text_List; Row : Positive) is
   begin
      for I in Row .. Item.Used - 1 loop
         Item.Rows (I) := Item.Rows (I + 1);
         Item.Ids (I) := Item.Ids (I + 1);
      end loop;
      Item.Used := Item.Used - 1;
      Item.Changed := Item.Changed + 1;
   end Delete;

   overriding
   function Count (Self : Text_List) return Natural
   is (Self.Used);

   overriding
   function Version (Self : Text_List) return Natural
   is (Self.Changed);

   overriding
   function Row_Id (Self : Text_List; Row : Positive) return Positive
   is (Self.Ids (Row));

   overriding
   procedure Describe_Row (Self : Text_List; Row : Positive; Content : out Row_Content) is
   begin
      Content := Self.Rows (Row);
   end Describe_Row;

end Pomarine.Models;
