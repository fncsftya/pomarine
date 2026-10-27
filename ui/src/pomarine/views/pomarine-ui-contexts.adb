with Pomarine.UI.Arenas;
with Pomarine.UI.Binders.Controls;
with System.Address_To_Access_Conversions;

package body Pomarine.UI.Contexts is

   package Controls renames Pomarine.UI.Binders.Controls;
   package Labels renames Pomarine.Widgets.Labels;
   package Lists renames Pomarine.Widgets.Lists;
   package Text_Fields renames Pomarine.Widgets.Text_Fields;

   package Conv is new System.Address_To_Access_Conversions (Model);

   function Model_At (Item : System.Address) return Conv.Object_Pointer renames Conv.To_Pointer;
   --  What the non-generic part (Pomarine.UI.Binders) holds of the model is its address.

   function Whole_Version (Item : Model) return VM.Version_Number
   is (Commands.Version (Commands.Model'Class (Item)));
   --  What a text or a choice watches unless it is given a version of its own.

   --  Properties of the model's own subprograms. The view makes the adapter of one in its arena, when it binds.

   function Showing (Get : not null Text_Getter; Changes : Version_Getter := null) return Text_Property
   is ((Get => Get, Changes => Changes, others => <>));

   function Showing (Get : not null Text_Each_Getter) return Text_Property
   is ((Each => Get, others => <>));

   function Editing
     (Get : not null Text_Getter; Set : not null Text_Setter; Changes : Version_Getter := null) return Text_Property
   is ((Get => Get, Set => Set, Changes => Changes, others => <>));

   function Showing (Get : not null Flag_Getter) return Flag_Property
   is ((Get => Get, others => <>));

   function Showing (Get : not null Flag_Each_Getter) return Flag_Property
   is ((Each => Get, others => <>));

   function Editing (Get : not null Flag_Getter; Set : not null Flag_Setter) return Flag_Property
   is ((Get => Get, Set => Set, others => <>));

   package body Choosing_Among is
      function Position (Item : Model) return Natural
      is (Choice'Pos (Get (Item)));

      function Is_Value (Value : Choice) return Flag_Property
      is ((Pick => Position'Access, Want => Choice'Pos (Value), others => <>));
   end Choosing_Among;

   function Showing (Get : not null Fraction_Getter) return Fraction_Property
   is ((Get => Get, others => <>));

   function Editing (Get : not null Fraction_Getter; Set : not null Fraction_Setter) return Fraction_Property
   is ((Get => Get, Set => Set));

   function Counting (Get : not null Count_Getter) return Count_Property
   is ((Get => Get));

   function Listing (Get : not null Rows_Getter) return Rows_Property
   is ((Get => Get));

   function Choosing
     (Get : not null Count_Getter; Set : not null Choice_Setter; Changes : Version_Getter := null)
      return Choice_Property
   is ((Get => Get, Set => Set, Changes => Changes));

   function Doing (Allowed : not null Flag_Getter; Perform : not null Action_Performer) return Action_Property
   is ((Allowed => Allowed, Perform => Perform));

   type Pointer_Text is new Binders.Text_Adapter with record
      Get     : Text_Getter;
      Each    : Text_Each_Getter;
      Set     : Text_Setter;
      Changes : Version_Getter;
   end record;

   overriding
   function Current (Self : Pointer_Text; Item : System.Address; Index : Natural) return String;
   overriding
   procedure Assign (Self : Pointer_Text; Item : System.Address; Value : String; Index : Natural);
   overriding
   function Stamp (Self : Pointer_Text; Item : System.Address; Index : Natural) return VM.Version_Number;
   overriding
   function Can_Assign (Self : Pointer_Text) return Boolean;

   overriding
   function Current (Self : Pointer_Text; Item : System.Address; Index : Natural) return String
   is (if Self.Each /= null
       then Self.Each (Model_At (Item).all, Positive'Max (1, Index))
       else Self.Get (Model_At (Item).all));

   overriding
   procedure Assign (Self : Pointer_Text; Item : System.Address; Value : String; Index : Natural) is
      pragma Unreferenced (Index);
   begin
      if Self.Set /= null then
         Self.Set (Model_At (Item).all, Value);
      end if;
   end Assign;

   overriding
   function Stamp (Self : Pointer_Text; Item : System.Address; Index : Natural) return VM.Version_Number is
      pragma Unreferenced (Index);
   begin
      return (if Self.Changes /= null then Self.Changes (Model_At (Item).all) else Whole_Version (Model_At (Item).all));
   end Stamp;

   overriding
   function Can_Assign (Self : Pointer_Text) return Boolean
   is (Self.Set /= null);

   type Pointer_Flag is new Binders.Flag_Adapter with record
      Get  : Flag_Getter;
      Each : Flag_Each_Getter;
      Set  : Flag_Setter;
      Pick : access function (Item : Model) return Natural;
      Want : Natural := 0;
   end record;

   overriding
   function Current (Self : Pointer_Flag; Item : System.Address; Index : Natural) return Boolean;
   overriding
   procedure Assign (Self : Pointer_Flag; Item : System.Address; Value : Boolean; Index : Natural);
   overriding
   function Can_Assign (Self : Pointer_Flag) return Boolean;

   overriding
   function Current (Self : Pointer_Flag; Item : System.Address; Index : Natural) return Boolean
   is (if Self.Pick /= null
       then Self.Pick (Model_At (Item).all) = Self.Want
       elsif Self.Each /= null
       then Self.Each (Model_At (Item).all, Positive'Max (1, Index))
       else Self.Get (Model_At (Item).all));

   overriding
   procedure Assign (Self : Pointer_Flag; Item : System.Address; Value : Boolean; Index : Natural) is
      pragma Unreferenced (Index);
   begin
      if Self.Set /= null then
         Self.Set (Model_At (Item).all, Value);
      end if;
   end Assign;

   overriding
   function Can_Assign (Self : Pointer_Flag) return Boolean
   is (Self.Set /= null);

   type Pointer_Fraction is new Binders.Fraction_Adapter with record
      Get : Fraction_Getter;
      Set : Fraction_Setter;
   end record;

   overriding
   function Current (Self : Pointer_Fraction; Item : System.Address) return Float;
   overriding
   procedure Assign (Self : Pointer_Fraction; Item : System.Address; Value : Float);
   overriding
   function Can_Assign (Self : Pointer_Fraction) return Boolean;

   overriding
   function Current (Self : Pointer_Fraction; Item : System.Address) return Float
   is (Self.Get (Model_At (Item).all));

   overriding
   procedure Assign (Self : Pointer_Fraction; Item : System.Address; Value : Float) is
   begin
      if Self.Set /= null then
         Self.Set (Model_At (Item).all, Value);
      end if;
   end Assign;

   overriding
   function Can_Assign (Self : Pointer_Fraction) return Boolean
   is (Self.Set /= null);

   type Pointer_Count is new Binders.Count_Adapter with record
      Get : Count_Getter;
   end record;

   overriding
   function Current (Self : Pointer_Count; Item : System.Address) return Natural
   is (Self.Get (Model_At (Item).all));

   type Pointer_Rows is new Binders.Rows_Adapter with record
      Get : Rows_Getter;
   end record;

   overriding
   function Rows_Of (Self : Pointer_Rows; Item : System.Address) return Pomarine.Models.Model_Access
   is (Self.Get (Model_At (Item).all).all'Unrestricted_Access);

   type Pointer_Choice is new Binders.Choice_Adapter with record
      Get     : Count_Getter;
      Set     : Choice_Setter;
      Changes : Version_Getter;
   end record;

   overriding
   function Chosen (Self : Pointer_Choice; Item : System.Address) return Natural;
   overriding
   procedure Choose (Self : Pointer_Choice; Item : System.Address; Id : Natural);
   overriding
   function Stamp (Self : Pointer_Choice; Item : System.Address) return VM.Version_Number;

   overriding
   function Chosen (Self : Pointer_Choice; Item : System.Address) return Natural
   is (Self.Get (Model_At (Item).all));

   overriding
   procedure Choose (Self : Pointer_Choice; Item : System.Address; Id : Natural) is
   begin
      Self.Set (Model_At (Item).all, Id);
   end Choose;

   overriding
   function Stamp (Self : Pointer_Choice; Item : System.Address) return VM.Version_Number
   is (if Self.Changes /= null then Self.Changes (Model_At (Item).all) else Whole_Version (Model_At (Item).all));

   type Pointer_Action is new Binders.Action_Adapter with record
      Allowed : Flag_Getter;
      Perform : Action_Performer;
   end record;

   overriding
   function May_Perform (Self : Pointer_Action; Item : System.Address) return Boolean;
   overriding
   procedure Run_Action (Self : Pointer_Action; Item : System.Address);

   overriding
   function May_Perform (Self : Pointer_Action; Item : System.Address) return Boolean
   is (Self.Allowed (Model_At (Item).all));

   overriding
   procedure Run_Action (Self : Pointer_Action; Item : System.Address) is
   begin
      Self.Perform (Model_At (Item).all);
   end Run_Action;

   type Pointer_Text_Store is access Pointer_Text;
   for Pointer_Text_Store'Storage_Pool use Pomarine.UI.Arenas.Pool;
   type Pointer_Flag_Store is access Pointer_Flag;
   for Pointer_Flag_Store'Storage_Pool use Pomarine.UI.Arenas.Pool;
   type Pointer_Fraction_Store is access Pointer_Fraction;
   for Pointer_Fraction_Store'Storage_Pool use Pomarine.UI.Arenas.Pool;
   type Pointer_Count_Store is access Pointer_Count;
   for Pointer_Count_Store'Storage_Pool use Pomarine.UI.Arenas.Pool;
   type Pointer_Rows_Store is access Pointer_Rows;
   for Pointer_Rows_Store'Storage_Pool use Pomarine.UI.Arenas.Pool;
   type Pointer_Choice_Store is access Pointer_Choice;
   for Pointer_Choice_Store'Storage_Pool use Pomarine.UI.Arenas.Pool;
   type Pointer_Action_Store is access Pointer_Action;
   for Pointer_Action_Store'Storage_Pool use Pomarine.UI.Arenas.Pool;

   --  The adapter of a property, made in the arena of the scope that binds it.

   function Adapter_Of (Self : Context'Class; Item : Text_Property) return Binders.Text_Adapter_Ref is
   begin
      pragma Assert (Item.Get /= null or else Item.Each /= null);
      declare
         Made : constant Pointer_Text_Store :=
           new (Binders.Arena (Self))
             Pointer_Text'(Get => Item.Get, Each => Item.Each, Set => Item.Set, Changes => Item.Changes);
      begin
         return Made.all'Unchecked_Access;
      end;
   end Adapter_Of;

   function Adapter_Of (Self : Context'Class; Item : Flag_Property) return Binders.Flag_Adapter_Ref is
   begin
      pragma Assert (Item.Get /= null or else Item.Each /= null or else Item.Pick /= null);
      declare
         Made : constant Pointer_Flag_Store :=
           new (Binders.Arena (Self))
             Pointer_Flag'(Get => Item.Get, Each => Item.Each, Set => Item.Set, Pick => Item.Pick, Want => Item.Want);
      begin
         return Made.all'Unchecked_Access;
      end;
   end Adapter_Of;

   function Adapter_Of (Self : Context'Class; Item : Fraction_Property) return Binders.Fraction_Adapter_Ref is
   begin
      pragma Assert (Item.Get /= null);
      declare
         Made : constant Pointer_Fraction_Store :=
           new (Binders.Arena (Self)) Pointer_Fraction'(Get => Item.Get, Set => Item.Set);
      begin
         return Made.all'Unchecked_Access;
      end;
   end Adapter_Of;

   function Adapter_Of (Self : Context'Class; Item : Count_Property) return Binders.Count_Adapter_Ref is
   begin
      pragma Assert (Item.Get /= null);
      declare
         Made : constant Pointer_Count_Store := new (Binders.Arena (Self)) Pointer_Count'(Get => Item.Get);
      begin
         return Made.all'Unchecked_Access;
      end;
   end Adapter_Of;

   function Adapter_Of (Self : Context'Class; Item : Rows_Property) return Binders.Rows_Adapter_Ref is
   begin
      pragma Assert (Item.Get /= null);
      declare
         Made : constant Pointer_Rows_Store := new (Binders.Arena (Self)) Pointer_Rows'(Get => Item.Get);
      begin
         return Made.all'Unchecked_Access;
      end;
   end Adapter_Of;

   function Adapter_Of (Self : Context'Class; Item : Choice_Property) return Binders.Choice_Adapter_Ref is
   begin
      pragma Assert (Item.Get /= null and then Item.Set /= null);
      declare
         Made : constant Pointer_Choice_Store :=
           new (Binders.Arena (Self)) Pointer_Choice'(Get => Item.Get, Set => Item.Set, Changes => Item.Changes);
      begin
         return Made.all'Unchecked_Access;
      end;
   end Adapter_Of;

   function Adapter_Of (Self : Context'Class; Item : Action_Property) return Binders.Action_Adapter_Ref is
   begin
      pragma Assert (Item.Allowed /= null and then Item.Perform /= null);
      declare
         Made : constant Pointer_Action_Store :=
           new (Binders.Arena (Self)) Pointer_Action'(Allowed => Item.Allowed, Perform => Item.Perform);
      begin
         return Made.all'Unchecked_Access;
      end;
   end Adapter_Of;

   --  How the model's commands are asked and done, by number.

   type Dispatch is new Binders.Model_Hooks with null record;

   overriding
   function Can_Execute (Self : Dispatch; Item : System.Address; Which : Natural; Index : Natural) return Boolean
   is (Commands.Can_Execute (Commands.Model'Class (Model_At (Item).all), Commands.Command'Val (Which), Index));

   overriding
   procedure Execute (Self : Dispatch; Item : System.Address; Which : Natural; Index : Natural) is
   begin
      Commands.Execute (Commands.Model'Class (Model_At (Item).all), Commands.Command'Val (Which), Index);
   end Execute;

   Instance_Hooks : aliased constant Dispatch := (null record);

   --  Contexts

   function Bind (Screen : in out Pomarine.UI.View; Data : not null access Model) return Context'Class is
   begin
      return Result : Context do
         Binders.Attach (Binders.Context (Result), Screen, Data.all'Address, Instance_Hooks'Unchecked_Access);
      end return;
   end Bind;

   function Bind (Screen : in out Pomarine.UI.View; Data : in out Model) return Context'Class
   is (Bind (Screen, Data'Unrestricted_Access));

   function View_Of (Self : Context'Class) return not null View_Ref is
      Home : constant View_Ref := Find_View (Binders.View_Number (Self));
   begin
      if Home = null then
         raise Stale_Handle with "view is gone";
      end if;
      return Home;
   end View_Of;

   --  Controls made one at a time

   function Label
     (Self  : Context;
      Text  : Text_Property;
      Index : Natural := 0;
      Style : Pomarine.Line_Texts.Style := Pomarine.Line_Texts.Regular;
      Ink   : Pomarine.Themes.Slot := 0) return Pomarine.UI.Label_Handle is
   begin
      return Controls.Label (Self, Adapter_Of (Self, Text), Index, Style, Ink);
   end Label;

   function Label
     (Self    : Context;
      Caption : String;
      Style   : Pomarine.Line_Texts.Style := Pomarine.Line_Texts.Regular;
      Ink     : Pomarine.Themes.Slot := 0) return Pomarine.UI.Label_Handle is
   begin
      return Controls.Label (Self, Caption, Style, Ink);
   end Label;

   function Button
     (Self      : Context;
      Caption   : String;
      Command   : Commands.Command;
      Look      : Pomarine.Widgets.Buttons.Kind := Pomarine.Widgets.Buttons.Normal;
      Index     : Natural := 0;
      Focusable : Boolean := True) return Pomarine.UI.Button_Handle is
   begin
      return Controls.Button (Self, Caption, Commands.Command'Pos (Command), Look, Index, Focusable);
   end Button;

   function Button
     (Self    : Context;
      Caption : String;
      Action  : Action_Property;
      Look    : Pomarine.Widgets.Buttons.Kind := Pomarine.Widgets.Buttons.Normal;
      Index   : Natural := 0) return Pomarine.UI.Button_Handle is
   begin
      return Controls.Button (Self, Caption, Adapter_Of (Self, Action), Look, Index);
   end Button;

   function Text_Field
     (Self        : Context;
      Text        : Text_Property;
      Submit      : Action_Property;
      Placeholder : String := "";
      Name        : String := "";
      Replacing   : Replacement := Caret_At_End;
      Index       : Natural := 0) return Pomarine.UI.Field_Handle is
   begin
      return Controls.Text_Field
        (Self,
         Adapter_Of (Self, Text),
         Adapter_Of (Self, Submit),
         Placeholder,
         Name,
         Binders.Replacement (Replacing),
         Index);
   end Text_Field;

   function Text_Field
     (Self        : Context;
      Text        : Text_Property;
      Placeholder : String := "";
      Name        : String := "";
      Replacing   : Replacement := Caret_At_End;
      Index       : Natural := 0) return Pomarine.UI.Field_Handle is
   begin
      return Controls.Text_Field
        (Self,
         Adapter_Of (Self, Text),
         Placeholder,
         Name,
         Binders.Replacement (Replacing),
         Index);
   end Text_Field;

   function Text_Field
     (Self        : Context;
      Text        : Text_Property;
      Submit      : Commands.Command;
      Placeholder : String := "";
      Name        : String := "";
      Replacing   : Replacement := Caret_At_End;
      Index       : Natural := 0) return Pomarine.UI.Field_Handle is
   begin
      return Controls.Text_Field
        (Self,
         Adapter_Of (Self, Text),
         Commands.Command'Pos (Submit),
         Placeholder,
         Name,
         Binders.Replacement (Replacing),
         Index);
   end Text_Field;

   procedure Enabled_When
     (Self : Context; Target : Pomarine.UI.Button_Handle; Allowed : Flag_Property; Index : Natural := 0) is
   begin
      Controls.Enabled_When (Self, Target, Adapter_Of (Self, Allowed), Index);
   end Enabled_When;

   procedure Selected_When
     (Self : Context; Target : Pomarine.UI.Button_Handle; Selected : Flag_Property; Index : Natural := 0) is
   begin
      Controls.Selected_When (Self, Target, Adapter_Of (Self, Selected), Index);
   end Selected_When;

   function Check
     (Self    : Context;
      Caption : String;
      Checked : Flag_Property;
      Command : Commands.Command;
      Form    : Pomarine.Widgets.Checks.Kind := Pomarine.Widgets.Checks.Box;
      Index   : Natural := 0;
      Name    : String := "") return Pomarine.UI.Check_Handle is
   begin
      return Controls.Check
        (Self,
         Caption,
         Adapter_Of (Self, Checked),
         Commands.Command'Pos (Command),
         Form,
         Index,
         Name);
   end Check;

   function Check
     (Self    : Context;
      Caption : String;
      Checked : Flag_Property;
      Form    : Pomarine.Widgets.Checks.Kind := Pomarine.Widgets.Checks.Box;
      Name    : String := "") return Pomarine.UI.Check_Handle is
   begin
      return Controls.Check (Self, Caption, Adapter_Of (Self, Checked), Form, Name);
   end Check;

   function Button
     (Self    : Context;
      Look    : Pomarine.Widgets.Buttons.Settings;
      Command : Commands.Command;
      Index   : Natural := 0;
      Reflect : Boolean := True) return Pomarine.UI.Button_Handle is
   begin
      return Controls.Button (Self, Look, Commands.Command'Pos (Command), Index, Reflect);
   end Button;

   function Grip
     (Self    : Context;
      Look    : Pomarine.UI.Grip_Look;
      Command : Commands.Command;
      Index   : Natural := 0;
      Name    : String := "") return Pomarine.UI.Grip_Handle is
   begin
      return Controls.Grip (Self, Look, Commands.Command'Pos (Command), Index, Name);
   end Grip;

   function Plain_Grip (Self : Context; Look : Pomarine.UI.Grip_Look) return Pomarine.UI.Grip_Handle is
   begin
      return Controls.Plain_Grip (Self, Look);
   end Plain_Grip;

   function Plain_Button (Self : Context; Look : Pomarine.Widgets.Buttons.Settings) return Pomarine.UI.Button_Handle is
   begin
      return Controls.Plain_Button (Self, Look);
   end Plain_Button;

   function Switch
     (Self    : Context;
      Caption : String;
      On      : Flag_Property;
      Command : Commands.Command;
      Index   : Natural := 0;
      Name    : String := "") return Pomarine.UI.Switch_Handle is
   begin
      return Controls.Switch (Self, Caption, Adapter_Of (Self, On), Commands.Command'Pos (Command), Index, Name);
   end Switch;

   function Progress (Self : Context; Done : Fraction_Property) return Pomarine.UI.Progress_Handle is
   begin
      return Controls.Progress (Self, Adapter_Of (Self, Done));
   end Progress;

   procedure Focus_When
     (Self : Context; Target : Pomarine.UI.Focus_Target; Raised : Flag_Property; Index : Natural := 0) is
   begin
      Controls.Focus_When (Self, Target, Adapter_Of (Self, Raised), Index);
   end Focus_When;

   procedure Show_When
     (Self : Context; Target : Pomarine.UI.Control_Ref; Shown : Flag_Property; Index : Natural := 0)
   is
   begin
      Controls.Show_When (Self, Target, Adapter_Of (Self, Shown), Index);
   end Show_When;

   procedure Show_When (Self : Context; Target : Pomarine.UI.Layout; Shown : Flag_Property; Index : Natural := 0) is
   begin
      Controls.Show_When (Self, Target, Adapter_Of (Self, Shown), Index);
   end Show_When;

   function List
     (Self : Context; Rows : Rows_Property; Selection : Choice_Property; Name : String := "")
      return Pomarine.UI.List_Handle is
   begin
      return Controls.List (Self, Adapter_Of (Self, Rows), Adapter_Of (Self, Selection), Name);
   end List;

   procedure Focus_Initially (Self : Context; Target : Pomarine.UI.Focus_Target) is
   begin
      Controls.Focus_Initially (Self, Target);
   end Focus_Initially;

   procedure Reveal_After
     (Self : Context; Command : Commands.Command; Target : Pomarine.UI.Reveal_Target; Count : Count_Property) is
   begin
      Controls.Reveal_After (Self, Commands.Command'Pos (Command), Target, Adapter_Of (Self, Count));
   end Reveal_After;

   function Borrow_Label
     (Self : Context; Existing : in out Labels.Label; Text : Text_Property) return Pomarine.UI.Label_Handle is
   begin
      return Controls.Borrow_Label (Self, Existing, Adapter_Of (Self, Text));
   end Borrow_Label;

   function Borrow_Button
     (Self     : Context;
      Existing : in out Pomarine.Widgets.Buttons.Button;
      Command  : Commands.Command;
      Index    : Natural := 0;
      Reflect  : Boolean := True) return Pomarine.UI.Button_Handle is
   begin
      return Controls.Borrow_Button (Self, Existing, Commands.Command'Pos (Command), Index, Reflect);
   end Borrow_Button;

   procedure Caption_From
     (Self : Context; Target : Pomarine.UI.Button_Handle; Text : Text_Property; Index : Natural := 0) is
   begin
      Controls.Caption_From (Self, Target, Adapter_Of (Self, Text), Index);
   end Caption_From;

   function Borrow_Field
     (Self      : Context;
      Existing  : in out Text_Fields.Text_Field;
      Backing   : aliased in out Texts.Documents.Document;
      Text      : Text_Property;
      Replacing : Replacement := Caret_At_End) return Pomarine.UI.Field_Handle is
   begin
      return Controls.Borrow_Field (Self, Existing, Backing, Adapter_Of (Self, Text), Binders.Replacement (Replacing));
   end Borrow_Field;

   procedure On_Frame_Event
     (Self    : Context;
      Target  : in out Widgets.Frames.Frame;
      Kind    : Widgets.Event_Kind;
      Command : Commands.Command;
      Index   : Natural := 0) is
   begin
      Controls.On_Frame_Event (Self, Target, Kind, Commands.Command'Pos (Command), Index);
   end On_Frame_Event;

   procedure On_Event
     (Self             : Context;
      Target           : Pomarine.UI.Widget_Handle;
      Kind             : Widgets.Event_Kind;
      Command          : Commands.Command;
      Index            : Natural := 0;
      Index_From_Event : Boolean := False) is
   begin
      On_Event (Self, Pomarine.UI.Any (Target), Kind, Command, Index, Index_From_Event);
   end On_Event;

   procedure On_Event
     (Self             : Context;
      Target           : Pomarine.UI.Control_Ref;
      Kind             : Widgets.Event_Kind;
      Command          : Commands.Command;
      Index            : Natural := 0;
      Index_From_Event : Boolean := False) is
   begin
      Controls.On_Event (Self, Target, Kind, Commands.Command'Pos (Command), Index, Index_From_Event);
   end On_Event;

   procedure On_Editor_Event
     (Self             : Context;
      Target           : Pomarine.UI.Widget_Handle;
      Hook             : Editor_Hook;
      Command          : Commands.Command;
      Index            : Natural := 0;
      Index_From_Event : Boolean := False) is
   begin
      Controls.On_Editor_Event
        (Self,
         Target,
         Binders.Editor_Hook (Hook),
         Commands.Command'Pos (Command),
         Index,
         Index_From_Event);
   end On_Editor_Event;

   procedure On_Canvas_Event
     (Self             : Context;
      Target           : Pomarine.UI.Widget_Handle;
      Hook             : Canvas_Hook;
      Command          : Commands.Command;
      Index            : Natural := 0;
      Index_From_Event : Boolean := False) is
   begin
      Controls.On_Canvas_Event
        (Self,
         Target,
         Binders.Canvas_Hook (Hook),
         Commands.Command'Pos (Command),
         Index,
         Index_From_Event);
   end On_Canvas_Event;

   procedure On_List_Actions (Self : Context; Target : Pomarine.UI.Widget_Handle; Actions : List_Actions) is
      Which : Binders.Which_Array (Actions'Range);
   begin
      for Number in Actions'Range loop
         Which (Number) := Commands.Command'Pos (Actions (Number));
      end loop;
      Controls.On_List_Actions (Self, Target, Which);
   end On_List_Actions;

   function Borrow_Slider
     (Self : Context; Existing : in out Widgets.Sliders.Slider; Value : Fraction_Property)
      return Pomarine.UI.Widget_Handle is
   begin
      return Controls.Borrow_Slider (Self, Existing, Adapter_Of (Self, Value));
   end Borrow_Slider;

   function Borrow_Widget
     (Self : Context; Existing : in out Pomarine.Widgets.Widget'Class) return Pomarine.UI.Widget_Handle is
   begin
      return Controls.Borrow_Widget (Self, Existing);
   end Borrow_Widget;

   function Borrow_List
     (Self : Context; Existing : in out Lists.List; Rows : Rows_Property; Selection : Choice_Property)
      return Pomarine.UI.List_Handle is
   begin
      return Controls.Borrow_List (Self, Existing, Adapter_Of (Self, Rows), Adapter_Of (Self, Selection));
   end Borrow_List;

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
      Align    : Pomarine.UI.Align_Kind := Pomarine.UI.Layouts.As_Is) return Pomarine.UI.Layout
   is
      Home : constant not null View_Ref := View_Of (Self);
      Made : constant Pomarine.UI.Label_Handle := Label (Self, Text, Index, Style, Ink);
   begin
      if Centered then
         Labels.Set_Centered (Widget_Of (Home.all, Made).all, True);
      end if;
      Binders.Describe (Widget_Of (Home.all, Made).all, Tooltip);
      return Pomarine.UI.Place (Made, Grow, Shrink, Width, Height, Margin, Align);
   end Label;

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
      Align    : Pomarine.UI.Align_Kind := Pomarine.UI.Layouts.As_Is) return Pomarine.UI.Layout
   is
      Home : constant not null View_Ref := View_Of (Self);
      Made : constant Pomarine.UI.Label_Handle := Label (Self, Caption, Style, Ink);
   begin
      if Centered then
         Labels.Set_Centered (Widget_Of (Home.all, Made).all, True);
      end if;
      Binders.Describe (Widget_Of (Home.all, Made).all, Tooltip);
      return Pomarine.UI.Place (Made, Grow, Shrink, Width, Height, Margin, Align);
   end Label;

   function Button
     (Self      : Context;
      Caption   : String;
      Command   : Commands.Command;
      Look      : Pomarine.Widgets.Buttons.Kind := Pomarine.Widgets.Buttons.Normal;
      Index     : Natural := 0;
      Focusable : Boolean := True;
      Tooltip   : String := "";
      Name      : String := "";
      Grow      : Pomarine.UI.Layouts.Weight := Pomarine.UI.Layouts.Unchanged;
      Shrink    : Pomarine.UI.Layouts.Weight := Pomarine.UI.Layouts.Unchanged;
      Width     : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Height    : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Margin    : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Align     : Pomarine.UI.Align_Kind := Pomarine.UI.Layouts.As_Is) return Pomarine.UI.Layout
   is
      Home : constant not null View_Ref := View_Of (Self);
      Made : constant Pomarine.UI.Button_Handle := Button (Self, Caption, Command, Look, Index, Focusable);
   begin
      Binders.Describe (Widget_Of (Home.all, Made).all, Tooltip, Name);
      return Pomarine.UI.Place (Made, Grow, Shrink, Width, Height, Margin, Align);
   end Button;

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
      Align   : Pomarine.UI.Align_Kind := Pomarine.UI.Layouts.As_Is) return Pomarine.UI.Layout
   is
      Home : constant not null View_Ref := View_Of (Self);
      Made : constant Pomarine.UI.Button_Handle := Button (Self, Caption, Action, Look, Index);
   begin
      Binders.Describe (Widget_Of (Home.all, Made).all, Tooltip, Name);
      return Pomarine.UI.Place (Made, Grow, Shrink, Width, Height, Margin, Align);
   end Button;

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
   is
      Made : constant Pomarine.UI.Field_Handle := Text_Field (Self, Text, Submit, Placeholder, Name, Replacing, Index);
   begin
      if Focus_Initially then
         Contexts.Focus_Initially (Self, Pomarine.UI.Focus_Of (Made));
      end if;
      return Pomarine.UI.Place (Made, Grow, Shrink, Width, Height, Margin, Align);
   end Text_Field;

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
   is
      Made : constant Pomarine.UI.Field_Handle := Text_Field (Self, Text, Placeholder, Name, Replacing, Index);
   begin
      if Focus_Initially then
         Contexts.Focus_Initially (Self, Pomarine.UI.Focus_Of (Made));
      end if;
      return Pomarine.UI.Place (Made, Grow, Shrink, Width, Height, Margin, Align);
   end Text_Field;

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
      Align   : Pomarine.UI.Align_Kind := Pomarine.UI.Layouts.As_Is) return Pomarine.UI.Layout
   is
      Made : constant Pomarine.UI.Check_Handle := Check (Self, Caption, Checked, Command, Form, Index, Name);
   begin
      return Pomarine.UI.Place (Made, Grow, Shrink, Width, Height, Margin, Align);
   end Check;

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
   is
      Made : constant Pomarine.UI.Check_Handle := Check (Self, Caption, Checked, Form, Name);
   begin
      return Pomarine.UI.Place (Made, Grow, Shrink, Width, Height, Margin, Align);
   end Check;

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
      Align   : Pomarine.UI.Align_Kind := Pomarine.UI.Layouts.As_Is) return Pomarine.UI.Layout
   is
      Made : constant Pomarine.UI.Switch_Handle := Switch (Self, Caption, On, Command, Index, Name);
   begin
      return Pomarine.UI.Place (Made, Grow, Shrink, Width, Height, Margin, Align);
   end Switch;

   function Progress
     (Self   : Context;
      Done   : Fraction_Property;
      Grow   : Pomarine.UI.Layouts.Weight := Pomarine.UI.Layouts.Unchanged;
      Shrink : Pomarine.UI.Layouts.Weight := Pomarine.UI.Layouts.Unchanged;
      Width  : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Height : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Margin : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Align  : Pomarine.UI.Align_Kind := Pomarine.UI.Layouts.As_Is) return Pomarine.UI.Layout
   is
      Made : constant Pomarine.UI.Progress_Handle := Progress (Self, Done);
   begin
      return Pomarine.UI.Place (Made, Grow, Shrink, Width, Height, Margin, Align);
   end Progress;

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
      Align     : Pomarine.UI.Align_Kind := Pomarine.UI.Layouts.As_Is) return Pomarine.UI.Layout
   is
      Made : constant Pomarine.UI.List_Handle := List (Self, Rows, Selection, Name);
   begin
      return Pomarine.UI.Place (Made, Grow, Shrink, Width, Height, Margin, Align);
   end List;

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
      Align        : Pomarine.UI.Align_Kind := Pomarine.UI.Layouts.As_Is) return Pomarine.UI.Layout
   is
      Made : constant Pomarine.UI.List_Handle := List (Self, Rows, Selection, Name);
   begin
      Contexts.Reveal_After (Self, Reveal_After, Pomarine.UI.Reveal_Of (Made), Growth);
      return Pomarine.UI.Place (Made, Grow, Shrink, Width, Height, Margin, Align);
   end List;

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
      Align    : Pomarine.UI.Align_Kind := Pomarine.UI.Layouts.As_Is) return Pomarine.UI.Layout
   is
      Made : constant Pomarine.UI.Widget_Handle := Borrow_Widget (Self, Existing);
   begin
      Binders.Describe (Existing, Tooltip, Name);
      return Pomarine.UI.Place (Made, Grow, Shrink, Width, Height, Margin, Align);
   end Borrow_Widget;

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
      Exact    : Boolean := False) return Pomarine.UI.Layout
   is
      Made : constant Pomarine.UI.Widget_Handle := Borrow_Widget (Self, Existing);
   begin
      Binders.Describe (Existing, Tooltip, Name);
      On_Event (Self, Made, Widgets.Click, Click, Index);
      return Pomarine.UI.Place (Made, Grow, Shrink, Width, Height, Margin, Align, Exact);
   end Borrow_Widget;

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
      Spread   : Pomarine.UI.Spread_Kind := Pomarine.UI.Layouts.As_Is) return Pomarine.UI.Layout
   is
      Made : constant Pomarine.UI.Widget_Handle := Borrow_Widget (Self, Existing);
   begin
      On_Event (Self, Made, Widgets.Click, Click, Index);
      return Pomarine.UI.Hold (Made, Items, Flow, Gap, Padding, Align, Spread);
   end Borrow_Holding;

   function Borrow_Holding
     (Self     : Context;
      Existing : in out Pomarine.Widgets.Widget'Class;
      Items    : Pomarine.UI.Layout_Array;
      Flow     : Pomarine.UI.Layouts.Flow_Kind := Pomarine.UI.Layouts.Column;
      Gap      : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Padding  : Pomarine.UI.Layouts.Length := Pomarine.UI.Unset;
      Align    : Pomarine.UI.Align_Kind := Pomarine.UI.Layouts.As_Is;
      Spread   : Pomarine.UI.Spread_Kind := Pomarine.UI.Layouts.As_Is) return Pomarine.UI.Layout is
   begin
      return Pomarine.UI.Hold (Borrow_Widget (Self, Existing), Items, Flow, Gap, Padding, Align, Spread);
   end Borrow_Holding;

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
      Exact    : Boolean := False) return Pomarine.UI.Layout
   is
      Made : constant Pomarine.UI.Label_Handle := Borrow_Label (Self, Existing, Text);
   begin
      Binders.Describe (Existing, Tooltip, Name);
      return Pomarine.UI.Place (Made, Grow, Shrink, Width, Height, Margin, Align, Exact);
   end Borrow_Label;

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
      Exact    : Boolean := False) return Pomarine.UI.Layout
   is
      Made : constant Pomarine.UI.Button_Handle := Borrow_Button (Self, Existing, Command, Index, Reflect);
   begin
      Binders.Describe (Existing, Tooltip, Name);
      return Pomarine.UI.Place (Made, Grow, Shrink, Width, Height, Margin, Align, Exact);
   end Borrow_Button;

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
   is
      Made : constant Pomarine.UI.Field_Handle := Borrow_Field (Self, Existing, Backing, Text, Replacing);
   begin
      Binders.Describe (Existing, Tooltip, Name);
      return Pomarine.UI.Place (Made, Grow, Shrink, Width, Height, Margin, Align, Exact);
   end Borrow_Field;

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
   is
      Made : constant Pomarine.UI.Widget_Handle := Borrow_Slider (Self, Existing, Value);
   begin
      Binders.Describe (Existing, Tooltip, Name);
      return Pomarine.UI.Place (Made, Grow, Shrink, Width, Height, Margin, Align, Exact);
   end Borrow_Slider;

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
      Exact     : Boolean := False) return Pomarine.UI.Layout
   is
      Made : constant Pomarine.UI.List_Handle := Borrow_List (Self, Existing, Rows, Selection);
   begin
      Binders.Describe (Existing, Tooltip, Name);
      return Pomarine.UI.Place (Made, Grow, Shrink, Width, Height, Margin, Align, Exact);
   end Borrow_List;

   --  Components

   overriding
   procedure Initialize (Item : in out Component) is
   begin
      Binders.Open_Under (Binders.Context (Item), Item.Parent.all);
   end Initialize;

   overriding
   procedure Finalize (Item : in out Component) is
   begin
      if not Item.Committed then
         Binders.Abandon (Item);
      end if;
   end Finalize;

   procedure Commit (Item : in out Component) is
   begin
      Binders.Commit_Scope_Of (Item);
      Item.Committed := True;
   end Commit;

   function Finish (Item : in out Component; Result : Pomarine.UI.Layout) return Pomarine.UI.Layout is
   begin
      Commit (Item);
      return Result;
   end Finish;

end Pomarine.UI.Contexts;
