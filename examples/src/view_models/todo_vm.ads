with Tasks;
with Pomarine.Models;
with Pomarine.View_Models;

--  Screen state and commands, independent of widgets and windows.

package Todo_VM is
   type Command is (Add_Task, Toggle_Chosen, Remove_Chosen, Sweep_Done);
   package Commands is new Pomarine.View_Models.Command_Models (Command);
   type Model is limited new Commands.Observed_Model with private;

   overriding
   function Can_Execute (Self : Model; What : Command; Index : Natural := 0) return Boolean;
   overriding
   procedure Perform (Self : in out Model; What : Command; Index : Natural := 0);

   function Count (Self : Model) return Natural;
   function Draft (Self : Model) return String;
   procedure Set_Draft (Self : in out Model; Text : String)
   with Post => Draft (Self) = Text;

   function Selected_Task (Self : Model) return Natural;
   --  The id of the chosen task (Tasks.Row_Id); 0 if none. The choice is of the task, not of its
   --  row: it stays with the task when others are deleted or the rows are moved, and is not given to
   --  another that takes the row's place.
   procedure Select_Task (Self : in out Model; Id : Natural);

   function Selected (Self : Model) return Natural;
   --  The row of the chosen task now; 0 if none, or if it has gone.
   procedure Select_Row (Self : in out Model; Row : Natural)
   with Pre => Row <= Count (Self), Post => Selected (Self) = Row;

   procedure Seed (Self : in out Model)
   with Post => Count (Self) = Count (Self)'Old + 2;
   --  The tasks the example starts with.

   function Summary (Self : Model) return String;
   function Rows (Self : in out Model) return not null access Tasks.Task_List;
   --  Borrowed by the list; Self must outlive the view. Mutate tasks through Execute.
   function Row_Model (Self : in out Model) return not null access Pomarine.Models.List_Model'Class;
   --  The same rows as a list model, for a binding (Listing).

private
   type Model is limited new Commands.Observed_Model with record
      Items  : aliased Tasks.Task_List;
      Text   : Pomarine.View_Models.Text_Property;
      Choice : Natural := 0;
      --  The id of the chosen task.
   end record;

   overriding
   function Parts_Version (Self : Model) return Pomarine.View_Models.Version_Number;
end Todo_VM;
