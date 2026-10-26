with SDL3.Cursors;
with Pomarine.Events;
with SDL3.Painters;
with Pomarine.Models;
with Pomarine.Scrollbars;
with Pomarine.Semantics;

--  A column of rows read from a model (see Pomarine.Models), as many as it
--  has, a screenful of them drawn: one is chosen with the pointer or the
--  arrow keys, the wheel scrolls, and a bar along the right shows where it
--  is. A row has its text, and, at the other end, a faint detail.
--
--  Only the rows that show are asked for, drawn, and described to an
--  assistive technology (each of them a list item that says which it is of
--  how many), so a list costs the same of a hundred or a hundred thousand
--  rows, and no widget is made for a row.
--
--  A row may also have up to Max_Actions buttons at its end, each an
--  icon, drawn faint when the row is Dimmed (see Pomarine.Models.Row_Content).
--  A click on one says Act, with the Row and which Action, and does not
--  choose the row. With a row chosen, Space does its first button, and Delete
--  or Backspace the first that cannot be undone (see Row_Action). Each is a
--  button of its own to an assistive technology.
--
--  A click on the list below its last rows chooses none (Select_Row 0), and says nothing.
--
--  It says Choose, with the Row, when a row is chosen by a click or the
--  keys, and Click as well when it was a click (Selected says which row), so
--  that what a click does need not be done for each arrow key; Double_Click
--  for a double click on a row, and Submit for Return; Selected says which.
--  It is as high as the layout makes it: it does not size itself to its
--  rows.
package Pomarine.Widgets.Lists is

   Default_Row_Height : constant Float := 28.0;
   --  In points.

   type List is new Widget with private;

   procedure Set_Model (Item : in out List; Model : not null Pomarine.Models.Model_Access);
   --  Show the rows of Model, which must be there as long as the list is
   --  used. The selection is forgotten.

   procedure Set_Row_Height (Item : in out List; Points : Float)
     with Pre => Points >= 12.0;

   function Selected (Item : List) return Natural;
   --  The row that is chosen; 0 if none, or if it is gone from the model.

   procedure Select_Row (Item : in out List; Row : Natural);
   --  Choose Row (0 for none), and bring it into view. Says nothing: it is
   --  the application's doing.

   function Chosen_Id (Item : List) return Natural;
   --  The id (Pomarine.Models.List_Model.Row_Id) of the chosen row; 0 if none. Unlike
   --  Selected, it is the same wherever the row moves to, and costs no search.

   procedure Catch_Up (Item : in out List);
   --  Look at the model now, as Update does: keep what shows within the rows, and let go of a choice
   --  that is gone. For an application that asks Chosen_Id before the list has had its turn.

   procedure Select_Id (Item : in out List; Id : Natural);
   --  Choose the row with that id (0 for none), and bring it into view. An id
   --  no row has is none. Says nothing, as Select_Row.

   procedure Reveal (Item : in out List; Row : Positive);
   --  Scroll, if need be, to show Row.

   procedure Scroll_Smoothly (Item : in out List; To : Float; Milliseconds : Natural := 180)
     with Pre => Is_Attached (Item);
   --  Scroll to show the rows from To points down, over Milliseconds (see
   --  Pomarine.Widgets.Animate); at once if the system asks for less
   --  movement. Reveal, the keys and an assistive technology's scrolling
   --  go so.

   function Offset (Item : List) return Float;
   --  How far the rows have moved up, in points.

   function Button_Part (Row_Id : Positive; Action : Positive) return Positive
     with Pre => Action <= Pomarine.Models.Max_Actions;
   --  The number of the part of an assistive technology that is the
   --  Actionth button of the row with the id Row_Id (see Part_Id).

   function First_Shown (Item : List) return Natural;
   function Last_Shown (Item : List) return Natural;
   --  The rows drawn, in whole or in part: 0 and 0 if none.

   overriding procedure Draw
     (Item   : in out List;
      Target : SDL3.Painters.Painter'Class;
      Colors : Themes.Theme);

   overriding procedure Draw_Over
     (Item   : in out List;
      Target : SDL3.Painters.Painter'Class;
      Colors : Themes.Theme);

   overriding procedure Handle
     (Item    : in out List;
      Event   : Pomarine.Events.Event;
      Handled : out Boolean);

   overriding procedure Update
     (Item : in out List; Now : Pomarine.Events.Milliseconds);

   overriding procedure Hover_Changed (Item : in out List; Hovered : Boolean);

   overriding function Is_Focusable (Item : List) return Boolean;

   overriding procedure Focus_Changed (Item : in out List; Focused : Boolean);

   overriding function Cursor (Item : List) return SDL3.Cursors.Kind;

   overriding procedure Describe
     (Item  : List;
      Facts : in out Semantics.Description);

   overriding procedure Perform
     (Item    : in out List;
      Request : Semantics.Request;
      Done    : out Boolean);

   overriding function Part_Count (Item : List) return Natural;

   overriding function Part_Number (Item : List; Index : Positive) return Positive;

   overriding procedure Describe_Part
     (Item   : List;
      Part   : Positive;
      Facts  : in out Semantics.Description;
      Bounds : out Semantics.Rectangle);

   overriding procedure Perform_Part
     (Item    : in out List;
      Part    : Positive;
      Request : Semantics.Request;
      Done    : out Boolean);

private

   type List is new Widget with record
      Model     : Pomarine.Models.Model_Access;
      Seen      : Natural := 0;
      --  The model's version when it was last looked at.
      Row_Points : Float := Default_Row_Height;
      Moved     : Float := 0.0;
      --  How far the rows have moved up, in points.
      Chosen    : Natural := 0;
      --  The id of the chosen row; 0 for none.
      Over      : Natural := 0;
      Over_Action : Natural := 0;
      --  The row under the pointer.
      Has_Focus : Boolean := False;
      Bar       : Scrollbars.Bar;
   end record;

end Pomarine.Widgets.Lists;
