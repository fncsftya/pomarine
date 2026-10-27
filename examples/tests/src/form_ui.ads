with Pomarine.UI.Contexts;
with Form_VM;

--  How the tests see Form_VM through Pomarine.UI.

package Form_UI is

   package Forms is new Pomarine.UI.Contexts (Form_VM.Commands, Form_VM.Model);

   Name_Reads   : Natural := 0;
   Status_Reads : Natural := 0;
   --  How many times the model has been read for them: a refresh when nothing changed shows here.

   function Read_Name (Item : Form_VM.Model) return String;
   function Read_Status (Item : Form_VM.Model) return String;

   function Name_Present (Item : Form_VM.Model) return Boolean;
   procedure Wipe (Item : in out Form_VM.Model);
   --  A command that is no literal of Form_VM.Command.

   Wipe_Name  : constant Forms.Action_Property := Forms.Doing (Name_Present'Access, Wipe'Access);
   Name       : constant Forms.Text_Property :=
     Forms.Editing (Read_Name'Access, Form_VM.Set_Name'Access, Changes => Form_VM.Name_Version'Access);
   --  Watches the name alone.
   Whole_Name : constant Forms.Text_Property := Forms.Editing (Form_VM.Name'Access, Form_VM.Set_Name'Access);
   --  Watches the whole model, so it is refreshed for any change.
   Counted    : constant Forms.Text_Property := Forms.Editing (Read_Name'Access, Form_VM.Set_Name'Access);
   --  Counts reads and watches the whole model.
   Status     : constant Forms.Text_Property :=
     Forms.Showing (Read_Status'Access, Changes => Form_VM.Saved_Version'Access);
   Saved      : constant Forms.Text_Property := Forms.Showing (Form_VM.Last_Saved'Access);

end Form_UI;
