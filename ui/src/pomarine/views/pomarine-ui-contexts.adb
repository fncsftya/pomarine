with Ada.Strings.Unbounded;
with Pomarine.Text_Areas;
with Pomarine.UI.Arenas;
with Pomarine.Widgets.Editors;
with Pomarine.Widgets.Bindings;

package body Pomarine.UI.Contexts is

   package Labels renames Pomarine.Widgets.Labels;
   package Lists renames Pomarine.Widgets.Lists;
   package Text_Fields renames Pomarine.Widgets.Text_Fields;

   use type Widgets.Widget_Access;

   --  Adapters

   package body Read_Text is
      function Property return Text_Property is ((Adapter => Instance'Access));
   end Read_Text;

   package body Edit_Text is
      function Property return Text_Property is ((Adapter => Instance'Access));
      overriding procedure Assign (Self : Adapter; Item : in out Model; Value : String) is
         pragma Unreferenced (Self);
      begin
         Set (Item, Value);
      end Assign;
   end Edit_Text;

   package body Counter is
      function Property return Count_Property is ((Adapter => Instance'Access));
   end Counter;

   package body Row_Source is
      function Property return Rows_Property is ((Adapter => Instance'Access));
   end Row_Source;

   package body Command_Action is
      function Property return Action_Property is ((Adapter => Instance'Access));
      overriding procedure Perform (Self : Adapter; Item : in out Model) is
         pragma Unreferenced (Self);
      begin
         Perform (Item);
      end Perform;
   end Command_Action;

   package body Choice is
      function Property return Choice_Property is ((Adapter => Instance'Access));
      overriding procedure Choose (Self : Adapter; Item : in out Model; Id : Natural) is
         pragma Unreferenced (Self);
      begin
         Set (Item, Id);
      end Choose;
   end Choice;

   --  What is kept of a binding. Each is allocated in the arena of its scope, with
   --  pointers to the adapters (library level) and the model (borrowed), and the
   --  handles of the widgets, which it checks before it uses them: a record of a
   --  scope outlives nothing, but it does not take it on trust.

   type Label_Binding is new Pomarine.UI.Binding with record
      Handle : Handle_Data;
      Text   : Text_Adapter_Ref;
      Data   : Model_Ref;
      Seen   : VM.Watch;
   end record;

   overriding procedure Refresh (Item : in out Label_Binding; Within : in out View'Class; Forced : Boolean);

   type Field_Binding is new Pomarine.UI.Binding with record
      Handle   : Handle_Data;
      Text     : Text_Adapter_Ref;
      Data     : Model_Ref;
      Seen     : VM.Watch;
      Link     : Widgets.Bindings.Text_Link;
      Deferred : Boolean := False;
      --  The model's text is not yet shown: the person is composing.
      Known    : Ada.Strings.Unbounded.Unbounded_String;
      --  The text the field and the model last agreed on: what was shown, or what the person's edit gave.
      --  A change of the document to the same text (an input method cancelled, an edit undone) is no edit.
      Replacing : Replacement := Caret_At_End;
   end record;

   overriding procedure Collect (Item : in out Field_Binding; Within : in out View'Class);
   overriding procedure Refresh (Item : in out Field_Binding; Within : in out View'Class; Forced : Boolean);

   type Command_Binding is new Pomarine.UI.Binding with record
      Which : Natural := 0;
      --  Commands.Command'Pos of the command, or not used if there is an Action.
      Action : Action_Adapter_Ref;
      Data  : Model_Ref;
   end record;

   overriding function Can_Execute (Item : Command_Binding; Index : Natural) return Boolean;
   overriding procedure Execute (Item : in out Command_Binding; Index : Natural);
   overriding function Key (Item : Command_Binding) return Command_Key;
   overriding function Is_Command (Item : Command_Binding) return Boolean;

   type List_Binding is new Pomarine.UI.Binding with record
      Handle    : Handle_Data;
      Choice    : Choice_Adapter_Ref;
      Data      : Model_Ref;
      Seen      : VM.Watch;
      Last      : Natural := 0;
      --  The id of the chosen row as the model and the list last agreed.
   end record;

   overriding procedure Collect (Item : in out List_Binding; Within : in out View'Class);
   overriding procedure Refresh (Item : in out List_Binding; Within : in out View'Class; Forced : Boolean);

   type Reveal_Binding is new Pomarine.UI.Binding with record
      Handle : Handle_Data;
      Count  : Count_Adapter_Ref;
      Data   : Model_Ref;
      After  : Command_Key;
      Before : Natural := 0;
   end record;

   overriding procedure Before_Command (Item : in out Reveal_Binding; Which : Command_Key);
   overriding procedure After_Command (Item : in out Reveal_Binding; Which : Command_Key);

   type Label_Store is access Label_Binding;
   for Label_Store'Storage_Pool use Pomarine.UI.Arenas.Pool;
   type Field_Store is access Field_Binding;
   for Field_Store'Storage_Pool use Pomarine.UI.Arenas.Pool;
   type Command_Store is access Command_Binding;
   for Command_Store'Storage_Pool use Pomarine.UI.Arenas.Pool;
   type List_Store is access List_Binding;
   for List_Store'Storage_Pool use Pomarine.UI.Arenas.Pool;
   type Reveal_Store is access Reveal_Binding;
   for Reveal_Store'Storage_Pool use Pomarine.UI.Arenas.Pool;

   --  Label

   overriding procedure Refresh (Item : in out Label_Binding; Within : in out View'Class; Forced : Boolean) is
      Changed : constant Boolean := VM.Changed (Item.Seen, Stamp (Item.Text.all, Item.Data.all));
      Found   : constant Widgets.Widget_Access := Resolve (Within, Item.Handle, Label_Control);
   begin
      if Found /= null and then (Forced or else Changed) then
         declare
            Shown : Labels.Label renames Labels.Label (Found.all);
            Now   : constant String := Current (Item.Text.all, Item.Data.all);
         begin
            if Labels.Text (Shown) /= Now then
               Labels.Set_Text (Shown, Now);
               Within.Touched := True;
            end if;
         end;
      end if;
   end Refresh;

   --  Field

   function Is_Composing (Field : in out Text_Fields.Text_Field) return Boolean is
     (Text_Areas.Is_Composing (Widgets.Editors.Area (Widgets.Editors.Editor (Field)).all));

   procedure Place_Caret
     (Field   : in out Text_Fields.Text_Field;
      Doc     : Docs.Document;
      Rule    : Replacement;
      Before  : Texts.Position)
   is
      Where : Texts.Position := Docs.Text_End (Doc);
   begin
      case Rule is
         when Caret_At_End =>
            null;
         when Caret_At_Start =>
            Where := (Paragraph => 1, Index => 1);
         when Caret_Kept =>
            if Docs.Is_Position (Doc, (Paragraph => 1, Index => Before.Index)) then
               Where := (Paragraph => 1, Index => Before.Index);
            end if;
      end case;
      Text_Areas.Select_Range (Widgets.Editors.Area (Widgets.Editors.Editor (Field)).all, Where, Where);
   end Place_Caret;

   overriding procedure Collect (Item : in out Field_Binding; Within : in out View'Class) is
      Found : constant Widgets.Widget_Access := Resolve (Within, Item.Handle, Field_Control);
   begin
      if Found = null or else not Item.Text.Can_Assign then
         return;
      end if;
      declare
         Field : Text_Fields.Text_Field renames Text_Fields.Text_Field (Found.all);
         Doc   : constant Docs.Document_Access := Within.Controls (Item.Handle.Slot).Document;
      begin
         --  What an input method shows before it sends it is not yet the person's word.
         if not Is_Composing (Field) and then Widgets.Bindings.Edited (Item.Link, Doc.all) then
            declare
               Now : constant String := Docs.Whole (Doc.all);
            begin
               if Now /= Ada.Strings.Unbounded.To_String (Item.Known) then
                  Item.Known := Ada.Strings.Unbounded.To_Unbounded_String (Now);
                  Assign (Item.Text.all, Item.Data.all, Now);
                  Within.Touched := True;
               end if;
            end;
         end if;
      end;
   end Collect;

   overriding procedure Refresh (Item : in out Field_Binding; Within : in out View'Class; Forced : Boolean) is
      Changed : constant Boolean := VM.Changed (Item.Seen, Stamp (Item.Text.all, Item.Data.all));
      Found   : constant Widgets.Widget_Access := Resolve (Within, Item.Handle, Field_Control);
   begin
      if Found = null or else not (Forced or else Changed or else Item.Deferred) then
         return;
      end if;
      declare
         Field  : Text_Fields.Text_Field renames Text_Fields.Text_Field (Found.all);
         Doc    : constant Docs.Document_Access := Within.Controls (Item.Handle.Slot).Document;
         Wanted : constant String := Current (Item.Text.all, Item.Data.all);
      begin
         if Docs.Whole (Doc.all) = Wanted then
            --  Already shown: the caret, the selection, the history and the composition are left alone.
            Item.Deferred := False;
            Item.Known := Ada.Strings.Unbounded.To_Unbounded_String (Wanted);
         elsif Is_Composing (Field) then
            Item.Deferred := True;
         else
            declare
               Before : constant Texts.Position :=
                 Text_Areas.Caret (Widgets.Editors.Area (Widgets.Editors.Editor (Field)).all);
            begin
               Widgets.Bindings.Show (Item.Link, Doc.all, Wanted);
               Item.Known := Ada.Strings.Unbounded.To_Unbounded_String (Wanted);
               Place_Caret (Field, Doc.all, Item.Replacing, Before);
               Item.Deferred := False;
               Within.Touched := True;
            end;
         end if;
      end;
   end Refresh;

   --  Command

   overriding function Can_Execute (Item : Command_Binding; Index : Natural) return Boolean is
     (if Item.Action /= null then Index = 0 and then Allowed (Item.Action.all, Item.Data.all)
      else Commands.Can_Execute (Commands.Model'Class (Item.Data.all), Commands.Command'Val (Item.Which), Index));

   overriding procedure Execute (Item : in out Command_Binding; Index : Natural) is
   begin
      if Item.Action /= null then
         Perform (Item.Action.all, Item.Data.all);
      else
         Commands.Execute (Commands.Model'Class (Item.Data.all), Commands.Command'Val (Item.Which), Index);
      end if;
   end Execute;

   overriding function Key (Item : Command_Binding) return Command_Key is
     ((Model => Item.Data.all'Address, Which => (if Item.Action = null then Item.Which else Natural'Last)));
   --  An action has no number: it is no command that an effect (Reveal_After) can be about.

   overriding function Is_Command (Item : Command_Binding) return Boolean is
      pragma Unreferenced (Item);
   begin
      return True;
   end Is_Command;

   --  List

   overriding procedure Collect (Item : in out List_Binding; Within : in out View'Class) is
      Found : constant Widgets.Widget_Access := Resolve (Within, Item.Handle, List_Control);
   begin
      if Found = null then
         return;
      end if;
      Lists.Catch_Up (Lists.List (Found.all));
      declare
         Now : constant Natural := Lists.Chosen_Id (Lists.List (Found.all));
      begin
         if Now /= Item.Last then
            Item.Last := Now;
            Choose (Item.Choice.all, Item.Data.all, Now);
            Within.Touched := True;
         end if;
      end;
   end Collect;

   overriding procedure Refresh (Item : in out List_Binding; Within : in out View'Class; Forced : Boolean) is
      Changed : constant Boolean := VM.Changed (Item.Seen, Stamp (Item.Choice.all, Item.Data.all));
      Found   : constant Widgets.Widget_Access := Resolve (Within, Item.Handle, List_Control);
   begin
      if Found /= null and then (Forced or else Changed) then
         declare
            Shown  : Lists.List renames Lists.List (Found.all);
            Wanted : constant Natural := Chosen (Item.Choice.all, Item.Data.all);
         begin
            if Wanted /= Lists.Chosen_Id (Shown) then
               Lists.Select_Id (Shown, Wanted);
               Within.Touched := True;
            end if;
            Item.Last := Lists.Chosen_Id (Shown);
         end;
      end if;
   end Refresh;

   --  Effect

   overriding procedure Before_Command (Item : in out Reveal_Binding; Which : Command_Key) is
   begin
      if Which = Item.After then
         Item.Before := Current (Item.Count.all, Item.Data.all);
      end if;
   end Before_Command;

   overriding procedure After_Command (Item : in out Reveal_Binding; Which : Command_Key) is
   begin
      if Which = Item.After then
         declare
            Now : constant Natural := Current (Item.Count.all, Item.Data.all);
         begin
            if Now > Item.Before then
               --  Needs the view; found by number, as every use of a view from a record.
               declare
                  Home : constant View_Ref := Find_View (Item.Owner);
               begin
                  if Home /= null then
                     declare
                        Found : constant Widgets.Widget_Access := Resolve (Home.all, Item.Handle, List_Control);
                     begin
                        if Found /= null then
                           Lists.Reveal (Lists.List (Found.all), Now);
                        end if;
                     end;
                  end if;
               end;
            end if;
         end;
      end if;
   end After_Command;

   --  Contexts

   function Bind (Screen : in out Pomarine.UI.View; Data : not null access Model) return Context'Class is
   begin
      return Context'(Ada.Finalization.Limited_Controlled with
              Number => Number_Of (Screen),
              Data   => Data.all'Unrestricted_Access,
              Scope  => Root_Scope (Screen));
   end Bind;

   function Scope_Of (Item : Context) return Pomarine.UI.Scope_Ref is (Item.Scope);

   function View_Of (Self : Context'Class) return not null View_Ref is
      Home : constant View_Ref := Find_View (Self.Number);
   begin
      if Home = null then
         raise Stale_Handle with "view is gone";
      end if;
      return Home;
   end View_Of;

   function Is_Open (Item : Context) return Boolean is
      Home : constant View_Ref := Find_View (Item.Number);
   begin
      if Home = null or else not Is_Live (Home.all, Item.Scope) then
         return False;
      end if;
      begin
         Require_Open (Home.all, Item.Scope);
         return True;
      exception
         when Program_Error =>
            return False;
      end;
   end Is_Open;

   --  Making a command binding for a widget that triggers it.

   procedure Wire_Command
     (Self    : Context;
      Home    : in out Pomarine.UI.View'Class;
      Widget  : in out Widgets.Widget'Class;
      Command : Commands.Command;
      Index   : Natural;
      Reflect : Boolean;
      Action  : Action_Adapter_Ref := null)
   is
      Where : constant Subpools.Subpool_Handle := Arena_Of (Home, Self.Scope);
      Made : constant Command_Store := new (Where) Command_Binding;
   begin
      Made.Which := Commands.Command'Pos (Command);
      Made.Action := Action;
      Made.Data := Self.Data;
      Made.Tag := Command_Tag (Home);
      Add_Binding (Home, Self.Scope, Made.all'Unchecked_Access);
      Widgets.Set_Tag (Widget, Made.Tag, Index, Reflects => Reflect);
   end Wire_Command;

   procedure Wire_Label
     (Self : Context; Home : in out Pomarine.UI.View'Class; Handle : Pomarine.UI.Label_Handle; Text : Text_Property)
   is
      Where : constant Subpools.Subpool_Handle := Arena_Of (Home, Self.Scope);
      Made : constant Label_Store := new (Where) Label_Binding;
   begin
      Made.Handle := Handle_Data (Handle);
      Made.Text := Text.Adapter;
      Made.Data := Self.Data;
      Add_Binding (Home, Self.Scope, Made.all'Unchecked_Access);
   end Wire_Label;

   procedure Wire_Field
     (Self      : Context;
      Home      : in out Pomarine.UI.View'Class;
      Handle    : Pomarine.UI.Field_Handle;
      Text      : Text_Property;
      Replacing : Replacement)
   is
      Where : constant Subpools.Subpool_Handle := Arena_Of (Home, Self.Scope);
      Made : constant Field_Store := new (Where) Field_Binding;
   begin
      Made.Handle := Handle_Data (Handle);
      Made.Text := Text.Adapter;
      Made.Data := Self.Data;
      Made.Replacing := Replacing;
      --  What the field shows now is taken as seen, so it is not an edit.
      declare
         Primed : constant Boolean :=
           Widgets.Bindings.Edited (Made.Link, Home.Controls (Made.Handle.Slot).Document.all);
         pragma Unreferenced (Primed);
      begin
         null;
      end;
      Add_Binding (Home, Self.Scope, Made.all'Unchecked_Access);
   end Wire_Field;

   procedure Wire_List
     (Self      : Context;
      Home      : in out Pomarine.UI.View'Class;
      Handle    : Pomarine.UI.List_Handle;
      Rows      : Rows_Property;
      Selection : Choice_Property)
   is
      Where : constant Subpools.Subpool_Handle := Arena_Of (Home, Self.Scope);
      Made : constant List_Store := new (Where) List_Binding;
   begin
      Lists.Set_Model (Widget_Of (Home, Handle).all, Rows_Of (Rows.Adapter.all, Self.Data.all));
      Made.Handle := Handle_Data (Handle);
      Made.Choice := Selection.Adapter;
      Made.Data := Self.Data;
      Add_Binding (Home, Self.Scope, Made.all'Unchecked_Access);
   end Wire_List;

   procedure Called
     (Home : in out Pomarine.UI.View'Class; Handle : Handle_Data; Kind : Control_Kind; Name : String) is
   begin
      if Name /= "" then
         Widgets.Set_Accessible_Name (Resolve (Home, Handle, Kind).all, Name);
      end if;
   end Called;

   function Label (Self : Context; Text : Text_Property) return Pomarine.UI.Label_Handle is
      Home   : constant not null View_Ref := View_Of (Self);
      Handle : constant Pomarine.UI.Label_Handle := New_Label (Home.all, Self.Scope);
   begin
      Wire_Label (Self, Home.all, Handle, Text);
      return Handle;
   end Label;

   function Button
     (Self    : Context;
      Caption : String;
      Command : Commands.Command;
      Look    : Pomarine.Widgets.Buttons.Kind := Pomarine.Widgets.Buttons.Normal;
      Index   : Natural := 0) return Pomarine.UI.Button_Handle
   is
      Home   : constant not null View_Ref := View_Of (Self);
      Handle : constant Pomarine.UI.Button_Handle := New_Button (Home.all, Self.Scope, Caption, Look);
   begin
      Wire_Command (Self, Home.all, Widget_Of (Home.all, Handle).all, Command, Index, Reflect => True);
      return Handle;
   end Button;

   function Button
     (Self    : Context;
      Caption : String;
      Action  : Action_Property;
      Look    : Pomarine.Widgets.Buttons.Kind := Pomarine.Widgets.Buttons.Normal;
      Index   : Natural := 0) return Pomarine.UI.Button_Handle
   is
      Home   : constant not null View_Ref := View_Of (Self);
      Handle : constant Pomarine.UI.Button_Handle := New_Button (Home.all, Self.Scope, Caption, Look);
   begin
      Wire_Command
        (Self, Home.all, Widget_Of (Home.all, Handle).all, Commands.Command'First, Index, Reflect => True,
         Action => Action.Adapter);
      return Handle;
   end Button;

   function Text_Field
     (Self        : Context;
      Text        : Text_Property;
      Submit      : Action_Property;
      Placeholder : String := "";
      Name        : String := "";
      Replacing   : Replacement := Caret_At_End) return Pomarine.UI.Field_Handle
   is
      Home   : constant not null View_Ref := View_Of (Self);
      Handle : constant Pomarine.UI.Field_Handle := New_Field (Home.all, Self.Scope, Placeholder);
   begin
      Wire_Field (Self, Home.all, Handle, Text, Replacing);
      Called (Home.all, Handle_Data (Handle), Field_Control, Name);
      Wire_Command
        (Self, Home.all, Widget_Of (Home.all, Handle).all, Commands.Command'First, 0, Reflect => False,
         Action => Submit.Adapter);
      return Handle;
   end Text_Field;

   function Text_Field
     (Self        : Context;
      Text        : Text_Property;
      Placeholder : String := "";
      Name        : String := "";
      Replacing   : Replacement := Caret_At_End) return Pomarine.UI.Field_Handle
   is
      Home   : constant not null View_Ref := View_Of (Self);
      Handle : constant Pomarine.UI.Field_Handle := New_Field (Home.all, Self.Scope, Placeholder);
   begin
      Wire_Field (Self, Home.all, Handle, Text, Replacing);
      Called (Home.all, Handle_Data (Handle), Field_Control, Name);
      return Handle;
   end Text_Field;

   function Text_Field
     (Self        : Context;
      Text        : Text_Property;
      Submit      : Commands.Command;
      Placeholder : String := "";
      Name        : String := "";
      Replacing   : Replacement := Caret_At_End) return Pomarine.UI.Field_Handle
   is
      Home   : constant not null View_Ref := View_Of (Self);
      Handle : constant Pomarine.UI.Field_Handle := New_Field (Home.all, Self.Scope, Placeholder);
   begin
      Wire_Field (Self, Home.all, Handle, Text, Replacing);
      Called (Home.all, Handle_Data (Handle), Field_Control, Name);
      Wire_Command (Self, Home.all, Widget_Of (Home.all, Handle).all, Submit, 0, Reflect => False);
      return Handle;
   end Text_Field;

   function List
     (Self      : Context;
      Rows      : Rows_Property;
      Selection : Choice_Property;
      Name      : String := "") return Pomarine.UI.List_Handle
   is
      Home   : constant not null View_Ref := View_Of (Self);
      Handle : constant Pomarine.UI.List_Handle := New_List (Home.all, Self.Scope);
   begin
      Wire_List (Self, Home.all, Handle, Rows, Selection);
      Called (Home.all, Handle_Data (Handle), List_Control, Name);
      return Handle;
   end List;

   procedure Focus_Initially (Self : Context; Target : Pomarine.UI.Focus_Target) is
      Home : constant not null View_Ref := View_Of (Self);
   begin
      Require_Open (Home.all, Self.Scope);
      Set_Focus_Initially (Home.all, Target);
   end Focus_Initially;

   procedure Reveal_After
     (Self    : Context;
      Command : Commands.Command;
      Target  : Pomarine.UI.Reveal_Target;
      Count   : Count_Property)
   is
      Home : constant not null View_Ref := View_Of (Self);
      Where : constant Subpools.Subpool_Handle := Arena_Of (Home.all, Self.Scope);
      Made : constant Reveal_Store := new (Where) Reveal_Binding;
   begin
      Require_Open (Home.all, Self.Scope);
      Check_Handle (Home.all, Data_Of (Target), List_Control);
      Made.Handle := Data_Of (Target);
      Made.Count := Count.Adapter;
      Made.Data := Self.Data;
      Made.After := (Model => Self.Data.all'Address, Which => Commands.Command'Pos (Command));
      Add_Binding (Home.all, Self.Scope, Made.all'Unchecked_Access);
   end Reveal_After;

   --  Borrowing

   function Borrow_Label
     (Self : Context; Existing : in out Labels.Label; Text : Text_Property) return Pomarine.UI.Label_Handle
   is
      Home   : constant not null View_Ref := View_Of (Self);
      Handle : constant Pomarine.UI.Label_Handle := Pomarine.UI.Borrow_Label (Home.all, Self.Scope, Existing);
   begin
      Wire_Label (Self, Home.all, Handle, Text);
      return Handle;
   end Borrow_Label;

   function Borrow_Button
     (Self     : Context;
      Existing : in out Pomarine.Widgets.Buttons.Button;
      Command  : Commands.Command;
      Index    : Natural := 0) return Pomarine.UI.Button_Handle
   is
      Home   : constant not null View_Ref := View_Of (Self);
      Handle : constant Pomarine.UI.Button_Handle := Pomarine.UI.Borrow_Button (Home.all, Self.Scope, Existing);
   begin
      Wire_Command (Self, Home.all, Existing, Command, Index, Reflect => True);
      return Handle;
   end Borrow_Button;

   function Borrow_Field
     (Self      : Context;
      Existing  : in out Text_Fields.Text_Field;
      Backing   : aliased in out Texts.Documents.Document;
      Text      : Text_Property;
      Replacing : Replacement := Caret_At_End) return Pomarine.UI.Field_Handle
   is
      Home   : constant not null View_Ref := View_Of (Self);
      Handle : constant Pomarine.UI.Field_Handle :=
        Pomarine.UI.Borrow_Field (Home.all, Self.Scope, Existing, Backing);
   begin
      Wire_Field (Self, Home.all, Handle, Text, Replacing);
      return Handle;
   end Borrow_Field;

   function Borrow_List
     (Self      : Context;
      Existing  : in out Lists.List;
      Rows      : Rows_Property;
      Selection : Choice_Property) return Pomarine.UI.List_Handle
   is
      Home   : constant not null View_Ref := View_Of (Self);
      Handle : constant Pomarine.UI.List_Handle := Pomarine.UI.Borrow_List (Home.all, Self.Scope, Existing);
   begin
      Wire_List (Self, Home.all, Handle, Rows, Selection);
      return Handle;
   end Borrow_List;

   --  Components

   overriding procedure Initialize (Item : in out Component) is
      Home : constant not null View_Ref := View_Of (Item.Parent.all);
   begin
      Item.Number := Item.Parent.Number;
      Item.Data := Item.Parent.Data;
      Item.Scope := Open_Scope (Home.all, Item.Parent.Scope);
   end Initialize;

   overriding procedure Finalize (Item : in out Component) is
      Home : constant View_Ref := Find_View (Item.Number);
   begin
      if not Item.Committed and then Home /= null then
         Abandon_Scope (Home.all, Item.Scope);
      end if;
   end Finalize;

   procedure Commit (Item : in out Component) is
      Home : constant not null View_Ref := View_Of (Item);
   begin
      Commit_Scope (Home.all, Item.Scope);
      Item.Committed := True;
   end Commit;

end Pomarine.UI.Contexts;
