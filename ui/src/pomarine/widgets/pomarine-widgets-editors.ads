with Pomarine.Semantics;
with SDL3.Painters;
with SDL3.Cursors;
with Pomarine.Events;
with Texts.Documents;
with Pomarine.Icons;
with Pomarine.Text_Areas;
with Pomarine.Widgets.Buttons;
private with Ada.Containers.Vectors;
private with Ada.Strings.Unbounded;
private with Pomarine.Widgets.Labels;
private with Pomarine.Widgets.Menus;
private with Pomarine.Widgets.Panels;
private with Pomarine.Widgets.Selects;
private with Pomarine.Widgets.Tooltips;

--  A text area (see Pomarine.Text_Areas) as a widget: it is placed by the
--  layout, takes the focus when clicked, and is drawn, updated and given
--  events by the tree, with the tree's clipboard. It is drawn again when
--  anything it shows changes, including its document, which the
--  application may change.
--
--  As a field it is white, outlined; with the focus, the outline is the
--  theme's focus colour, and thicker. It can say that what is in it will
--  not do (outlined in the danger colour), be turned off (tinted, faint,
--  and taking nothing), show a hint while it is empty, and an icon before
--  a single line.
--
--  A text area for more than one line, that can be edited, may have a
--  toolbar (Set_Toolbar) in a band at the top of it, set apart from the
--  text, which is below. In sections, divided, from the left: buttons for Bold,
--  Italic, Underline and Strikethrough; for bulleted and numbered lists,
--  a quotation, and less and more indent (see Pomarine.Text_Areas.Block);
--  and the font: the family and size (in points) of the text selected (of
--  what is typed, if none is), and the style of the paragraphs the selection
--  touches (Normal, Heading 1, 2 or 3), each chosen from a menu. Family and
--  size may change within a paragraph; the style is a paragraph's own. When it is too narrow for all, the sections
--  at the right go first.
--  Clicking one does not take the focus from the text. It has none to begin
--  with.
--
--  Declare it after the renderer it is drawn to, and after the document
--  it shows.

