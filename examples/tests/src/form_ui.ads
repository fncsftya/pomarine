with Pomarine.UI.Contexts;
with Form_VM;

--  How the tests see Form_VM through Pomarine.UI: instantiated in a package, as the adapters must be.
package Form_UI is

   package Forms is new Pomarine.UI.Contexts (Form_VM.Commands, Form_VM.Model);

   Name_Reads   : Natural := 0;
   Status_Reads : Natural := 0;
   --  How many times the model has been read for them: a refresh when nothing changed shows here.

   function Read_Name (Item : Form_VM.Model) return String;
   function Read_Status (Item : Form_VM.Model) return String;

   package Name_Adapter is new Forms.Edit_Text (Read_Name, Form_VM.Set_Name, Form_VM.Name_Version);
   --  Watches the name alone.
   package Whole_Name_Adapter is new Forms.Edit_Text (Form_VM.Name, Form_VM.Set_Name);
   --  Watches the whole model, so it is refreshed for any change.
   package Counted_Name_Adapter is new Forms.Edit_Text (Read_Name, Form_VM.Set_Name);
   --  Counts reads and watches the whole model.
   package Status_Adapter is new Forms.Read_Text (Read_Status, Form_VM.Saved_Version);
   package Saved_Adapter is new Forms.Read_Text (Form_VM.Last_Saved);

   function Name_Present (Item : Form_VM.Model) return Boolean;
   procedure Wipe (Item : in out Form_VM.Model);
   package Wipe_Adapter is new Forms.Command_Action (Name_Present, Wipe);
   --  A command that is no literal of Form_VM.Command.

   Wipe_Name  : constant Forms.Action_Property := Wipe_Adapter.Property;
   Name       : constant Forms.Text_Property := Name_Adapter.Property;
   Whole_Name : constant Forms.Text_Property := Whole_Name_Adapter.Property;
   Counted    : constant Forms.Text_Property := Counted_Name_Adapter.Property;
   Status     : constant Forms.Text_Property := Status_Adapter.Property;
   Saved      : constant Forms.Text_Property := Saved_Adapter.Property;

end Form_UI;
