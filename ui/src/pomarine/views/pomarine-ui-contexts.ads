with Pomarine.Widgets.Frames;
with Pomarine.Widgets.Sliders;
with Ada.Finalization;
with Pomarine.Line_Texts;
with Pomarine.Models;
with Pomarine.Themes;
with Pomarine.View_Models;
with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Checks;
with Pomarine.Widgets.Editors;
with Pomarine.Widgets.Labels;
with Pomarine.Widgets.Lists;
with Pomarine.Widgets.Text_Fields;
with Texts.Documents;

--  Controls declared together with what ties them to a view-model.
--
--  An instance is for one kind of model, and must be instantiated in a
--  package (a library-level one): it allocates in the arenas, which the
--  compiler allows only from there.
--
--     package Todo_UI is new Pomarine.UI.Contexts (Todo_VM.Commands, Todo_VM.Model);
--
--  A property says how to read and write the model, and is made of the model's own subprograms (see
--  Properties from the model's own subprograms below), in one line:
--
--     Task_Summary : constant Todo_UI.Text_Property := Todo_UI.Showing (Todo_VM.Summary'Access);
--
--  A Context is the view, the model and the scope that controls are made in.
--  Bind gives the context of the view's root scope; a component declares a Component,
--  which is a Context of a scope of its own, that stays if the component
--  succeeds (Commit) and is thrown away, with every control and binding in it,
--  if it does not:
--
--     function Task_Actions (Parent : Todo_UI.Context'Class) return UI.Layout is
--       (UI.Row ([Parent.Label (Task_Summary, Grow => 1.0),
--                 Parent.Button ("Done", Toggle_Chosen, Width => 70.0)], Gap => 8.0));
--
--  A context is limited and borrows (a pointer to the model, the view by
--  number): it cannot be kept in anything but a limited object, and what it
--  makes does not need it once made. If the view is gone, using it raises
--  Stale_Handle; if the model is gone, nothing helps (see Pomarine.UI).
--
--  The accessibility rules of Ada could not carry this further: a context with
--  access discriminants cannot be made for a nested component (the discriminant
--  of one object cannot give the discriminant of another), so a context holds
--  named access values of library-level types, made once, in Bind.
generic
   with package Commands is new Pomarine.View_Models.Command_Models (<>);
   type Model is limited new Commands.Model with private;
package Pomarine.UI.Contexts is

   package VM renames Pomarine.View_Models;
   package Buttons renames Pomarine.Widgets.Buttons;

   --  Properties: how the model is read and written, made of its own subprograms (below)

   type Text_Property is private;
   type Count_Property is private;
   type Rows_Property is private;
   type Choice_Property is private;
   type Flag_Property is private;
   type Fraction_Property is private;
   type Action_Property is private;

   function Is_Writable (Item : Fraction_Property) return Boolean;

   --  Properties from the model's own subprograms
   --
   --  How a model is read and written is said with its subprograms themselves, in one line, wherever a constant
   --  can be declared (at library level: the subprograms must be, as 'Access wants):
   --
   --     Task_Draft : constant Todo_UI.Text_Property :=
   --       Todo_UI.Editing (Todo_VM.Draft'Access, Todo_VM.Set_Draft'Access);
   --
   --  The view keeps what it needs in its own arena. Changes says what a text or a choice watches to see it was
   --  changed; none, the model as a whole.

   type Text_Getter is access function (Item : Model) return String;
   type Text_Each_Getter is access function (Item : Model; Index : Positive) return String;
   type Text_Setter is access procedure (Item : in out Model; Value : String);
   type Flag_Getter is access function (Item : Model) return Boolean;
   type Flag_Each_Getter is access function (Item : Model; Index : Positive) return Boolean;
   type Flag_Setter is access procedure (Item : in out Model; Value : Boolean);
   type Fraction_Getter is access function (Item : Model) return Float;
   type Fraction_Setter is access procedure (Item : in out Model; Value : Float);
   type Count_Getter is access function (Item : Model) return Natural;
   type Rows_Getter is access function (Item : in out Model)
     return not null access Pomarine.Models.List_Model'Class;
   type Choice_Setter is access procedure (Item : in out Model; Id : Natural);
   type Action_Performer is access procedure (Item : in out Model);
   type Version_Getter is access function (Item : Model) return VM.Version_Number;

   function Showing (Get : not null Text_Getter; Changes : Version_Getter := null) return Text_Property;
   --  A text to show, never written.
   function Showing (Get : not null Text_Each_Getter) return Text_Property;
   --  A text to show for each of many (a card of a list), whole version, each turn.
   function Editing
     (Get : not null Text_Getter; Set : not null Text_Setter; Changes : Version_Getter := null) return Text_Property;
   --  A text to show and to be written by what the person types (as Edit_Text).

   function Showing (Get : not null Flag_Getter) return Flag_Property;
   function Showing (Get : not null Flag_Each_Getter) return Flag_Property;
   function Editing (Get : not null Flag_Getter; Set : not null Flag_Setter) return Flag_Property;

   generic
      type Choice is (<>);
      with function Get (Item : Model) return Choice;
   package Choosing_Among is
      function Is_Value (Value : Choice) return Flag_Property;
      --  True while the model's enumeration is Value, for one option of a radio group:
      --     Theme : package is new Todo_UI.Choosing_Among (Themes, Todo_VM.Theme);
      --     Todo_UI.Radio ("Dark", Theme.Is_Value (Dark), ...)
   end Choosing_Among;

   function Showing (Get : not null Fraction_Getter) return Fraction_Property;
   function Editing (Get : not null Fraction_Getter; Set : not null Fraction_Setter) return Fraction_Property;

   function Counting (Get : not null Count_Getter) return Count_Property;
   --  A number, to see whether it grew (as Counter).

   function Listing (Get : not null Rows_Getter) return Rows_Property;
   --  The rows a list shows, borrowed from the model (as Row_Source).

   function Choosing
     (Get : not null Count_Getter; Set : not null Choice_Setter; Changes : Version_Getter := null)
      return Choice_Property;
   --  The id of the chosen row, and how a choice is made (as Choice).

   function Doing (Allowed : not null Flag_Getter; Perform : not null Action_Performer) return Action_Property;
   --  A command that is no enumeration's (as Command_Action).

   --  Contexts

   type Context is new Ada.Finalization.Limited_Controlled with private;

   function Bind
     (Screen : in out Pomarine.UI.View; Data : not null access Model) return Context'Class;
   --  The context of the view's own scope (class-wide, since a component is a
   --  context too). The model must be there as long as the view is used (see
   --  Pomarine.UI).

   function Scope_Of (Item : Context) return Pomarine.UI.Scope_Ref;

   function Is_Open (Item : Context) return Boolean;
   --  Whether its scope still takes controls.

   type Replacement is (Caret_At_End, Caret_At_Start, Caret_Kept);
   --  Where the caret goes when the model gives a field a text other than the field's: the whole
   --  text is replaced (the undo history with it), and the caret is put at the end, at the start,
   --  or, if it can be, where it was.

   function Is_Writable (Item : Text_Property) return Boolean;

   function Label
     (Self  : Context;
      Text  : Text_Property;
      Index : Natural := 0;
      Style : Pomarine.Line_Texts.Style := Pomarine.Line_Texts.Regular;
      Ink   : Pomarine.Themes.Slot := 0) return Pomarine.UI.Label_Handle;
   --  A label of the model's text, in Style and in Ink (a slot of 0 is the theme's foreground).

   function Label
     (Self    : Context;
      Caption : String;
      Style   : Pomarine.Line_Texts.Style := Pomarine.Line_Texts.Regular;
      Ink     : Pomarine.Themes.Slot := 0) return Pomarine.UI.Label_Handle;
   --  A label of a text that is no model's.

   function Button
     (Self    : Context;
      Caption : String;
      Command : Commands.Command;
      Look    : Pomarine.Widgets.Buttons.Kind := Pomarine.Widgets.Buttons.Normal;
      Index   : Natural := 0;
      Focusable : Boolean := False) return Pomarine.UI.Button_Handle;
   --  A button that does Command when it is clicked, if the model can, and is turned
   --  on and off as the model says.

   function Button
     (Self    : Context;
      Caption : String;
      Action  : Action_Property;
      Look    : Pomarine.Widgets.Buttons.Kind := Pomarine.Widgets.Buttons.Normal;
      Index   : Natural := 0) return Pomarine.UI.Button_Handle;
   --  As above, for a command that is no enumeration's (Action).

   function Button
     (Self    : Context;
      Look    : Pomarine.Widgets.Buttons.Settings;
      Command : Commands.Command;
      Index   : Natural := 0;
      Reflect : Boolean := True) return Pomarine.UI.Button_Handle;
   --  As above, a button as Look says in every way (an icon, a shape, a caption). Not Reflect: the button
   --  does the command, but is not turned on and off as the model says.

   function Grip
     (Self    : Context;
      Look    : Pomarine.UI.Grip_Look;
      Command : Commands.Command;
      Index   : Natural := 0;
      Name    : String := "") return Pomarine.UI.Grip_Handle;
   --  A box that does Command when it is clicked (Hold puts what is in it), as a card that is opened. It is
   --  not turned on and off as the model says.

   function Plain_Grip (Self : Context; Look : Pomarine.UI.Grip_Look) return Pomarine.UI.Grip_Handle;
   --  A grip the view places but does not hear: the application hooks what it wants (Click, Double_Click).

   function Plain_Button
     (Self : Context; Look : Pomarine.Widgets.Buttons.Settings) return Pomarine.UI.Button_Handle;
   --  A button the view places but does not hear and the model knows nothing of: the application hooks its
   --  Click (Pomarine.Widgets.Callbacks) on Widget_Of.

   function Text_Field
     (Self        : Context;
      Text        : Text_Property;
      Placeholder : String := "";
      Name        : String := "";
      Replacing   : Replacement := Caret_At_End;
      Index       : Natural := 0) return Pomarine.UI.Field_Handle
     with Pre => Is_Writable (Text);

   function Text_Field
     (Self        : Context;
      Text        : Text_Property;
      Submit      : Commands.Command;
      Placeholder : String := "";
      Name        : String := "";
      Replacing   : Replacement := Caret_At_End;
      Index       : Natural := 0) return Pomarine.UI.Field_Handle
     with Pre => Is_Writable (Text);

   function Text_Field
     (Self        : Context;
      Text        : Text_Property;
      Submit      : Action_Property;
      Placeholder : String := "";
      Name        : String := "";
      Replacing   : Replacement := Caret_At_End;
      Index       : Natural := 0) return Pomarine.UI.Field_Handle
     with Pre => Is_Writable (Text);
   --  A field that shows the model's text and gives it what is typed, and, with Submit,
   --  does the command when Return is pressed (the field stays typeable when it cannot).
   --  Name is what an assistive technology (and a test) calls it; none, if not said.

   function Check
     (Self    : Context;
      Caption : String;
      Checked : Flag_Property;
      Command : Commands.Command;
      Form    : Pomarine.Widgets.Checks.Kind := Pomarine.Widgets.Checks.Box;
      Index   : Natural := 0;
      Name    : String := "") return Pomarine.UI.Check_Handle;
   --  Index: of which of many it is, for the command and for the flag.
   --  A box (or, with Form Radio, a radio) shown ticked as Checked says. A click does Command, if
   --  the model can; what the model makes of it, Checked says back.

   function Check
     (Self    : Context;
      Caption : String;
      Checked : Flag_Property;
      Form    : Pomarine.Widgets.Checks.Kind := Pomarine.Widgets.Checks.Box;
      Name    : String := "") return Pomarine.UI.Check_Handle
     with Pre => Is_Settable (Checked);
   --  A box that is ticked as Checked says and gives the model what the person ticks (Edit_Flag).

   function Is_Settable (Item : Flag_Property) return Boolean;

   function Switch
     (Self    : Context;
      Caption : String;
      On      : Flag_Property;
      Command : Commands.Command;
      Index   : Natural := 0;
      Name    : String := "") return Pomarine.UI.Switch_Handle;
   --  As Check, a switch.

   function Progress (Self : Context; Done : Fraction_Property) return Pomarine.UI.Progress_Handle;

   procedure Show_When
     (Self : Context; Target : Pomarine.UI.Control_Ref; Shown : Flag_Property; Index : Natural := 0);

   procedure Enabled_When
     (Self : Context; Target : Pomarine.UI.Button_Handle; Allowed : Flag_Property; Index : Natural := 0);
   --  Explicit availability for an embedded host whose validator does not route this view's tags.

   procedure Selected_When
     (Self : Context; Target : Pomarine.UI.Button_Handle; Selected : Flag_Property; Index : Natural := 0);
   --  The button's pressed appearance follows the model; this does not change its command.

   procedure Focus_When
     (Self : Context; Target : Pomarine.UI.Focus_Target; Raised : Flag_Property; Index : Natural := 0);
   --  Give the control the focus, a field with its text selected, when Raised turns true: declare it after
   --  what shows the control, so that it is shown when it is given.

   procedure Show_When
     (Self : Context; Target : Pomarine.UI.Layout; Shown : Flag_Property; Index : Natural := 0);
   --  As above, for a Row, Column or Scroll: its panel, with all it holds.
   --  The control is in the layout while Shown is true, and out of it (it takes no room) when not.

   function List
     (Self      : Context;
      Rows      : Rows_Property;
      Selection : Choice_Property;
      Name      : String := "") return Pomarine.UI.List_Handle;
   --  A list of the model's rows (the existing model-backed rows) and the choice of one of them.

   --  Controls placed in one step
   --
   --  Each is the control of the same name above together with the Place of it, so that a component is the
   --  expression of its layout and a handle is kept only for what is wanted again later:
   --
   --     UI.Row ([Bound.Label (Task_Summary, Grow => 1.0),
   --              Bound.Button ("Done", Toggle_Chosen, Width => 70.0)], Gap => 8.0)
   --
   --  Grow, Shrink, Width, Height, Margin and Align are those of Pomarine.UI.Place. Tooltip and Name (what an
   --  assistive technology and a test call it) are said of the widget when they are not empty. The order in
   --  which the controls of an expression are made is not defined, and does not matter: the tab key goes by
   --  where they are placed.

   function Label
     (Self     : Context;
      Text     : Text_Property;
      Index    : Natural := 0;
      Centered : Boolean := False;
      Style    : Pomarine.Line_Texts.Style := Pomarine.Line_Texts.Regular;
      Ink      : Pomarine.Themes.Slot := 0;
      Tooltip  : String := "";
      Grow     : Pomarine.UI.Layouts.Weight := Pomarine.UI.Layouts.Unchanged;
      Shrink   : Pomarine.UI.Layouts.Weight := Pomarine.UI.Layouts.Unchanged;
      Width    : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Height   : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Margin   : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Align    : Pomarine.UI.Align_Kind := Pomarine.UI.Layouts.As_Is) return Pomarine.UI.Layout;

   function Label
     (Self     : Context;
      Caption  : String;
      Centered : Boolean := False;
      Style    : Pomarine.Line_Texts.Style := Pomarine.Line_Texts.Regular;
      Ink      : Pomarine.Themes.Slot := 0;
      Tooltip  : String := "";
      Grow     : Pomarine.UI.Layouts.Weight := Pomarine.UI.Layouts.Unchanged;
      Shrink   : Pomarine.UI.Layouts.Weight := Pomarine.UI.Layouts.Unchanged;
      Width    : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Height   : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Margin   : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Align    : Pomarine.UI.Align_Kind := Pomarine.UI.Layouts.As_Is) return Pomarine.UI.Layout;

   function Button
     (Self      : Context;
      Caption   : String;
      Command   : Commands.Command;
      Look      : Pomarine.Widgets.Buttons.Kind := Pomarine.Widgets.Buttons.Normal;
      Index     : Natural := 0;
      Focusable : Boolean := False;
      Tooltip   : String := "";
      Name      : String := "";
      Grow      : Pomarine.UI.Layouts.Weight := Pomarine.UI.Layouts.Unchanged;
      Shrink    : Pomarine.UI.Layouts.Weight := Pomarine.UI.Layouts.Unchanged;
      Width     : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Height    : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Margin    : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Align     : Pomarine.UI.Align_Kind := Pomarine.UI.Layouts.As_Is) return Pomarine.UI.Layout;

   function Button
     (Self    : Context;
      Caption : String;
      Action  : Action_Property;
      Look    : Pomarine.Widgets.Buttons.Kind := Pomarine.Widgets.Buttons.Normal;
      Index   : Natural := 0;
      Tooltip : String := "";
      Name    : String := "";
      Grow    : Pomarine.UI.Layouts.Weight := Pomarine.UI.Layouts.Unchanged;
      Shrink  : Pomarine.UI.Layouts.Weight := Pomarine.UI.Layouts.Unchanged;
      Width   : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Height  : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Margin  : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Align   : Pomarine.UI.Align_Kind := Pomarine.UI.Layouts.As_Is) return Pomarine.UI.Layout;

   function Text_Field
     (Self            : Context;
      Text            : Text_Property;
      Submit          : Commands.Command;
      Placeholder     : String := "";
      Name            : String := "";
      Focus_Initially : Boolean := False;
      Replacing       : Replacement := Caret_At_End;
      Index           : Natural := 0;
      Grow            : Pomarine.UI.Layouts.Weight := Pomarine.UI.Layouts.Unchanged;
      Shrink          : Pomarine.UI.Layouts.Weight := Pomarine.UI.Layouts.Unchanged;
      Width           : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Height          : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Margin          : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Align           : Pomarine.UI.Align_Kind := Pomarine.UI.Layouts.As_Is) return Pomarine.UI.Layout
     with Pre => Is_Writable (Text);
   --  With Focus_Initially the field has the focus when the screen is mounted.

   function Text_Field
     (Self            : Context;
      Text            : Text_Property;
      Placeholder     : String := "";
      Name            : String := "";
      Focus_Initially : Boolean := False;
      Replacing       : Replacement := Caret_At_End;
      Index           : Natural := 0;
      Grow            : Pomarine.UI.Layouts.Weight := Pomarine.UI.Layouts.Unchanged;
      Shrink          : Pomarine.UI.Layouts.Weight := Pomarine.UI.Layouts.Unchanged;
      Width           : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Height          : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Margin          : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Align           : Pomarine.UI.Align_Kind := Pomarine.UI.Layouts.As_Is) return Pomarine.UI.Layout
     with Pre => Is_Writable (Text);

   function Check
     (Self    : Context;
      Caption : String;
      Checked : Flag_Property;
      Command : Commands.Command;
      Form    : Pomarine.Widgets.Checks.Kind := Pomarine.Widgets.Checks.Box;
      Index   : Natural := 0;
      Name    : String := "";
      Grow    : Pomarine.UI.Layouts.Weight := Pomarine.UI.Layouts.Unchanged;
      Shrink  : Pomarine.UI.Layouts.Weight := Pomarine.UI.Layouts.Unchanged;
      Width   : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Height  : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Margin  : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Align   : Pomarine.UI.Align_Kind := Pomarine.UI.Layouts.As_Is) return Pomarine.UI.Layout;

   function Check
     (Self    : Context;
      Caption : String;
      Checked : Flag_Property;
      Form    : Pomarine.Widgets.Checks.Kind := Pomarine.Widgets.Checks.Box;
      Name    : String := "";
      Grow    : Pomarine.UI.Layouts.Weight := Pomarine.UI.Layouts.Unchanged;
      Shrink  : Pomarine.UI.Layouts.Weight := Pomarine.UI.Layouts.Unchanged;
      Width   : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Height  : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Margin  : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Align   : Pomarine.UI.Align_Kind := Pomarine.UI.Layouts.As_Is) return Pomarine.UI.Layout
     with Pre => Is_Settable (Checked);

   function Switch
     (Self    : Context;
      Caption : String;
      On      : Flag_Property;
      Command : Commands.Command;
      Index   : Natural := 0;
      Name    : String := "";
      Grow    : Pomarine.UI.Layouts.Weight := Pomarine.UI.Layouts.Unchanged;
      Shrink  : Pomarine.UI.Layouts.Weight := Pomarine.UI.Layouts.Unchanged;
      Width   : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Height  : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Margin  : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Align   : Pomarine.UI.Align_Kind := Pomarine.UI.Layouts.As_Is) return Pomarine.UI.Layout;

   function Progress
     (Self   : Context;
      Done   : Fraction_Property;
      Grow   : Pomarine.UI.Layouts.Weight := Pomarine.UI.Layouts.Unchanged;
      Shrink : Pomarine.UI.Layouts.Weight := Pomarine.UI.Layouts.Unchanged;
      Width  : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Height : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Margin : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Align  : Pomarine.UI.Align_Kind := Pomarine.UI.Layouts.As_Is) return Pomarine.UI.Layout;

   function List
     (Self      : Context;
      Rows      : Rows_Property;
      Selection : Choice_Property;
      Name      : String := "";
      Grow      : Pomarine.UI.Layouts.Weight := Pomarine.UI.Layouts.Unchanged;
      Shrink    : Pomarine.UI.Layouts.Weight := Pomarine.UI.Layouts.Unchanged;
      Width     : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Height    : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Margin    : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Align     : Pomarine.UI.Align_Kind := Pomarine.UI.Layouts.As_Is) return Pomarine.UI.Layout;

   function List
     (Self         : Context;
      Rows         : Rows_Property;
      Selection    : Choice_Property;
      Reveal_After : Commands.Command;
      Growth       : Count_Property;
      Name         : String := "";
      Grow         : Pomarine.UI.Layouts.Weight := Pomarine.UI.Layouts.Unchanged;
      Shrink       : Pomarine.UI.Layouts.Weight := Pomarine.UI.Layouts.Unchanged;
      Width        : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Height       : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Margin       : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Align        : Pomarine.UI.Align_Kind := Pomarine.UI.Layouts.As_Is) return Pomarine.UI.Layout;
   --  As above, and, after Reveal_After is done, if Growth has grown, the list is scrolled to its last row.

   function Borrow_Widget
     (Self     : Context;
      Existing : in out Pomarine.Widgets.Widget'Class;
      Tooltip  : String := "";
      Name     : String := "";
      Grow     : Pomarine.UI.Layouts.Weight := Pomarine.UI.Layouts.Unchanged;
      Shrink   : Pomarine.UI.Layouts.Weight := Pomarine.UI.Layouts.Unchanged;
      Width    : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Height   : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Margin   : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Align    : Pomarine.UI.Align_Kind := Pomarine.UI.Layouts.As_Is) return Pomarine.UI.Layout;
   --  A widget of any kind that the application keeps, placed (see Borrow_Widget below).

   function Borrow_Widget
     (Self     : Context;
      Existing : in out Pomarine.Widgets.Widget'Class;
      Click    : Commands.Command;
      Index    : Natural := 0;
      Tooltip  : String := "";
      Name     : String := "";
      Grow     : Pomarine.UI.Layouts.Weight := Pomarine.UI.Layouts.Unchanged;
      Shrink   : Pomarine.UI.Layouts.Weight := Pomarine.UI.Layouts.Unchanged;
      Width    : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Height   : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Margin   : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Align    : Pomarine.UI.Align_Kind := Pomarine.UI.Layouts.As_Is;
      Exact    : Boolean := False) return Pomarine.UI.Layout;
   --  As above, and a click on it does Click (with Index).

   function Borrow_Holding
     (Self     : Context;
      Existing : in out Pomarine.Widgets.Widget'Class;
      Items    : Pomarine.UI.Layout_Array;
      Click    : Commands.Command;
      Index    : Natural := 0;
      Flow     : Pomarine.UI.Layouts.Flow_Kind := Pomarine.UI.Layouts.Column;
      Gap      : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Padding  : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Align    : Pomarine.UI.Align_Kind := Pomarine.UI.Layouts.As_Is;
      Spread   : Pomarine.UI.Spread_Kind := Pomarine.UI.Layouts.As_Is) return Pomarine.UI.Layout;
   --  A widget of the application's that holds others (see Pomarine.UI.Hold), placed, with Items in it; a click
   --  on it does Click (with Index). Its own box is said with Styled.

   function Borrow_Holding
     (Self     : Context;
      Existing : in out Pomarine.Widgets.Widget'Class;
      Items    : Pomarine.UI.Layout_Array;
      Flow     : Pomarine.UI.Layouts.Flow_Kind := Pomarine.UI.Layouts.Column;
      Gap      : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Padding  : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Align    : Pomarine.UI.Align_Kind := Pomarine.UI.Layouts.As_Is;
      Spread   : Pomarine.UI.Spread_Kind := Pomarine.UI.Layouts.As_Is) return Pomarine.UI.Layout;
   --  As above, with no click.

   function Borrow_Label
     (Self     : Context;
      Existing : in out Pomarine.Widgets.Labels.Label;
      Text     : Text_Property;
      Tooltip  : String := "";
      Name     : String := "";
      Grow     : Pomarine.UI.Layouts.Weight := Pomarine.UI.Layouts.Unchanged;
      Shrink   : Pomarine.UI.Layouts.Weight := Pomarine.UI.Layouts.Unchanged;
      Width    : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Height   : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Margin   : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Align    : Pomarine.UI.Align_Kind := Pomarine.UI.Layouts.As_Is;
      Exact    : Boolean := False) return Pomarine.UI.Layout;

   function Borrow_Button
     (Self     : Context;
      Existing : in out Pomarine.Widgets.Buttons.Button;
      Command  : Commands.Command;
      Index    : Natural := 0;
      Reflect  : Boolean := True;
      Tooltip  : String := "";
      Name     : String := "";
      Grow     : Pomarine.UI.Layouts.Weight := Pomarine.UI.Layouts.Unchanged;
      Shrink   : Pomarine.UI.Layouts.Weight := Pomarine.UI.Layouts.Unchanged;
      Width    : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Height   : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Margin   : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Align    : Pomarine.UI.Align_Kind := Pomarine.UI.Layouts.As_Is;
      Exact    : Boolean := False) return Pomarine.UI.Layout;

   function Borrow_Field
     (Self      : Context;
      Existing  : in out Pomarine.Widgets.Text_Fields.Text_Field;
      Backing   : aliased in out Texts.Documents.Document;
      Text      : Text_Property;
      Replacing : Replacement := Caret_At_End;
      Tooltip   : String := "";
      Name      : String := "";
      Grow      : Pomarine.UI.Layouts.Weight := Pomarine.UI.Layouts.Unchanged;
      Shrink    : Pomarine.UI.Layouts.Weight := Pomarine.UI.Layouts.Unchanged;
      Width     : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Height    : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Margin    : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Align     : Pomarine.UI.Align_Kind := Pomarine.UI.Layouts.As_Is;
      Exact     : Boolean := False) return Pomarine.UI.Layout
     with Pre => Is_Writable (Text);

   function Borrow_Slider
     (Self     : Context;
      Existing : in out Pomarine.Widgets.Sliders.Slider;
      Value    : Fraction_Property;
      Tooltip  : String := "";
      Name     : String := "";
      Grow     : Pomarine.UI.Layouts.Weight := Pomarine.UI.Layouts.Unchanged;
      Shrink   : Pomarine.UI.Layouts.Weight := Pomarine.UI.Layouts.Unchanged;
      Width    : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Height   : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Margin   : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Align    : Pomarine.UI.Align_Kind := Pomarine.UI.Layouts.As_Is;
      Exact    : Boolean := False) return Pomarine.UI.Layout
     with Pre => Is_Writable (Value);

   function Borrow_List
     (Self      : Context;
      Existing  : in out Pomarine.Widgets.Lists.List;
      Rows      : Rows_Property;
      Selection : Choice_Property;
      Tooltip   : String := "";
      Name      : String := "";
      Grow      : Pomarine.UI.Layouts.Weight := Pomarine.UI.Layouts.Unchanged;
      Shrink    : Pomarine.UI.Layouts.Weight := Pomarine.UI.Layouts.Unchanged;
      Width     : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Height    : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Margin    : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Align     : Pomarine.UI.Align_Kind := Pomarine.UI.Layouts.As_Is;
      Exact     : Boolean := False) return Pomarine.UI.Layout;

   --  Effects of the view

   procedure Focus_Initially (Self : Context; Target : Pomarine.UI.Focus_Target);
   --  Give the focus to the control when the screen is mounted.

   procedure Reveal_After
     (Self    : Context;
      Command : Commands.Command;
      Target  : Pomarine.UI.Reveal_Target;
      Count   : Count_Property);
   --  After Command is done, if Count has grown, scroll the list to its last row.
   --  The view's, not the model's: the model knows nothing of scrolling.

   --  Controls the application already owns (migration). The view binds and places them
   --  as its own and never finalizes them; when the view goes they are taken out of the
   --  tree and are the application's again. The handler of the event the view hears (Click of a
   --  button, Submit of a field, Choose of a list) is the view's from here.

   function Borrow_Label
     (Self : Context; Existing : in out Pomarine.Widgets.Labels.Label; Text : Text_Property)
      return Pomarine.UI.Label_Handle;

   function Borrow_Button
     (Self     : Context;
      Existing : in out Pomarine.Widgets.Buttons.Button;
      Command  : Commands.Command;
      Index    : Natural := 0;
      Reflect  : Boolean := True) return Pomarine.UI.Button_Handle;

   procedure Caption_From
     (Self : Context; Target : Pomarine.UI.Button_Handle; Text : Text_Property; Index : Natural := 0);
   --  A button's caption follows Text. Works for owned and borrowed buttons; its command is unchanged.

   function Borrow_Field
     (Self      : Context;
      Existing  : in out Pomarine.Widgets.Text_Fields.Text_Field;
      Backing   : aliased in out Texts.Documents.Document;
      Text      : Text_Property;
      Replacing : Replacement := Caret_At_End) return Pomarine.UI.Field_Handle
     with Pre => Is_Writable (Text);
   --  Backing is the document the field shows (the application attached it).

   procedure On_Frame_Event
     (Self : Context; Target : in out Pomarine.Widgets.Frames.Frame; Kind : Pomarine.Widgets.Event_Kind;
      Command : Commands.Command; Index : Natural := 0);
   --  Discrete frame actions. Target must outlive the binding; movement and resizing stay in the view.

   procedure On_Event
     (Self : Context; Target : Pomarine.UI.Control_Ref; Kind : Pomarine.Widgets.Event_Kind;
      Command : Commands.Command; Index : Natural := 0; Index_From_Event : Boolean := False);
   --  Bind a discrete event on a typed control, without borrowing it again.

   procedure On_Event
     (Self : Context; Target : Pomarine.UI.Widget_Handle; Kind : Pomarine.Widgets.Event_Kind;
      Command : Commands.Command; Index : Natural := 0; Index_From_Event : Boolean := False);
   --  Route an app-owned widget event through the normal edit-before-command turn. The binding owns
   --  this event handler until its scope is destroyed; the widget's tag is left unchanged.

   type Editor_Hook is (Tool_Used, Link_Followed, Link_Asked);
   --  What an editor says that no other widget does: a tool of its toolbar was used (Add_Tool), a link was
   --  Command-clicked, it has begun to ask for a link's address.

   procedure On_Editor_Event
     (Self : Context; Target : Pomarine.UI.Widget_Handle; Hook : Editor_Hook;
      Command : Commands.Command; Index : Natural := 0; Index_From_Event : Boolean := False)
     with Pre => Hook = Tool_Used or else not Index_From_Event;
   --  Route an event of an editor the application keeps (Borrow_Widget) through the normal turn. With
   --  Index_From_Event the command's index says the tool used as well as Index (Tool_Index); otherwise it is
   --  Index. Target must be an editor and each hook of it may be bound once.

   type Canvas_Hook is (Line_Selected, Line_Deleted);
   --  What a canvas says of its lines: which is selected changed (0 for none), Backspace or Delete was pressed
   --  while one is selected.

   procedure On_Canvas_Event
     (Self : Context; Target : Pomarine.UI.Widget_Handle; Hook : Canvas_Hook;
      Command : Commands.Command; Index : Natural := 0; Index_From_Event : Boolean := False)
     with Pre => Hook = Line_Selected or else not Index_From_Event;
   --  As On_Editor_Event, of a canvas the application keeps. With Index_From_Event, of Line_Selected, the
   --  command's index is the Tag of the line selected, 0 for none.

   function Tool_Index (Index : Natural; Tool : Positive) return Natural is
     (Index * Pomarine.Widgets.Editors.Tool_Capacity + Tool)
     with Pre => Tool <= Pomarine.Widgets.Editors.Tool_Capacity;
   --  The index of a command of Tool_Used with Index_From_Event, of the editor bound with Index.

   function Editor_Of (Index : Positive) return Natural is
     ((Index - 1) / Pomarine.Widgets.Editors.Tool_Capacity);
   function Tool_Of (Index : Positive) return Positive is
     ((Index - 1) mod Pomarine.Widgets.Editors.Tool_Capacity + 1);
   --  What Tool_Index put together: the Index the editor was bound with, the tool.

   type List_Actions is array (Positive range <>) of Commands.Command;
   procedure On_List_Actions (Self : Context; Target : Pomarine.UI.Widget_Handle; Actions : List_Actions)
     with Pre => Actions'First = 1 and then Actions'Length in 1 .. Pomarine.Models.Max_Actions;
   --  Bind each numbered row action to a command, with the row as its index. Unknown actions are ignored.
   --  Target must borrow a list. For Click and Submit, On_Event with Index_From_Event uses its selected row;
   --  a list with no selection does not execute a command. Bindings detach with the control's scope.

   function Borrow_Slider
     (Self : Context; Existing : in out Pomarine.Widgets.Sliders.Slider; Value : Fraction_Property)
      return Pomarine.UI.Widget_Handle
      with Pre => Is_Writable (Value);
   --  Changes are collected before commands. Programmatic refreshes preserve an active drag.

   function Borrow_Widget
     (Self : Context; Existing : in out Pomarine.Widgets.Widget'Class) return Pomarine.UI.Widget_Handle;
   --  A widget of any kind that the application keeps (a canvas, a picture, a custom widget): the view
   --  places it and Show_When shows or hides it. The rest of it is the application's.

   function Borrow_List
     (Self      : Context;
      Existing  : in out Pomarine.Widgets.Lists.List;
      Rows      : Rows_Property;
      Selection : Choice_Property) return Pomarine.UI.List_Handle;

   --  Components

   type Component (Parent : not null access constant Context'Class) is limited new Context with private;
   --  A context of a scope of its own, under that of Parent. Declare it first in the
   --  component's declarative part; whatever raises after that, the scope and all in it go.

   procedure Commit (Item : in out Component);
   --  The component succeeded: its scope joins the parent's, and stays provisionally until
   --  the screen is mounted. Controls can no longer be made through Item.

   function Finish (Item : in out Component; Result : Pomarine.UI.Layout) return Pomarine.UI.Layout;
   --  Commit, and Result: the end of a component that is one expression, `return Bound.Finish (UI.Row (...))`.
   --  A component that needs no scope of its own to give up whole when it fails (most) makes its controls
   --  through the context it is given and has no Component: see the notes above.

private

   type Model_Ref is access all Model;

   --  How a binding reads and writes the model: the adapter of a property, made in the arena of its scope.

   type Text_Adapter is limited interface;
   function Current (Self : Text_Adapter; Item : Model; Index : Natural) return String is abstract;
   procedure Assign (Self : Text_Adapter; Item : in out Model; Value : String; Index : Natural) is abstract;
   function Stamp (Self : Text_Adapter; Item : Model; Index : Natural) return VM.Version_Number is abstract;
   function Can_Assign (Self : Text_Adapter) return Boolean is abstract;
   type Text_Adapter_Ref is access constant Text_Adapter'Class;

   type Count_Adapter is limited interface;
   function Current (Self : Count_Adapter; Item : Model) return Natural is abstract;
   type Count_Adapter_Ref is access constant Count_Adapter'Class;

   type Rows_Adapter is limited interface;
   function Rows_Of (Self : Rows_Adapter; Item : in out Model) return Pomarine.Models.Model_Access is abstract;
   type Rows_Adapter_Ref is access constant Rows_Adapter'Class;

   type Choice_Adapter is limited interface;
   function Chosen (Self : Choice_Adapter; Item : Model) return Natural is abstract;
   procedure Choose (Self : Choice_Adapter; Item : in out Model; Id : Natural) is abstract;
   function Stamp (Self : Choice_Adapter; Item : Model) return VM.Version_Number is abstract;
   type Choice_Adapter_Ref is access constant Choice_Adapter'Class;

   type Flag_Adapter is limited interface;
   function Current (Self : Flag_Adapter; Item : Model; Index : Natural) return Boolean is abstract;
   procedure Assign (Self : Flag_Adapter; Item : in out Model; Value : Boolean; Index : Natural) is abstract;
   function Can_Assign (Self : Flag_Adapter) return Boolean is abstract;
   type Flag_Adapter_Ref is access constant Flag_Adapter'Class;

   type Fraction_Adapter is limited interface;
   function Current (Self : Fraction_Adapter; Item : Model) return Float is abstract;
   procedure Assign (Self : Fraction_Adapter; Item : in out Model; Value : Float) is null;
   function Can_Assign (Self : Fraction_Adapter) return Boolean is abstract;
   type Fraction_Adapter_Ref is access constant Fraction_Adapter'Class;

   type Action_Adapter is limited interface;
   function May_Perform (Self : Action_Adapter; Item : Model) return Boolean is abstract;
   procedure Run_Action (Self : Action_Adapter; Item : in out Model) is abstract;
   type Action_Adapter_Ref is access constant Action_Adapter'Class;

   --  A property is the model's own subprograms, from which the view makes the adapter in its arena when it
   --  binds the property.

   type Text_Property is record
      Get     : Text_Getter;
      Each    : Text_Each_Getter;
      Set     : Text_Setter;
      Changes : Version_Getter;
   end record;

   type Count_Property is record
      Get     : Count_Getter;
   end record;

   type Rows_Property is record
      Get     : Rows_Getter;
   end record;

   type Choice_Property is record
      Get     : Count_Getter;
      Set     : Choice_Setter;
      Changes : Version_Getter;
   end record;

   type Flag_Property is record
      Get     : Flag_Getter;
      Each    : Flag_Each_Getter;
      Set     : Flag_Setter;
      Pick    : access function (Item : Model) return Natural;
      Want    : Natural := 0;
   end record;

   type Fraction_Property is record
      Get     : Fraction_Getter;
      Set     : Fraction_Setter;
   end record;

   function Is_Writable (Item : Fraction_Property) return Boolean is
     (Item.Set /= null);

   type Action_Property is record
      Allowed : Flag_Getter;
      Perform : Action_Performer;
   end record;

   function Is_Settable (Item : Flag_Property) return Boolean is
     (Item.Set /= null);

   function Is_Writable (Item : Text_Property) return Boolean is
     (Item.Set /= null);

   type Context is new Ada.Finalization.Limited_Controlled with record
      Number : Natural := 0;
      Data   : Model_Ref;
      Scope  : Pomarine.UI.Scope_Ref;
   end record;

   type Component (Parent : not null access constant Context'Class) is limited new Context with record
      Committed : Boolean := False;
   end record;

   overriding procedure Initialize (Item : in out Component);
   overriding procedure Finalize (Item : in out Component);

end Pomarine.UI.Contexts;
