package body Tasks is

   package Unbounded renames Ada.Strings.Unbounded;

   procedure Add (Item : in out Task_List; Text : String) is
   begin
      Item.Items.Append (Task_Item'(Id => Item.Next_Id, Text => Unbounded.To_Unbounded_String (Text), Done => False));
      Item.Next_Id := Item.Next_Id + 1;
      Item.Changed := Item.Changed + 1;
   end Add;

   procedure Toggle (Item : in out Task_List; Row : Positive) is
   begin
      Item.Items.Reference (Row).Done := not Item.Items (Row).Done;
      Item.Changed := Item.Changed + 1;
   end Toggle;

   procedure Delete (Item : in out Task_List; Row : Positive) is
   begin
      Item.Items.Delete (Row);
      Item.Changed := Item.Changed + 1;
   end Delete;

   procedure Clear_Done (Item : in out Task_List) is
      Row : Positive := 1;
   begin
      while Row <= Natural (Item.Items.Length) loop
         if Item.Items (Row).Done then
            Item.Items.Delete (Row);
         else
            Row := Row + 1;
         end if;
      end loop;
      Item.Changed := Item.Changed + 1;
   end Clear_Done;

   function Open_Count (Item : Task_List) return Natural is
   begin
      return Result : Natural := 0 do
         for Each of Item.Items loop
            if not Each.Done then
               Result := Result + 1;
            end if;
         end loop;
      end return;
   end Open_Count;

   overriding function Count (Self : Task_List) return Natural is (Natural (Self.Items.Length));

   overriding function Version (Self : Task_List) return Natural is (Self.Changed);

   overriding function Row_Id (Self : Task_List; Row : Positive) return Positive is (Self.Items (Row).Id);

   overriding procedure Describe_Row
     (Self : Task_List; Row : Positive; Content : out Pomarine.Models.Row_Content)
   is
      Each : Task_Item renames Self.Items (Row);
   begin
      Content := (others => <>);
      Pomarine.Models.Set_Text (Content, Unbounded.To_String (Each.Text));
      if Each.Done then
         Pomarine.Models.Set_Detail (Content, "done");
         Content.Tone := Pomarine.Models.Good;
         Content.Dimmed := True;
      else
         Pomarine.Models.Set_Detail (Content, "to do");
         Content.Tone := Pomarine.Models.Bad;
      end if;
   end Describe_Row;

end Tasks;
