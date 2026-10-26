with Ada.Strings.Unbounded;
with Pomarine.Text_Areas;
with Pomarine.UI.Arenas;
with Pomarine.UI.Syncing;
with Pomarine.Widgets.Editors;
with Pomarine.Widgets.Bindings;
with Pomarine.Widgets.Callbacks;
with Pomarine.Widgets.Frames.Handlers;

package body Pomarine.UI.Contexts is

   package Labels renames Pomarine.Widgets.Labels;
   package Checks renames Pomarine.Widgets.Checks;
   package Lists renames Pomarine.Widgets.Lists;
   package Progress_Bars renames Pomarine.Widgets.Progress_Bars;
   package Switches renames Pomarine.Widgets.Switches;
   package Text_Fields renames Pomarine.Widgets.Text_Fields;

   use type Widgets.Widget_Access;

   --  Adapters

   package body Read_Text is
      function Property return Text_Property is ((Adapter => Instance'Access));
   end Read_Text;

   package body Edit_Text is
      function Property return Text_Property is ((Adapter => Instance'Access));
      overriding procedure Assign (Self : Adapter; Item : in out Model; Value : String; Index : Natural) is
         pragma Unreferenced (Self, Index);
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

   package body Indexed_Text is
      function Property return Text_Property is ((Adapter => Instance'Access));
   end Indexed_Text;

   package body Indexed_Flag is
      function Property return Flag_Property is ((Adapter => Instance'Access));
   end Indexed_Flag;

   package body Read_Flag is
      function Property return Flag_Property is ((Adapter => Instance'Access));
   end Read_Flag;

   package body Edit_Flag is
      function Property return Flag_Property is ((Adapter => Instance'Access));
      overriding procedure Assign (Self : Adapter; Item : in out Model; Value : Boolean; Index : Natural) is
         pragma Unreferenced (Self, Index);
      begin
         Set (Item, Value);
      end Assign;
   end Edit_Flag;

   package body Read_Fraction is
      function Property return Fraction_Property is ((Adapter => Instance'Access));
   end Read_Fraction;

   package body Edit_Fraction is
      function Property return Fraction_Property is ((Adapter => Instance'Access));
      overriding procedure Assign (Self : Adapter; Item : in out Model; Value : Float) is
      begin
         Set (Item, Value);
      end Assign;
   end Edit_Fraction;

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
      Index  : Natural := 0;
      Handle : Handle_Data;
      Text   : Text_Adapter_Ref;
      Data   : Model_Ref;
      Seen   : VM.Watch;
   end record;

   overriding procedure Refresh (Item : in out Label_Binding; Within : in out View'Class; Forced : Boolean);

   type Field_Binding is new Pomarine.UI.Binding with record
      Index  : Natural := 0;
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

   type Frame_Ref is access all Widgets.Frames.Frame;
   type Event_Command_Binding is new Command_Binding with record
      Home : View_Ref;
      Target : Widgets.Widget_Access;
      Frame : Frame_Ref;
      Kind : Widgets.Event_Kind := Widgets.Click;
      Index : Natural := 0;
      Index_From_Event : Boolean := False;
   end record;
   overriding procedure Detach (Item : in out Event_Command_Binding; Within : in out View'Class);
   package Event_Callbacks is new Widgets.Callbacks (Event_Command_Binding);
   package Frame_Callbacks is new Widgets.Frames.Handlers (Event_Command_Binding);
   type Event_Command_Store is access Event_Command_Binding;
   for Event_Command_Store'Storage_Pool use Pomarine.UI.Arenas.Pool;

   procedure Event_Heard
     (Self : in out Event_Command_Binding; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
   begin
      Syncing.Hear
        (Self.Home.all, (Kind => Widgets.Click, Tag => Self.Tag,
                         Index => (if not Self.Index_From_Event then Self.Index
                                   elsif Event.Kind in Widgets.Choose | Widgets.Act then Event.Row
                                   else Event.Index)));
   end Event_Heard;

   overriding procedure Detach (Item : in out Event_Command_Binding; Within : in out View'Class) is
      pragma Unreferenced (Within);
   begin
      if Item.Frame /= null then
         Frame_Callbacks.Off (Item.Frame.all, Item.Kind);
         Item.Frame := null;
      end if;
      if Item.Target /= null then
         Event_Callbacks.Off (Item.Target.all, Item.Kind);
         Item.Target := null;
      end if;
   end Detach;

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

   type Flag_Binding is new Pomarine.UI.Binding with record
      Index  : Natural := 0;
      Handle : Handle_Data;
      Kind   : Control_Kind;
      Flag   : Flag_Adapter_Ref;
      Data   : Model_Ref;
      Known  : Boolean := False;
      Availability : Boolean := False;
      --  What the widget and the model last agreed on, for a flag the person can set.
   end record;

   overriding procedure Collect (Item : in out Flag_Binding; Within : in out View'Class);
   overriding procedure Refresh (Item : in out Flag_Binding; Within : in out View'Class; Forced : Boolean);

   type Shown_Binding is new Pomarine.UI.Binding with record
      Index  : Natural := 0;
      Handle : Handle_Data;
      Flag   : Flag_Adapter_Ref;
      Data   : Model_Ref;
   end record;

   overriding procedure Refresh (Item : in out Shown_Binding; Within : in out View'Class; Forced : Boolean);

   type Panel_Binding is new Pomarine.UI.Binding with record
      Index  : Natural := 0;
      Screen : Pomarine.UI.Layout;
      Flag   : Flag_Adapter_Ref;
      Data   : Model_Ref;
   end record;

   overriding procedure Refresh (Item : in out Panel_Binding; Within : in out View'Class; Forced : Boolean);

   type Focus_Binding is new Pomarine.UI.Binding with record
      Index  : Natural := 0;
      Handle : Handle_Data;
      Flag   : Flag_Adapter_Ref;
      Data   : Model_Ref;
      Raised : Boolean := False;
      --  Whether the flag was true when last looked at.
   end record;

   overriding procedure Refresh (Item : in out Focus_Binding; Within : in out View'Class; Forced : Boolean);

   type Progress_Binding is new Pomarine.UI.Binding with record
      Handle : Handle_Data;
      Done   : Fraction_Adapter_Ref;
      Data   : Model_Ref;
   end record;

   overriding procedure Refresh (Item : in out Progress_Binding; Within : in out View'Class; Forced : Boolean);

   type Slider_Binding is new Pomarine.UI.Binding with record
      Handle : Handle_Data;
      Value : Fraction_Adapter_Ref;
      Data : Model_Ref;
      Shown : Float := 0.0;
      Ready : Boolean := False;
   end record;
   overriding procedure Collect (Item : in out Slider_Binding; Within : in out View'Class);
   overriding procedure Refresh (Item : in out Slider_Binding; Within : in out View'Class; Forced : Boolean);
   type Slider_Store is access Slider_Binding;
   for Slider_Store'Storage_Pool use Pomarine.UI.Arenas.Pool;

   type Flag_Store is access Flag_Binding;
   for Flag_Store'Storage_Pool use Pomarine.UI.Arenas.Pool;
   type Shown_Store is access Shown_Binding;
   for Shown_Store'Storage_Pool use Pomarine.UI.Arenas.Pool;
   type Panel_Store is access Panel_Binding;
   for Panel_Store'Storage_Pool use Pomarine.UI.Arenas.Pool;
   type Focus_Store is access Focus_Binding;
   for Focus_Store'Storage_Pool use Pomarine.UI.Arenas.Pool;
   type Progress_Store is access Progress_Binding;
   for Progress_Store'Storage_Pool use Pomarine.UI.Arenas.Pool;

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
      Changed : constant Boolean := VM.Changed (Item.Seen, Stamp (Item.Text.all, Item.Data.all, Item.Index));
      Found   : constant Widgets.Widget_Access := Resolve (Within, Item.Handle, Label_Control);
   begin
      if Found /= null and then (Forced or else Changed) then
         declare
            Shown : Labels.Label renames Labels.Label (Found.all);
            Now   : constant String := Current (Item.Text.all, Item.Data.all, Item.Index);
         begin
            if Labels.Text (Shown) /= Now then
               Labels.Set_Text (Shown, Now);
               Within.Touched := True;
            end if;
         end;
      end if;
   end Refresh;

   --  Check, switch, visibility, progress. These compare with the widget at every turn: they are cheap,
   --  and a click that the model did not take is undone.

   function Shown_By (Found : Widgets.Widget_Access; Kind : Control_Kind) return Boolean is
     (if Kind = Button_Control then Buttons.Is_Selected (Buttons.Button (Found.all))
      elsif Kind = Check_Control then Checks.Is_Checked (Checks.Check (Found.all))
      else Switches.Is_On (Switches.Switch (Found.all)));

   overriding procedure Collect (Item : in out Flag_Binding; Within : in out View'Class) is
      Found : constant Widgets.Widget_Access := Resolve (Within, Item.Handle, Item.Kind);
   begin
      if Found /= null and then Item.Kind /= Button_Control and then Item.Flag.Can_Assign
        and then Shown_By (Found, Item.Kind) /= Item.Known
      then
         Item.Known := Shown_By (Found, Item.Kind);
         Assign (Item.Flag.all, Item.Data.all, Item.Known, Item.Index);
         Within.Touched := True;
      end if;
   end Collect;

   overriding procedure Refresh (Item : in out Flag_Binding; Within : in out View'Class; Forced : Boolean) is
      pragma Unreferenced (Forced);
      Found : constant Widgets.Widget_Access := Resolve (Within, Item.Handle, Item.Kind);
   begin
      if Found = null then
         return;
      end if;
      declare
         Wanted : constant Boolean := Current (Item.Flag.all, Item.Data.all, Item.Index);
      begin
         Item.Known := Wanted;
         if Item.Kind = Button_Control and then Item.Availability then
            if Buttons.Is_Enabled (Buttons.Button (Found.all)) /= Wanted then
               Buttons.Set_Enabled (Buttons.Button (Found.all), Wanted);
               Within.Touched := True;
            end if;
         elsif Item.Kind = Button_Control then
            if Buttons.Is_Selected (Buttons.Button (Found.all)) /= Wanted then
               Buttons.Set_Selected (Buttons.Button (Found.all), Wanted);
               Within.Touched := True;
            end if;
         elsif Item.Kind = Check_Control then
            if Checks.Is_Checked (Checks.Check (Found.all)) /= Wanted then
               Checks.Set_Checked (Checks.Check (Found.all), Wanted);
               Within.Touched := True;
            end if;
         elsif Switches.Is_On (Switches.Switch (Found.all)) /= Wanted then
            Switches.Set_On (Switches.Switch (Found.all), Wanted);
            Within.Touched := True;
         end if;
      end;
   end Refresh;

   overriding procedure Refresh (Item : in out Shown_Binding; Within : in out View'Class; Forced : Boolean) is
      pragma Unreferenced (Forced);
      Slot : constant Natural := Item.Handle.Slot;
   begin
      if Item.Handle.View /= Within.Number or else Slot not in 1 .. Natural (Within.Controls.Length)
        or else Within.Controls (Slot).Kind = Free_Slot
        or else Within.Controls (Slot).Generation /= Item.Handle.Generation
      then
         return;
      end if;
      declare
         Found  : constant Widgets.Widget_Access := Within.Controls (Slot).Widget;
         Wanted : constant Boolean := Current (Item.Flag.all, Item.Data.all, Item.Index);
      begin
         if Widgets.Is_Visible (Found.all) /= Wanted then
            Widgets.Set_Visible (Found.all, Wanted);
            Within.Touched := True;
         end if;
      end;
   end Refresh;

   overriding procedure Refresh (Item : in out Panel_Binding; Within : in out View'Class; Forced : Boolean) is
      pragma Unreferenced (Forced);
   begin
      if Item.Screen.Node = null or else Item.Screen.Node.Made = null or else not Is_Live (Within, Item.Screen) then
         return;
      end if;
      declare
         Found  : constant Widgets.Widget_Access := Item.Screen.Node.Made;
         Wanted : constant Boolean := Current (Item.Flag.all, Item.Data.all, Item.Index);
      begin
         if Widgets.Is_Visible (Found.all) /= Wanted then
            Widgets.Set_Visible (Found.all, Wanted);
            Within.Touched := True;
         end if;
      end;
   end Refresh;

   overriding procedure Refresh (Item : in out Focus_Binding; Within : in out View'Class; Forced : Boolean) is
      pragma Unreferenced (Forced);
      Now   : constant Boolean := Current (Item.Flag.all, Item.Data.all, Item.Index);
      Found : Widgets.Widget_Access := Resolve (Within, Item.Handle, Field_Control);
   begin
      if Now and then not Item.Raised then
         if Found = null then
            Found := Resolve (Within, Item.Handle, Button_Control);
         end if;
         if Found /= null and then Widgets.Is_Attached (Found.all) and then Widgets.Is_Shown (Found.all) then
            Item.Raised := True;
            if Within.Controls (Item.Handle.Slot).Kind = Field_Control then
               Text_Areas.Select_All
                 (Widgets.Editors.Area (Widgets.Editors.Editor (Text_Fields.Text_Field (Found.all))).all);
            end if;
            --  Not before the buttons of the field are on (see Revalidate).
            Widgets.Revalidate (Within.Tree.all);
            Widgets.Focus (Found.all);
            Within.Touched := True;
         end if;
      elsif not Now then
         Item.Raised := False;
      end if;
   end Refresh;

   overriding procedure Refresh (Item : in out Progress_Binding; Within : in out View'Class; Forced : Boolean) is
      pragma Unreferenced (Forced);
      Found : constant Widgets.Widget_Access := Resolve (Within, Item.Handle, Progress_Control);
   begin
      if Found = null then
         return;
      end if;
      declare
         Wanted : constant Float := Float'Max (0.0, Float'Min (1.0, Current (Item.Done.all, Item.Data.all)));
         Bar    : Progress_Bars.Progress_Bar renames Progress_Bars.Progress_Bar (Found.all);
      begin
         if Progress_Bars.Value (Bar) /= Wanted then
            Progress_Bars.Set_Value (Bar, Wanted);
         end if;
      end;
   end Refresh;

   overriding procedure Collect (Item : in out Slider_Binding; Within : in out View'Class) is
      Found : constant Widgets.Widget_Access := Resolve (Within, Item.Handle, Custom_Control);
   begin
      if Found /= null and then Item.Ready then
         declare
            Value : constant Float := Widgets.Sliders.Value (Widgets.Sliders.Slider (Found.all));
         begin
            if Value /= Item.Shown then
               Item.Shown := Value;
               Assign (Item.Value.all, Item.Data.all, Value);
            end if;
         end;
      end if;
   end Collect;

   overriding procedure Refresh (Item : in out Slider_Binding; Within : in out View'Class; Forced : Boolean) is
      pragma Unreferenced (Forced);
      Found : constant Widgets.Widget_Access := Resolve (Within, Item.Handle, Custom_Control);
   begin
      if Found /= null then
         declare
            Slider : Widgets.Sliders.Slider renames Widgets.Sliders.Slider (Found.all);
            Wanted : constant Float := Float'Max (0.0, Float'Min (1.0, Current (Item.Value.all, Item.Data.all)));
         begin
            if not Widgets.Sliders.Is_Dragging (Slider) and then Widgets.Sliders.Value (Slider) /= Wanted then
               Widgets.Sliders.Set_Value (Slider, Wanted);
               Within.Touched := True;
            end if;
            Item.Shown := Widgets.Sliders.Value (Slider);
            Item.Ready := True;
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
                  Assign (Item.Text.all, Item.Data.all, Now, Item.Index);
                  Within.Touched := True;
               end if;
            end;
         end if;
      end;
   end Collect;

   overriding procedure Refresh (Item : in out Field_Binding; Within : in out View'Class; Forced : Boolean) is
      Changed : constant Boolean := VM.Changed (Item.Seen, Stamp (Item.Text.all, Item.Data.all, Item.Index));
      Found   : constant Widgets.Widget_Access := Resolve (Within, Item.Handle, Field_Control);
   begin
      if Found = null or else not (Forced or else Changed or else Item.Deferred) then
         return;
      end if;
      declare
         Field  : Text_Fields.Text_Field renames Text_Fields.Text_Field (Found.all);
         Doc    : constant Docs.Document_Access := Within.Controls (Item.Handle.Slot).Document;
         Wanted : constant String := Current (Item.Text.all, Item.Data.all, Item.Index);
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
     (Self : Context; Home : in out Pomarine.UI.View'Class; Handle : Pomarine.UI.Label_Handle; Text : Text_Property;
      Index : Natural := 0)
   is
      Where : constant Subpools.Subpool_Handle := Arena_Of (Home, Self.Scope);
      Made : constant Label_Store := new (Where) Label_Binding;
   begin
      Made.Handle := Handle_Data (Handle);
      Made.Text := Text.Adapter;
      Made.Data := Self.Data;
      Made.Index := Index;
      Add_Binding (Home, Self.Scope, Made.all'Unchecked_Access);
   end Wire_Label;

   procedure Wire_Field
     (Self      : Context;
      Home      : in out Pomarine.UI.View'Class;
      Handle    : Pomarine.UI.Field_Handle;
      Text      : Text_Property;
      Replacing : Replacement;
      Index     : Natural := 0)
   is
      Where : constant Subpools.Subpool_Handle := Arena_Of (Home, Self.Scope);
      Made : constant Field_Store := new (Where) Field_Binding;
   begin
      Made.Handle := Handle_Data (Handle);
      Made.Text := Text.Adapter;
      Made.Data := Self.Data;
      Made.Replacing := Replacing;
      Made.Index := Index;
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

   function Label (Self : Context; Text : Text_Property; Index : Natural := 0) return Pomarine.UI.Label_Handle is
      Home   : constant not null View_Ref := View_Of (Self);
      Handle : constant Pomarine.UI.Label_Handle := New_Label (Home.all, Self.Scope);
   begin
      Wire_Label (Self, Home.all, Handle, Text, Index);
      return Handle;
   end Label;

   function Label (Self : Context; Caption : String) return Pomarine.UI.Label_Handle is
      Home   : constant not null View_Ref := View_Of (Self);
      Handle : constant Pomarine.UI.Label_Handle := New_Label (Home.all, Self.Scope);
   begin
      Labels.Set_Text (Widget_Of (Home.all, Handle).all, Caption);
      return Handle;
   end Label;

   function Button
     (Self    : Context;
      Caption : String;
      Command : Commands.Command;
      Look    : Pomarine.Widgets.Buttons.Kind := Pomarine.Widgets.Buttons.Normal;
      Index   : Natural := 0;
      Focusable : Boolean := False) return Pomarine.UI.Button_Handle
   is
      Home   : constant not null View_Ref := View_Of (Self);
      Handle : constant Pomarine.UI.Button_Handle := New_Button (Home.all, Self.Scope, Caption, Look, Focusable);
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
      Replacing   : Replacement := Caret_At_End;
      Index       : Natural := 0) return Pomarine.UI.Field_Handle
   is
      Home   : constant not null View_Ref := View_Of (Self);
      Handle : constant Pomarine.UI.Field_Handle := New_Field (Home.all, Self.Scope, Placeholder);
   begin
      Wire_Field (Self, Home.all, Handle, Text, Replacing, Index);
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
      Replacing   : Replacement := Caret_At_End;
      Index       : Natural := 0) return Pomarine.UI.Field_Handle
   is
      Home   : constant not null View_Ref := View_Of (Self);
      Handle : constant Pomarine.UI.Field_Handle := New_Field (Home.all, Self.Scope, Placeholder);
   begin
      Wire_Field (Self, Home.all, Handle, Text, Replacing, Index);
      Called (Home.all, Handle_Data (Handle), Field_Control, Name);
      return Handle;
   end Text_Field;

   function Text_Field
     (Self        : Context;
      Text        : Text_Property;
      Submit      : Commands.Command;
      Placeholder : String := "";
      Name        : String := "";
      Replacing   : Replacement := Caret_At_End;
      Index       : Natural := 0) return Pomarine.UI.Field_Handle
   is
      Home   : constant not null View_Ref := View_Of (Self);
      Handle : constant Pomarine.UI.Field_Handle := New_Field (Home.all, Self.Scope, Placeholder);
   begin
      Wire_Field (Self, Home.all, Handle, Text, Replacing, Index);
      Called (Home.all, Handle_Data (Handle), Field_Control, Name);
      Wire_Command (Self, Home.all, Widget_Of (Home.all, Handle).all, Submit, 0, Reflect => False);
      return Handle;
   end Text_Field;

   procedure Wire_Flag
     (Self : Context; Home : in out Pomarine.UI.View'Class; Handle : Handle_Data; Kind : Control_Kind;
      Flag : Flag_Property; Index : Natural := 0; Availability : Boolean := False)
   is
      Where : constant Subpools.Subpool_Handle := Arena_Of (Home, Self.Scope);
      Made  : constant Flag_Store := new (Where) Flag_Binding;
   begin
      Made.Handle := Handle;
      Made.Kind := Kind;
      Made.Index := Index;
      Made.Availability := Availability;
      Made.Flag := Flag.Adapter;
      Made.Data := Self.Data;
      Add_Binding (Home, Self.Scope, Made.all'Unchecked_Access);
   end Wire_Flag;

   procedure Enabled_When
     (Self : Context; Target : Pomarine.UI.Button_Handle; Allowed : Flag_Property; Index : Natural := 0)
   is
      Home : constant not null View_Ref := View_Of (Self);
   begin
      Require_Handle (Home.all, Handle_Data (Target), Button_Control);
      Wire_Flag (Self, Home.all, Handle_Data (Target), Button_Control, Allowed, Index, Availability => True);
   end Enabled_When;

   procedure Selected_When
     (Self : Context; Target : Pomarine.UI.Button_Handle; Selected : Flag_Property; Index : Natural := 0)
   is
      Home : constant not null View_Ref := View_Of (Self);
   begin
      Require_Handle (Home.all, Handle_Data (Target), Button_Control);
      Wire_Flag (Self, Home.all, Handle_Data (Target), Button_Control, Selected, Index);
   end Selected_When;

   function Check
     (Self    : Context;
      Caption : String;
      Checked : Flag_Property;
      Command : Commands.Command;
      Form    : Pomarine.Widgets.Checks.Kind := Pomarine.Widgets.Checks.Box;
      Index   : Natural := 0;
      Name    : String := "") return Pomarine.UI.Check_Handle
   is
      Home   : constant not null View_Ref := View_Of (Self);
      Handle : constant Pomarine.UI.Check_Handle := New_Check (Home.all, Self.Scope, Caption, Form);
   begin
      Wire_Flag (Self, Home.all, Handle_Data (Handle), Check_Control, Checked, Index);
      Wire_Command (Self, Home.all, Widget_Of (Home.all, Handle).all, Command, Index, Reflect => True);
      Called (Home.all, Handle_Data (Handle), Check_Control, Name);
      return Handle;
   end Check;

   function Check
     (Self    : Context;
      Caption : String;
      Checked : Flag_Property;
      Form    : Pomarine.Widgets.Checks.Kind := Pomarine.Widgets.Checks.Box;
      Name    : String := "") return Pomarine.UI.Check_Handle
   is
      Home   : constant not null View_Ref := View_Of (Self);
      Handle : constant Pomarine.UI.Check_Handle := New_Check (Home.all, Self.Scope, Caption, Form);
   begin
      Wire_Flag (Self, Home.all, Handle_Data (Handle), Check_Control, Checked);
      Called (Home.all, Handle_Data (Handle), Check_Control, Name);
      return Handle;
   end Check;

   function Button
     (Self    : Context;
      Look    : Pomarine.Widgets.Buttons.Settings;
      Command : Commands.Command;
      Index   : Natural := 0;
      Reflect : Boolean := True) return Pomarine.UI.Button_Handle
   is
      Home   : constant not null View_Ref := View_Of (Self);
      Handle : constant Pomarine.UI.Button_Handle := New_Button (Home.all, Self.Scope, Look);
   begin
      Wire_Command (Self, Home.all, Widget_Of (Home.all, Handle).all, Command, Index, Reflect => Reflect);
      return Handle;
   end Button;

   function Grip
     (Self    : Context;
      Look    : Pomarine.UI.Grip_Look;
      Command : Commands.Command;
      Index   : Natural := 0;
      Name    : String := "") return Pomarine.UI.Grip_Handle
   is
      Home   : constant not null View_Ref := View_Of (Self);
      Handle : constant Pomarine.UI.Grip_Handle := New_Grip (Home.all, Self.Scope, Look);
   begin
      Wire_Command (Self, Home.all, Widget_Of (Home.all, Handle).all, Command, Index, Reflect => False);
      Called (Home.all, Handle_Data (Handle), Grip_Control, Name);
      return Handle;
   end Grip;

   function Plain_Grip (Self : Context; Look : Pomarine.UI.Grip_Look) return Pomarine.UI.Grip_Handle is
      Home : constant not null View_Ref := View_Of (Self);
   begin
      return New_Grip (Home.all, Self.Scope, Look, Unheard => True);
   end Plain_Grip;

   function Plain_Button
     (Self : Context; Look : Pomarine.Widgets.Buttons.Settings) return Pomarine.UI.Button_Handle
   is
      Home : constant not null View_Ref := View_Of (Self);
   begin
      return New_Button (Home.all, Self.Scope, Look, Unheard => True);
   end Plain_Button;

   function Switch
     (Self    : Context;
      Caption : String;
      On      : Flag_Property;
      Command : Commands.Command;
      Index   : Natural := 0;
      Name    : String := "") return Pomarine.UI.Switch_Handle
   is
      Home   : constant not null View_Ref := View_Of (Self);
      Handle : constant Pomarine.UI.Switch_Handle := New_Switch (Home.all, Self.Scope, Caption);
   begin
      Wire_Flag (Self, Home.all, Handle_Data (Handle), Switch_Control, On, Index);
      Wire_Command (Self, Home.all, Widget_Of (Home.all, Handle).all, Command, Index, Reflect => True);
      Called (Home.all, Handle_Data (Handle), Switch_Control, Name);
      return Handle;
   end Switch;

   function Progress (Self : Context; Done : Fraction_Property) return Pomarine.UI.Progress_Handle is
      Home   : constant not null View_Ref := View_Of (Self);
      Handle : constant Pomarine.UI.Progress_Handle := New_Progress (Home.all, Self.Scope);
      Where  : constant Subpools.Subpool_Handle := Arena_Of (Home.all, Self.Scope);
      Made   : constant Progress_Store := new (Where) Progress_Binding;
   begin
      Made.Handle := Handle_Data (Handle);
      Made.Done := Done.Adapter;
      Made.Data := Self.Data;
      Add_Binding (Home.all, Self.Scope, Made.all'Unchecked_Access);
      return Handle;
   end Progress;

   procedure Focus_When
     (Self : Context; Target : Pomarine.UI.Focus_Target; Raised : Flag_Property; Index : Natural := 0)
   is
      Home  : constant not null View_Ref := View_Of (Self);
      Where : constant Subpools.Subpool_Handle := Arena_Of (Home.all, Self.Scope);
      Made  : constant Focus_Store := new (Where) Focus_Binding;
   begin
      Require_Open (Home.all, Self.Scope);
      Made.Handle := Data_Of (Target);
      Made.Flag := Raised.Adapter;
      Made.Data := Self.Data;
      Made.Index := Index;
      Add_Binding (Home.all, Self.Scope, Made.all'Unchecked_Access);
   end Focus_When;

   procedure Show_When
     (Self : Context; Target : Pomarine.UI.Control_Ref; Shown : Flag_Property; Index : Natural := 0) is
      Home  : constant not null View_Ref := View_Of (Self);
      Where : constant Subpools.Subpool_Handle := Arena_Of (Home.all, Self.Scope);
      Made  : constant Shown_Store := new (Where) Shown_Binding;
   begin
      Require_Open (Home.all, Self.Scope);
      Made.Handle := Data_Of (Target);
      Made.Flag := Shown.Adapter;
      Made.Index := Index;
      Made.Data := Self.Data;
      Add_Binding (Home.all, Self.Scope, Made.all'Unchecked_Access);
   end Show_When;

   procedure Show_When
     (Self : Context; Target : Pomarine.UI.Layout; Shown : Flag_Property; Index : Natural := 0) is
      Home  : constant not null View_Ref := View_Of (Self);
      Where : constant Subpools.Subpool_Handle := Arena_Of (Home.all, Self.Scope);
      Made  : constant Panel_Store := new (Where) Panel_Binding;
   begin
      Require_Open (Home.all, Self.Scope);
      Made.Screen := Target;
      Made.Flag := Shown.Adapter;
      Made.Index := Index;
      Made.Data := Self.Data;
      Add_Binding (Home.all, Self.Scope, Made.all'Unchecked_Access);
   end Show_When;

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
      Require_Handle (Home.all, Data_Of (Target), List_Control);
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
      Index    : Natural := 0;
      Reflect  : Boolean := True) return Pomarine.UI.Button_Handle
   is
      Home   : constant not null View_Ref := View_Of (Self);
      Handle : constant Pomarine.UI.Button_Handle := Pomarine.UI.Borrow_Button (Home.all, Self.Scope, Existing);
   begin
      Wire_Command (Self, Home.all, Existing, Command, Index, Reflect => Reflect);
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

   procedure On_Frame_Event
     (Self : Context; Target : in out Widgets.Frames.Frame; Kind : Widgets.Event_Kind;
      Command : Commands.Command; Index : Natural := 0)
   is
      Home : constant not null View_Ref := View_Of (Self);
   begin
      Require_Open (Home.all, Self.Scope);
      if Kind not in Widgets.Double_Click | Widgets.Submit | Widgets.Blur | Widgets.Minimize
        | Widgets.Restore | Widgets.Close
      then
         raise Program_Error with "frame command requires a discrete event";
      end if;
      for Binding of Home.Bindings loop
         if Binding /= null and then Binding.all in Event_Command_Binding'Class then
            declare
               Other : Event_Command_Binding renames Event_Command_Binding (Binding.all);
               use type Widgets.Event_Kind;
            begin
               if Other.Frame = Target'Unrestricted_Access and then Other.Kind = Kind then
                  raise Program_Error with "frame event already bound";
               end if;
            end;
         end if;
      end loop;
      declare
         Where : constant Subpools.Subpool_Handle := Arena_Of (Home.all, Self.Scope);
         Made : constant Event_Command_Store := new (Where) Event_Command_Binding;
      begin
         Made.Which := Commands.Command'Pos (Command);
         Made.Data := Self.Data;
         Made.Tag := Command_Tag (Home.all);
         Made.Home := Home;
         Made.Frame := Target'Unrestricted_Access;
         Made.Kind := Kind;
         Made.Index := Index;
         Add_Binding (Home.all, Self.Scope, Made.all'Unchecked_Access);
         Frame_Callbacks.On (Target, Kind, Made.all'Unchecked_Access, Event_Heard'Access);
      end;
   end On_Frame_Event;

   procedure On_Event
     (Self : Context; Target : Pomarine.UI.Widget_Handle; Kind : Widgets.Event_Kind;
      Command : Commands.Command; Index : Natural := 0; Index_From_Event : Boolean := False)
   is
      Home : constant not null View_Ref := View_Of (Self);
      Handle : constant Handle_Data := Handle_Data (Target);
   begin
      Require_Open (Home.all, Self.Scope);
      Require_Handle (Home.all, Handle, Custom_Control);
      if Home.Controls (Handle.Slot).Scope /= Self.Scope.Slot then
         raise Program_Error with "event binding must belong to the control's scope";
      end if;
      declare
         Found : constant Widgets.Widget_Access := Resolve (Home.all, Handle, Custom_Control);
      begin
         for Binding of Home.Bindings loop
            if Binding /= null and then Binding.all in Event_Command_Binding'Class then
               declare
                  Other : Event_Command_Binding renames Event_Command_Binding (Binding.all);
                  use type Widgets.Event_Kind;
               begin
                  if Other.Target = Found and then Other.Kind = Kind then
                     raise Program_Error with "widget event already bound";
                  end if;
               end;
            end if;
         end loop;
         declare
            Where : constant Subpools.Subpool_Handle := Arena_Of (Home.all, Self.Scope);
            Made : constant Event_Command_Store := new (Where) Event_Command_Binding;
         begin
            Made.Which := Commands.Command'Pos (Command);
            Made.Data := Self.Data;
            Made.Tag := Command_Tag (Home.all);
            Made.Home := Home;
            Made.Target := Found;
            Made.Kind := Kind;
            Made.Index := Index;
            Made.Index_From_Event := Index_From_Event;
            Add_Binding (Home.all, Self.Scope, Made.all'Unchecked_Access);
            Event_Callbacks.On (Found.all, Kind, Made.all'Unchecked_Access, Event_Heard'Access);
         end;
      end;
   end On_Event;

   function Borrow_Slider
     (Self : Context; Existing : in out Widgets.Sliders.Slider; Value : Fraction_Property)
      return Pomarine.UI.Widget_Handle
   is
      Home : constant not null View_Ref := View_Of (Self);
      Handle : constant Pomarine.UI.Widget_Handle := Pomarine.UI.Borrow_Widget (Home.all, Self.Scope, Existing);
      Where : constant Subpools.Subpool_Handle := Arena_Of (Home.all, Self.Scope);
      Made : constant Slider_Store := new (Where) Slider_Binding;
   begin
      Made.Handle := Handle_Data (Handle);
      Made.Value := Value.Adapter;
      Made.Data := Self.Data;
      Add_Binding (Home.all, Self.Scope, Made.all'Unchecked_Access);
      Home.Controls (Made.Handle.Slot).Handled := Widgets.Change;
      Home.Controls (Made.Handle.Slot).Heard := True;
      Syncing.Install (Home.all, Existing, Widgets.Change, Edits_Only => True);
      return Handle;
   end Borrow_Slider;

   function Borrow_Widget
     (Self : Context; Existing : in out Pomarine.Widgets.Widget'Class) return Pomarine.UI.Widget_Handle
   is
      Home : constant not null View_Ref := View_Of (Self);
   begin
      return Pomarine.UI.Borrow_Widget (Home.all, Self.Scope, Existing);
   end Borrow_Widget;

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
