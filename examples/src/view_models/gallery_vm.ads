with Tasks;
with Pomarine.View_Models;

--  What the gallery's screen knows, independent of widgets: a count of clicks, a name, a box that is ticked,
--  one of three sizes, a switch, and a short list with a choice of one row.
package Gallery_VM is
   type Command is (Click_Me, Reset, Toggle_Compact, Pick_Size, Remove_Chosen);
   --  Pick_Size is indexed: 1 .. Size_Count.
   package Commands is new Pomarine.View_Models.Command_Models (Command);
   type Model is limited new Commands.Model with private;

   Size_Count : constant := 3;
   Full_At    : constant := 10;
   --  The clicks that fill the progress bar.

   overriding function Version (Self : Model) return Pomarine.View_Models.Version_Number;
   overriding function Can_Execute (Self : Model; What : Command; Index : Natural := 0) return Boolean;
   overriding procedure Execute (Self : in out Model; What : Command; Index : Natural := 0);

   function Clicks (Self : Model) return Natural;
   function Summary (Self : Model) return String;
   function Progress (Self : Model) return Float
     with Post => Progress'Result in 0.0 .. 1.0;

   function Name (Self : Model) return String;
   procedure Set_Name (Self : in out Model; Text : String)
     with Post => Name (Self) = Text;
   function Greeting (Self : Model) return String;

   function Notify (Self : Model) return Boolean;
   procedure Set_Notify (Self : in out Model; To : Boolean)
     with Post => Notify (Self) = To;

   function Compact (Self : Model) return Boolean;

   function Size (Self : Model) return Positive;
   function Is_Size (Self : Model; Index : Positive) return Boolean;

   function Count (Self : Model) return Natural;
   --  Rows in the list.
   function Selected_Item (Self : Model) return Natural;
   --  The id of the chosen row (Tasks.Row_Id); 0 if none.
   procedure Select_Item (Self : in out Model; Id : Natural);
   function Selected (Self : Model) return Natural;
   --  The row of the chosen item now; 0 if none.
   procedure Select_Row (Self : in out Model; Row : Natural)
     with Pre => Row <= Count (Self), Post => Selected (Self) = Row;
   function Rows (Self : in out Model) return not null access Tasks.Task_List;
   --  Borrowed by the list; Self must outlive the view.

   procedure Seed (Self : in out Model)
     with Post => Count (Self) = 4;

private
   type Model is limited new Commands.Model with record
      Taps    : Natural := 0;
      Text    : Pomarine.View_Models.Text_Property;
      Ticked  : Boolean := False;
      Dense   : Boolean := False;
      Picked  : Positive := 2;
      Items   : aliased Tasks.Task_List;
      Choice  : Natural := 0;
      Changed : Pomarine.View_Models.Change_Counter;
   end record;
end Gallery_VM;
