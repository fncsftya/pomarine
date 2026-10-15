--  What a widget that shows many things reads them from, without being
--  given them all: a model. The application keeps its data as it likes, and
--  a model is how a list asks for the few rows it is showing. Nothing is
--  copied but what is shown, so a list of a hundred thousand rows costs
--  what a screenful does.
package Pomarine.Models is

   Text_Capacity : constant := 160;
   --  Bytes of a row's text and of its detail; more is cut off.

   type Row_Content is record
      Text          : String (1 .. Text_Capacity) := [others => ' '];
      Text_Length   : Natural range 0 .. Text_Capacity := 0;
      Detail        : String (1 .. Text_Capacity) := [others => ' '];
      Detail_Length : Natural range 0 .. Text_Capacity := 0;
   end record;
   --  What a row of a list shows: its text, and, small and faint at the
   --  other end, its detail (a count, a date).

   procedure Set_Text (Item : in out Row_Content; Text : String);
   procedure Set_Detail (Item : in out Row_Content; Text : String);
   function Text_Of (Item : Row_Content) return String;
   function Detail_Of (Item : Row_Content) return String;

   type List_Model is limited interface;

   function Count (Self : List_Model) return Natural is abstract;
   --  How many rows.

   function Version (Self : List_Model) return Natural is abstract;
   --  A number that is different whenever any row, or how many there are,
   --  is: a list looks at it each turn, and shows the rows again if it has
   --  changed.

   function Row_Id (Self : List_Model; Row : Positive) return Positive is abstract
     with Pre'Class => Row <= Count (Self);
   --  A number for the row that is its own for as long as the row lasts,
   --  wherever it moves to: what a list keeps for the row it has selected,
   --  and an assistive technology for each row. Different for each.

   procedure Describe_Row
     (Self    : List_Model;
      Row     : Positive;
      Content : out Row_Content) is abstract
     with Pre'Class => Row <= Count (Self);
   --  What the row shows.

   type Model_Access is access all List_Model'Class;

   --  A model of rows of text kept in a fixed place: for a list the
   --  application fills by hand.

   type Text_List (Capacity : Positive) is limited new List_Model with private;

   procedure Clear (Item : in out Text_List)
     with Post => Count (Item) = 0;

   procedure Append (Item : in out Text_List; Text : String; Detail : String := "")
     with Pre  => Count (Item) < Item.Capacity,
          Post => Count (Item) = Count (Item)'Old + 1;

   procedure Replace (Item : in out Text_List; Row : Positive; Text : String; Detail : String := "")
     with Pre => Row <= Count (Item);

   procedure Delete (Item : in out Text_List; Row : Positive)
     with Pre  => Row <= Count (Item),
          Post => Count (Item) = Count (Item)'Old - 1;
   --  The rows after it move up; each keeps its id.

   overriding function Count (Self : Text_List) return Natural;
   overriding function Version (Self : Text_List) return Natural;
   overriding function Row_Id (Self : Text_List; Row : Positive) return Positive;
   overriding procedure Describe_Row
     (Self : Text_List; Row : Positive; Content : out Row_Content);

private

   type Row_Array is array (Positive range <>) of Row_Content;
   type Id_Array is array (Positive range <>) of Positive;

   type Text_List (Capacity : Positive) is limited new List_Model with record
      Used    : Natural := 0;
      Changed : Natural := 0;
      Next_Id : Positive := 1;
      Rows    : Row_Array (1 .. Capacity);
      Ids     : Id_Array (1 .. Capacity) := [others => 1];
   end record;

end Pomarine.Models;
