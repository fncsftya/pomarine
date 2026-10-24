with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with Pomarine.Models;

--  The tasks of Todo_GUI, kept as the application likes (a growing vector)
--  and shown by a list as a model: the list asks only for the rows it
--  draws, and looks at Version to know when to ask again.
package Tasks is

   type Task_List is limited new Pomarine.Models.List_Model with private;

   overriding function Count (Self : Task_List) return Natural;
   overriding function Version (Self : Task_List) return Natural;
   overriding function Row_Id (Self : Task_List; Row : Positive) return Positive;
   overriding procedure Describe_Row
     (Self : Task_List; Row : Positive; Content : out Pomarine.Models.Row_Content);

   procedure Add (Item : in out Task_List; Text : String)
     with Post => Count (Item) = Count (Item)'Old + 1;

   procedure Toggle (Item : in out Task_List; Row : Positive)
     with Pre => Row <= Count (Item);
   --  Done becomes not done, and the other way.

   procedure Delete (Item : in out Task_List; Row : Positive)
     with Pre => Row <= Count (Item);

   procedure Clear_Done (Item : in out Task_List);

   function Open_Count (Item : Task_List) return Natural;
   --  How many are not done.

private

   type Task_Item is record
      Id   : Positive;
      Text : Ada.Strings.Unbounded.Unbounded_String;
      Done : Boolean := False;
   end record;

   package Task_Vectors is new Ada.Containers.Vectors (Positive, Task_Item);

   type Task_List is limited new Pomarine.Models.List_Model with record
      Items   : Task_Vectors.Vector;
      Changed : Natural := 0;
      Next_Id : Positive := 1;
   end record;

end Tasks;
