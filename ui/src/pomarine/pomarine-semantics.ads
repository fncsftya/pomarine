with Pomarine_Ui_Config;

--  What a widget is to someone who cannot see it: its role, its name, its
--  value, what it can be told to do. Every widget describes itself in
--  these terms (see Pomarine.Widgets.Describe), the tree sends what has
--  changed of them to an assistive technology (see
--  Pomarine.Accessibility), and what that asks for comes back as an
--  Action on the node, which the widget does as it does a click or a key.
--
--  A widget describes itself by filling in a Description. Nothing in it is
--  kept: it is made when the description is wanted, and only for the
--  widgets that have changed.
package Pomarine.Semantics is

   type Role is
     (Unknown,           --  not said: a widget that must say what it is
      Window,
      Group,             --  boxes that only lay others out
      Label,             --  text that is read
      Heading,
      Button,
      Toggle_Button,
      Check_Box,
      Radio_Button,
      Switch,
      Slider,
      Progress_Indicator,
      Text_Input,        --  one line
      Multiline_Text_Input,
      Menu,
      Menu_Item,
      List,
      List_Item,
      Scroll_View,
      Image,
      Canvas,
      Dialog,
      Tooltip,
      Status,            --  a message that is read out when it appears
      Separator,
      Document,
      Text_Run);
   --  Text_Run: a line of text that is part of a text input's, a part of
   --  it of its own.

   subtype Interactive is Role range Button .. Menu_Item;
   --  Roles that are for the user to act on.

   type Action is
     (Click,
      Focus,
      Blur,
      Increment,
      Decrement,
      Set_Value,
      Expand,
      Collapse,
      Show_Context_Menu,
      Scroll_Into_View,
      Scroll_Up,
      Scroll_Down,
      Scroll_Left,
      Scroll_Right,
      Replace_Selected_Text,
      Set_Text_Selection,
      Show_Tooltip,
      Hide_Tooltip);

   type Action_Set is array (Action) of Boolean with Pack;

   No_Actions : constant Action_Set := [others => False];

   type Toggle is (Not_Toggled, Off, On, Mixed);
   --  Not_Toggled for what is not a check, a switch or a toggle button.

   Text_Capacity : constant := Pomarine_Ui_Config.Semantic_Text;
   --  Characters of a name, a value or a description that are kept; more
   --  is cut off, at a character's edge.

   Value_Capacity : constant := Pomarine_Ui_Config.Semantic_Value;
   --  The same, for a value that may be a paragraph.

   type Text is private;

   type Long_Text is private;
   --  A value: as Text, with room for a paragraph.

   function Empty_Text return Text;
   --  No characters.

   function To_String (Item : Text) return String;
   function Length (Item : Text) return Natural;
   Empty : constant Text;

   procedure Set (Item : out Text; To : String)
     with Post => Length (Item) <= Text_Capacity;
   --  Keep To, cut to fit.

   function To_String (Item : Long_Text) return String;
   function Length (Item : Long_Text) return Natural;
   procedure Set (Item : out Long_Text; To : String)
     with Post => Length (Item) <= Value_Capacity;

   type Text_Place is record
      Part       : Natural := 0;
      --  The number of the Text_Run (see Pomarine.Widgets.Part_Number).
      Characters : Natural := 0;
      --  Characters (not bytes) into its value.
   end record;

   type Description is record
      Kind        : Role := Unknown;
      Name        : Text;
      --  What it is called: a button's label, a field's caption.
      Value       : Long_Text;
      --  What it holds: a field's text, a slider's reading.
      Help        : Text;
      --  More than the name, said after it.
      Disabled    : Boolean := False;
      Focusable   : Boolean := False;
      Selected    : Boolean := False;
      Expanded    : Boolean := False;
      Has_Expanded : Boolean := False;
      --  Whether Expanded is to be said at all.
      Read_Only   : Boolean := False;
      Invalid     : Boolean := False;
      Modal       : Boolean := False;
      Live        : Boolean := False;
      --  A change to it is read out as it happens.
      Checked     : Toggle := Not_Toggled;
      Actions     : Action_Set := No_Actions;
      Has_Number  : Boolean := False;
      Number      : Float := 0.0;
      Minimum     : Float := 0.0;
      Maximum     : Float := 1.0;
      Step        : Float := 0.0;
      --  A slider's or a progress bar's reading, and its range.
      Position    : Natural := 0;
      Set_Size    : Natural := 0;
      --  Of a row of a list that is not all there: which it is of how many.
      Has_Selection : Boolean := False;
      Anchor, Caret : Text_Place;
      --  A text input's selection, between where it began and where its
      --  caret is: each a part of the input (a Text_Run) and a number of
      --  characters into it.
   end record;

   type Rectangle is record
      Left, Top, Right, Bottom : Float := 0.0;
   end record;
   --  A node's place, in points from the top left of its window.

   type Request is record
      Doing   : Action := Click;
      Number  : Float := 0.0;
      --  For Set_Value of a number.
      Contents : Text;
      --  For Set_Value of text, and Replace_Selected_Text.
      Has_Text : Boolean := False;
      Anchor_Part, Focus_Part : Natural := 0;
      Anchor, Focus : Natural := 0;
      --  For Set_Text_Selection: where it runs between, each a Text_Run
      --  (by its number) and a number of characters into it.
   end record;

   function Is_Named (Item : Description) return Boolean is
     (Length (Item.Name) > 0);

   procedure Name_As (Item : in out Description; To : String);
   procedure Value_As (Item : in out Description; To : String);
   procedure Help_As (Item : in out Description; To : String);

   function Can (Item : Description; Doing : Action) return Boolean is
     (Item.Actions (Doing));

   function Image (Item : Role) return String;
   --  The role's name, as a person would say it: "button",
   --  "check box".

private

   subtype Count is Natural range 0 .. Text_Capacity;
   subtype Long_Count is Natural range 0 .. Value_Capacity;

   type Text is record
      Used  : Count := 0;
      Chars : String (1 .. Text_Capacity) := [others => ' '];
   end record;

   type Long_Text is record
      Used  : Long_Count := 0;
      Chars : String (1 .. Value_Capacity) := [others => ' '];
   end record;

   Empty : constant Text := (Used => 0, Chars => [others => ' ']);

   function To_String (Item : Long_Text) return String is
     (Item.Chars (1 .. Item.Used));

   function Length (Item : Long_Text) return Natural is (Item.Used);

   function Empty_Text return Text is (Empty);

   function To_String (Item : Text) return String is
     (Item.Chars (1 .. Item.Used));

   function Length (Item : Text) return Natural is (Item.Used);

end Pomarine.Semantics;
