package body Form_UI is

   function Read_Name (Item : Form_VM.Model) return String is
   begin
      Name_Reads := Name_Reads + 1;
      return Form_VM.Name (Item);
   end Read_Name;

   function Read_Status (Item : Form_VM.Model) return String is
   begin
      Status_Reads := Status_Reads + 1;
      return Form_VM.Status (Item);
   end Read_Status;

   function Name_Present (Item : Form_VM.Model) return Boolean is (Form_VM.Name (Item)'Length > 0);

   procedure Wipe (Item : in out Form_VM.Model) is
   begin
      Form_VM.Set_Name (Item, "");
   end Wipe;

end Form_UI;
