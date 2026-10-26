with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with Pomarine.Events;
with Pomarine.Semantics;
with SDL3.Cursors;
with SDL3.Painters;

--  Exactly one of a few: tabs, a row of segments, or radio buttons, all the same in what they do. Once it has
--  choices, one of them is chosen: the first to begin with, and then the one the person chooses with a click, or, with
--  the focus (Set_Focusable), with the arrow keys (Home and End too). A choice that is turned off is skipped by the
--  keys and takes no click. It says Choose, with its Row the number of the choice, when the person changes it (and says
--  nothing when the application does, with Select_Choice).
--
--     Choice_Groups.Add (Page, Views, As => Choice_Groups.Tabs);
--     Choice_Groups.Add_Choice (Views, "Write");  Choice_Groups.Add_Choice (Views, "Outline");
--
--  Each choice is as wide as the others (the width of the group over their number), or, in a column of radio buttons,
--  as high as the others; Fit sets the height a group needs.
package Pomarine.Widgets.Choice_Groups is

   type Look_Kind is (Tabs, Segments, Radios);
   --  Tabs: labels along a rule, the chosen one over a bar in the accent. Segments: a row of boxes, the chosen one in
   --  the accent. Radios: a radio button before each label, in a column unless it is made a row.

   type Choice_Group is new Widget with private;

   procedure Add
     (Parent : in out Widget'Class;
      Item   : in out Choice_Group;
      As     : Look_Kind := Tabs)
     with Pre => Is_Attached (Parent) and then not Is_Attached (Item) and then Child_Count (Item) = 0,
          Post => Is_Attached (Item);
   --  Add Item to Parent, as As says, as wide as its parent allows and as high as one line of choices (Fit).

   procedure Set_Look (Item : in out Choice_Group; To : Look_Kind);

   function Look (Item : Choice_Group) return Look_Kind;

   procedure Set_Vertical (Item : in out Choice_Group; To : Boolean);
   --  The choices go down it rather than across: radio buttons do to begin with, tabs and segments do not.

   function Is_Vertical (Item : Choice_Group) return Boolean;

   procedure Add_Choice (Item : in out Choice_Group; Text : String);
   --  After the others. The first is chosen.

   procedure Clear_Choices (Item : in out Choice_Group)
     with Post => Choice_Count (Item) = 0 and then Selected (Item) = 0;

   function Choice_Count (Item : Choice_Group) return Natural;

   function Label (Item : Choice_Group; Index : Positive) return String
     with Pre => Index <= Choice_Count (Item);

   procedure Set_Choice_Enabled (Item : in out Choice_Group; Index : Positive; To : Boolean)
     with Pre => Index <= Choice_Count (Item);

   function Is_Choice_Enabled (Item : Choice_Group; Index : Positive) return Boolean
     with Pre => Index <= Choice_Count (Item);

   procedure Select_Choice (Item : in out Choice_Group; Index : Positive)
     with Pre => Index <= Choice_Count (Item), Post => Selected (Item) = Index;
   --  As the person would, but saying nothing.

   function Selected (Item : Choice_Group) return Natural
     with Post => (Selected'Result = 0) = (Choice_Count (Item) = 0);
   --  Which is chosen; 0 only if there are none.

   procedure Set_Enabled (Item : in out Choice_Group; To : Boolean);

   function Is_Enabled (Item : Choice_Group) return Boolean;

   procedure Fit (Item : in out Choice_Group)
     with Pre => Is_Attached (Item);
   --  Make it as high as its choices need: 32 points for tabs and segments, 24 for each radio button of a column.

   procedure Set_Focusable (Item : in out Choice_Group; To : Boolean);

   overriding function Is_Focusable (Item : Choice_Group) return Boolean;

   overriding function Focuses_On_Click (Item : Choice_Group) return Boolean is (False);

   overriding procedure Handle
     (Item    : in out Choice_Group;
      Event   : Pomarine.Events.Event;
      Handled : out Boolean);

   overriding procedure Draw
     (Item   : in out Choice_Group;
      Target : SDL3.Painters.Painter'Class;
      Colors : Themes.Theme);

   overriding procedure Draw_Over
     (Item   : in out Choice_Group;
      Target : SDL3.Painters.Painter'Class;
      Colors : Themes.Theme);

   overriding procedure Hover_Changed (Item : in out Choice_Group; Hovered : Boolean);

   overriding procedure Focus_Changed (Item : in out Choice_Group; Focused : Boolean);

   overriding function Cursor (Item : Choice_Group) return SDL3.Cursors.Kind;

   overriding procedure Describe (Item : Choice_Group; Facts : in out Semantics.Description);

   overriding function Part_Count (Item : Choice_Group) return Natural;

   overriding procedure Describe_Part
     (Item   : Choice_Group;
      Part   : Positive;
      Facts  : in out Semantics.Description;
      Bounds : out Semantics.Rectangle);

   overriding procedure Perform_Part
     (Item    : in out Choice_Group;
      Part    : Positive;
      Request : Semantics.Request;
      Done    : out Boolean);

private

   type Choice is record
      Text    : Ada.Strings.Unbounded.Unbounded_String;
      Enabled : Boolean := True;
   end record;

   package Choice_Vectors is new Ada.Containers.Vectors (Positive, Choice);

   type Choice_Group is new Widget with record
      Form      : Look_Kind := Tabs;
      Down_Flow : Boolean := False;
      Choices   : Choice_Vectors.Vector;
      Chosen    : Natural := 0;
      Pressed   : Natural := 0;
      Over      : Natural := 0;
      Enabled   : Boolean := True;
      Focusable : Boolean := False;
   end record;

end Pomarine.Widgets.Choice_Groups;