package Pomarine.Widgets.Editors is

   type Editor is new Widget and Listener with private;

   procedure Configure (Item : in out Editor; Family : String; Size : Float; Measure : Float; Spacing : Float := 0.0)
   with Post => Is_Configured (Item);
   --  As Pomarine.Text_Areas.Configure. Do it before the layout.

   function Is_Configured (Item : Editor) return Boolean;

   subtype Shared_Access is Pomarine.Text_Areas.Shared_Access;

   procedure Set_Shared (Item : in out Editor; Shared : not null Shared_Access);
   --  Direct Item's text area to share font registry and glyph atlas.

   procedure Attach (Item : in out Editor; Doc : not null Texts.Documents.Document_Access)
   with Pre => Is_Configured (Item), Post => Has_Document (Item);
   --  Show Doc: as Pomarine.Text_Areas.Attach.

   function Has_Document (Item : Editor) return Boolean;

   function Document (Item : Editor) return not null access constant Texts.Documents.Document
   with Pre => Has_Document (Item);
   --  Read the attached document without exposing the mutable text area.

   procedure Set_Toolbar (Item : in out Editor; To : Boolean := True);
   --  Give it the toolbar (or not), when it is for more than one line
   --  and not read only; Content_Height of its text area allows for it.

   function Has_Toolbar (Item : Editor) return Boolean;

   type Edit_Action is (Bulleted, Numbered, Quoted, Outdent, Indent, Link);
   --  The toolbar's editing buttons. Link is Begin_Link.

   procedure Set_Edit_Icon (Item : in out Editor; Action : Edit_Action; To : Pomarine.Icons.Icon);
   --  Show To on the button, in place of its text, where the tree has icons.

   Family_Capacity : constant := 64;

   procedure Set_Font (Item : in out Editor; Family : String; Size : Float)
   with Pre => Is_Configured (Item) and then Family'Length in 1 .. Family_Capacity and then Size > 0.0;
   --  Set the font of the text that has no size or family of its own, in
   --  points before Zoom: it is the font of the editor to begin with, and
   --  what the toolbar's controls show for such text.

   function Font_Family (Item : Editor) return String
   with Pre => Is_Configured (Item);

   function Font_Size (Item : Editor) return Float
   with Pre => Is_Configured (Item);

   Tool_Capacity : constant := 8;
   --  Of the buttons the application may add after the style buttons.

   function Tool_Count (Item : Editor) return Natural;

   procedure Add_Tool
     (Item : in out Editor; Label : String; Key : Character := ASCII.NUL; Needs_Selection : Boolean := False)
   with
     Pre =>
       Tool_Count (Item) < Tool_Capacity
       and then Label'Length > 0
       and then (Key = ASCII.NUL or else (Key in 'a' .. 'z' and then Key /= 'k'));
   --  Give the toolbar a button, after a divider, with this label, in the
   --  order added; none to begin with. Its click, or Command and Key while
   --  the text has the focus, is heard with Callbacks.On_Tool, with its number, from 1.
   --  K is Begin_Link's. Hovering it shows its label and key. With Needs_Selection it is off
   --  while nothing is selected, and its key does nothing.

   procedure Begin_Version (Item : in out Editor)
   with Pre => Has_Document (Item);
   --  Start writing another version of the selected text (which must be in
   --  one paragraph; if it touches a text that has versions, that text is
   --  what is selected). The text goes, to leave the caret where it began,
   --  and what is typed there (a line break is not typed: Return accepts)
   --  is the new version. A tick and a cross by the caret, Return and
   --  Escape, accept it or give it up: given up, the text is as it was.
   --  Nothing is done if there is no such selection.

   function Is_Writing_Version (Item : Editor) return Boolean;

   procedure Finish_Version (Item : in out Editor; Keep : Boolean)
   with Pre => Is_Writing_Version (Item);
   --  Accept what was typed (not blank) as another version, or, if not
   --  Keep, give it up.

   --  A text that has versions is marked in a neutral grey. Clicking it
   --  shows a bar with its number of versions and buttons to go to the
   --  one before and the one after, round the end; so do the left and
   --  right arrow keys, when the bar is shown or the pointer is over the
   --  text.

   --  Text that links to an address is underlined in the accent colour.
   --  Command-clicking a link is heard with Callbacks.On_Follow: the application opens
   --  Followed. The pointer is a hand over a link while Command is held.

   procedure Begin_Link (Item : in out Editor)
   with Pre => Has_Document (Item);
   --  Ask for the address the selected text is to link to, by a bubble by
   --  the selection (the toolbar's Link button, or Command+K, does this):
   --  a field for the address, with its tick and cross, or Return and
   --  Escape, to accept it or give it up. It is prefilled with the address
   --  the text links to now; accepted blank, that link is taken away.
   --  A tick is off while what is in the field is not an address (see
   --  Pomarine.Text_Areas.Is_Address; one with no scheme, as example.org,
   --  is made https://example.org). Nothing is done if nothing is selected,
   --  or the text is read only or of one line.

   --  The bubble may also offer addresses to choose from, as of the
   --  application's sources: a list below the field, whose choice makes the
   --  link at once. They are what the application has added since the
   --  bubble was begun: Begin_Link forgets them and says it (Callbacks.On_Ask_Link), the
   --  application answers with Add_Link_Choice, and the list is shown once
   --  it has any.

   procedure Clear_Link_Choices (Item : in out Editor);

   procedure Add_Link_Choice (Item : in out Editor; Title, Address : String)
   with Pre => Pomarine.Text_Areas.Is_Address (Address);
   --  Offer Address, listed as Title (as Address, if Title is blank).

   function Link_Choice_Count (Item : Editor) return Natural;

   procedure Choose_Link (Item : in out Editor; Which : Positive)
   with Pre => Is_Linking (Item) and then Which <= Link_Choice_Count (Item);
   --  Make the selected text a link to the Which'th offered, as choosing it from the list does.

   function Is_Linking (Item : Editor) return Boolean;

   function Link_Address (Item : Editor) return String
   with Pre => Is_Linking (Item);
   --  What is in the field now.

   procedure Set_Link_Address (Item : in out Editor; To : String)
   with Pre => Is_Linking (Item);
   --  Put To in the field, as if typed.

   procedure Finish_Link (Item : in out Editor; Keep : Boolean)
   with Pre => Is_Linking (Item), Post => not Is_Linking (Item);
   --  Make the selected text a link to what is in the field, if Keep and it
   --  is an address (or blank, to take the link away); if not, leave it as
   --  it was.

   function Followed (Item : Editor) return String;
   --  The address of the link last Command-clicked.

   procedure Set_Indent (Item : in out Editor; Points : Float)
   with Pre => Points >= 0.0;
   --  As Pomarine.Text_Areas.Set_Indent.

   procedure Set_Zoom (Item : in out Editor; To : Float)
   with Pre => To > 0.0;
   --  Make the text Zoom times its size.

   procedure Set_Paper (Item : in out Editor; To : Themes.Slot);
   --  Draw on To, not white.

   procedure Set_Borderless (Item : in out Editor; To : Boolean);
   --  Draw no outline of its own at rest, as when it is in a box that has
   --  one (the focus's outline is still drawn).

   function Zoom (Item : Editor) return Float;

   procedure Set_Invalid (Item : in out Editor; To : Boolean);
   --  Outline it in the danger colour, as of what will not do, until it
   --  is said to be valid again. The focus's outline is over it.

   function Is_Invalid (Item : Editor) return Boolean;

   procedure Set_Enabled (Item : in out Editor; To : Boolean);
   --  Turn it on, or off: off, it is tinted, its text faint, and it takes
   --  no events nor the focus. It is on to begin with.

   function Is_Enabled (Item : Editor) return Boolean;

   Hint_Capacity : constant := 32;

   procedure Set_Placeholder (Item : in out Editor; Text : String)
   with Pre => Text'Length <= Hint_Capacity;
   --  Show Text, faint, where its text begins, while it has none: a hint
   --  of what to put in it. None to begin with.

   procedure Set_Icon (Item : in out Editor; To : Pomarine.Icons.Icon)
   with Pre => Is_Configured (Item) and then Pomarine.Text_Areas.Is_Single_Line (Area (Item).all);
   --  Show the icon, faint, before its single line, leaving room for it.

   procedure Clear_Icon (Item : in out Editor);
   --  Show none, and leave no room for it.

   function Is_Focused (Item : Editor) return Boolean;

   procedure Caret_Box (Item : in out Editor; X, Y, Width, Height : out Float)
   with Pre => Has_Document (Item);
   --  Where the caret is drawn, in pixels: as Pomarine.Text_Areas.Caret_Box.

   function Search_Count (Item : Editor) return Natural;
   function Search_Current (Item : Editor) return Natural;

   function Can_Edit (Item : Editor) return Boolean;
   --  A document is attached, writable, and outside input-method composition.

   function Area (Item : in out Editor) return not null access Pomarine.Text_Areas.Text_Area;
   function Highlight_Count (Item : Editor) return Natural;
   --  The text area, to move the caret and so on. Whatever it does that
   --  changes how it looks, it does not say: say with Invalidate.

   overriding
   procedure Placed (Item : in out Editor; Left, Top, Width, Height : Float);

   overriding
   procedure Draw (Item : in out Editor; Target : SDL3.Painters.Painter'Class; Colors : Themes.Theme);

   overriding
   procedure Hover_Changed (Item : in out Editor; Hovered : Boolean);

   overriding
   procedure Handle (Item : in out Editor; Event : Pomarine.Events.Event; Handled : out Boolean);

   overriding
   procedure Update (Item : in out Editor; Now : Pomarine.Events.Milliseconds);

   overriding
   function Until_Update (Item : Editor) return Integer;

   overriding
   function Is_Focusable (Item : Editor) return Boolean;

   overriding
   function Cursor (Item : Editor) return SDL3.Cursors.Kind;
   --  The I-beam, while it can be edited.

   overriding
   procedure Focus_Changed (Item : in out Editor; Focused : Boolean);

   overriding
   procedure Describe (Item : Editor; Facts : in out Semantics.Description);
   overriding
   procedure Perform (Item : in out Editor; Request : Semantics.Request; Done : out Boolean);

   overriding
   function Part_Count (Item : Editor) return Natural;

   overriding
   function Part_Number (Item : Editor; Index : Positive) return Positive;

   overriding
   procedure Describe_Part
     (Item : Editor; Part : Positive; Facts : in out Semantics.Description; Bounds : out Semantics.Rectangle);

   overriding
   procedure Command_State_Changed (Item : in out Editor; State : Command_State);

   overriding
   procedure Handle_Event (Self : in out Editor; Source : in out Widget'Class; Event : Widget_Event);
   --  A click on a button of the toolbar.

   overriding
   procedure Handle_Command (Item : in out Editor; Tag : Integer; Done : out Boolean);

private

   package Choice_Lists is new
     Ada.Containers.Vectors (Positive, Ada.Strings.Unbounded.Unbounded_String, "=" => Ada.Strings.Unbounded."=");

   type Link_Input;
   type Link_Input_Access is access Link_Input;
   --  The bubble's field, and the document in it: made when it is first
   --  wanted (an editor holds one, and an editor cannot hold itself).

   type Format_Buttons is array (Texts.Documents.Format) of Pomarine.Widgets.Buttons.Button;

   subtype Tool_Number is Positive range 1 .. Tool_Capacity;

   type Tool_Buttons is array (Tool_Number) of Pomarine.Widgets.Buttons.Button;

   type Tool_Keys is array (Tool_Number) of Character;

   type Tool_Flags is array (Tool_Number) of Boolean;

   type Edit_Buttons is array (Edit_Action) of Pomarine.Widgets.Buttons.Button;

   type Choice is (Nothing, Pick_Family, Pick_Size, Pick_Style, Pick_Source);
   --  Which of the font controls has its menu open.

   type Editor is new Widget and Listener with record
      Text                            : aliased Pomarine.Text_Areas.Text_Area;
      Tool_Hook                       : Posted_Hook;
      Follow_Hook                     : Posted_Hook;
      Link_Hook                       : Posted_Hook;
      --  What the application has had it do when a tool is used, a link
      --  is followed, or an address is asked for (see Callbacks).
      Toolbar                         : Format_Buttons;
      --  Added to the tree when first wanted; shown while the text area
      --  has a toolbar.
      Toolbar_Shown                   : Boolean := False;
      Tools                           : Tool_Buttons;
      Keys                            : Tool_Keys := [others => ASCII.NUL];
      Selective                       : Tool_Flags := [others => False];
      Tool_Total                      : Natural range 0 .. Tool_Capacity := 0;
      --  The application's buttons, after a divider at the right of the
      --  style buttons. Hovering one shows Tip, below it.
      Editing                         : Edit_Buttons;
      Family_Box, Size_Box, Style_Box : Pomarine.Widgets.Selects.Select_Field;
      Chooser                         : Pomarine.Widgets.Menus.Menu;
      Choosing                        : Choice := Nothing;
      Face                            : String (1 .. Family_Capacity) := [others => ' '];
      Face_Length                     : Natural range 0 .. Family_Capacity := 0;
      Points                          : Float := 0.0;
      Column, Between                 : Float := 0.0;
      --  The font as set; and the measure and spacing it was configured with.
      Writing                         : Boolean := False;
      Writing_State                   : Natural := 0;
      --  The document's state before the text went, to go back to.
      Target_From, Target_To          : Texts.Position := (1, 1);
      Typed_From, Typed_To            : Texts.Position := (1, 1);
      --  What was selected, and where what is typed is now.
      Writing_Seen                    : Texts.Documents.Version := 0;
      Confirm                         : Pomarine.Widgets.Panels.Panel;
      Accept_Button, Cancel_Button    : Pomarine.Widgets.Buttons.Button;
      Confirm_Left, Confirm_Top       : Integer := -1;
      Cycle_Left, Cycle_Top           : Integer := -1;
      --  Where the bubbles were put, so as not to ask for a layout when they have not moved.
      Cycle                           : Pomarine.Widgets.Panels.Panel;
      Back_Button, Next_Button        : Pomarine.Widgets.Buttons.Button;
      Cycle_Count                     : Pomarine.Widgets.Labels.Label;
      Cycle_Open                      : Boolean := False;
      Cycle_From                      : Texts.Position := (1, 1);
      Hovering                        : Boolean := False;
      Hover_From                      : Texts.Position := (1, 1);
      Cycle_Target                    : Texts.Position := (1, 1);
      Tip                             : Pomarine.Widgets.Tooltips.Tooltip;
      Tip_Shown                       : Boolean := False;
      Tip_For                         : Tool_Number := 1;
      Shared                          : Shared_Access := null;
      Link_Owner                      : access Editor := null;
      --  Of the field in a link bubble, the editor it is for.
      Link_Box                        : Pomarine.Widgets.Panels.Panel;
      Link_Accept, Link_Cancel        : Pomarine.Widgets.Buttons.Button;
      Link_Parts                      : Link_Input_Access;
      Link_Sources                    : Pomarine.Widgets.Selects.Select_Field;
      --  Added to the bubble when it first has addresses to choose from.
      Link_Titles, Link_Addresses     : Choice_Lists.Vector;
      Link_Tall                       : Boolean := False;
      --  Whether the bubble is tall enough for the list.
      Linking                         : Boolean := False;
      Link_Had                        : Boolean := False;
      --  Whether the text already links to an address.
      Link_From, Link_To              : Texts.Position := (1, 1);
      Link_Left, Link_Top             : Integer := -1;
      Followed_To                     : Ada.Strings.Unbounded.Unbounded_String;
      Over_Link                       : Boolean := False;
      --  Whether the pointer was last over a link.
      --  The address of the link last Command-clicked.
      Pointer_In_Text                 : Boolean := True;
      Toolbar_On                      : Boolean := False;
      Zoomed                          : Float := 1.0;
      Has_Paper                       : Boolean := False;
      Paper                           : Themes.Slot := Themes.Page;
      Invalid                         : Boolean := False;
      Borderless                      : Boolean := False;
      Enabled                         : Boolean := True;
      Hint                            : String (1 .. Hint_Capacity) := [others => ' '];
      Hint_Length                     : Natural range 0 .. Hint_Capacity := 0;
      Iconed                          : Boolean := False;
      Which                           : Pomarine.Icons.Icon := Pomarine.Icons.Icon'First;
      Shown                           : Texts.Documents.Version := 0;
      Shown_Serial                    : Natural := 0;
      Told_Caret, Told_Mark           : Texts.Position;
      --  Where the caret and the other end of the selection were when an
      --  assistive technology was last told, to tell it when they move.
      --  Of the document, as of the last time it was drawn or seen to be
      --  changed.
   end record;

   type Link_Input is limited record
      Doc   : aliased Texts.Documents.Document;
      Field : aliased Editor;
   end record;

end Pomarine.Widgets.Editors;
