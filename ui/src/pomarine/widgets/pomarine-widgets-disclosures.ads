with Ada.Strings.Unbounded;
with Pomarine.Events;
with Pomarine.Semantics;
with Pomarine.Widgets.Layouts;
with SDL3.Cursors;
with SDL3.Painters;

--  A heading that shows or hides what is under it: a line with an arrow and a label, and, below it, the widgets the
--  application adds to it (as to any box, with Layouts.Add), in a column, indented. A click on the heading, or Space or
--  Return when it has the focus (Set_Focusable), turns it over, and it says Change; hidden, its widgets take no room
--  and it is only as tall as its heading. Add what is in it before it is closed: a widget added to a closed one shows
--  until it is next opened or closed (Set_Open).
--
--     Disclosures.Add (Page, Advanced, "Advanced", Open => False);
--     Layouts.Add (Advanced, Check, (Height => 24.0, others => <>));
package Pomarine.Widgets.Disclosures is

   Heading_Height : constant Float := 28.0;
   --  In points.

   type Disclosure is new Widget with private;

   function Box_Style return Layouts.Style;
   --  What Add makes its box: a column with the room for the heading above it and the indent beside it, for a screen
   --  that places it itself (Pomarine.UI.Styled).

   procedure Add
     (Parent : in out Widget'Class;
      Item   : in out Disclosure;
      Words  : String;
      Open   : Boolean := True)
     with Pre => Is_Attached (Parent) and then not Is_Attached (Item) and then Child_Count (Item) = 0,
          Post => Is_Attached (Item) and then Is_Open (Item) = Open;

   procedure Set_Title (Item : in out Disclosure; Text : String);

   function Title (Item : Disclosure) return String;

   procedure Set_Open (Item : in out Disclosure; To : Boolean)
     with Pre => Is_Attached (Item), Post => Is_Open (Item) = To;
   --  Show or hide what is under the heading, saying nothing.

   function Is_Open (Item : Disclosure) return Boolean;

   procedure Set_Focusable (Item : in out Disclosure; To : Boolean);

   overriding function Is_Focusable (Item : Disclosure) return Boolean;

   overriding function Focuses_On_Click (Item : Disclosure) return Boolean is (False);

   overriding procedure Handle
     (Item    : in out Disclosure;
      Event   : Pomarine.Events.Event;
      Handled : out Boolean);

   overriding procedure Draw
     (Item   : in out Disclosure;
      Target : SDL3.Painters.Painter'Class;
      Colors : Themes.Theme);

   overriding procedure Draw_Over
     (Item   : in out Disclosure;
      Target : SDL3.Painters.Painter'Class;
      Colors : Themes.Theme);

   overriding procedure Hover_Changed (Item : in out Disclosure; Hovered : Boolean);

   overriding procedure Focus_Changed (Item : in out Disclosure; Focused : Boolean);

   overriding function Cursor (Item : Disclosure) return SDL3.Cursors.Kind;

   overriding procedure Describe (Item : Disclosure; Facts : in out Semantics.Description);

   overriding procedure Perform
     (Item    : in out Disclosure;
      Request : Semantics.Request;
      Done    : out Boolean);

private

   type Disclosure is new Widget with record
      Words     : Ada.Strings.Unbounded.Unbounded_String;
      Opened    : Boolean := True;
      Focusable : Boolean := False;
      Pressed   : Boolean := False;
   end record;

end Pomarine.Widgets.Disclosures;
