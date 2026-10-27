package body Todo_VM is
   package VM renames Pomarine.View_Models;
   use type VM.Version_Number;

   overriding
   function Parts_Version (Self : Model) return VM.Version_Number
   is (VM.Version (Self.Text) + VM.Version_Number (Tasks.Version (Self.Items)));
   function Count (Self : Model) return Natural
   is (Tasks.Count (Self.Items));
   function Draft (Self : Model) return String
   is (VM.Get (Self.Text));
   function Selected_Task (Self : Model) return Natural
   is (Self.Choice);
   function Selected (Self : Model) return Natural
   is (Tasks.Find (Self.Items, Self.Choice));
   function Rows (Self : in out Model) return not null access Tasks.Task_List
   is (Self.Items'Unchecked_Access);
   function Row_Model (Self : in out Model) return not null access Pomarine.Models.List_Model'Class
   is (Self.Items'Unchecked_Access);
   function Summary (Self : Model) return String
   is (Tasks.Open_Count (Self.Items)'Image & " of" & Count (Self)'Image & " left");

   procedure Set_Draft (Self : in out Model; Text : String) is
   begin
      VM.Set (Self.Text, Text);
   end Set_Draft;

   procedure Select_Task (Self : in out Model; Id : Natural) is
   begin
      if Self.Choice /= Id then
         Self.Choice := Id;
         Mark_Changed (Self);
      end if;
   end Select_Task;

   procedure Select_Row (Self : in out Model; Row : Natural) is
   begin
      Select_Task (Self, (if Row = 0 then 0 else Tasks.Row_Id (Self.Items, Row)));
   end Select_Row;

   procedure Seed (Self : in out Model) is
   begin
      Set_Draft (Self, "Read the Pomarine README");
      Execute (Self, Add_Task);
      Set_Draft (Self, "Build the examples");
      Execute (Self, Add_Task);
   end Seed;

   overriding
   function Can_Execute (Self : Model; What : Command; Index : Natural := 0) return Boolean
   is (Index = 0
       and then (case What is
                   when Add_Task                      => Draft (Self)'Length > 0,
                   when Toggle_Chosen | Remove_Chosen => Selected (Self) > 0,
                   when Sweep_Done                    => Tasks.Open_Count (Self.Items) < Count (Self)));

   overriding
   procedure Perform (Self : in out Model; What : Command; Index : Natural := 0) is
      pragma Unreferenced (Index);
   begin
      case What is
         when Add_Task      =>
            Tasks.Add (Self.Items, Draft (Self));
            VM.Set (Self.Text, "");

         when Toggle_Chosen =>
            Tasks.Toggle (Self.Items, Selected (Self));

         when Remove_Chosen =>
            Tasks.Delete (Self.Items, Selected (Self));
            Self.Choice := 0;

         when Sweep_Done    =>
            Tasks.Clear_Done (Self.Items);
            Self.Choice := 0;
      end case;
   end Perform;
end Todo_VM;
