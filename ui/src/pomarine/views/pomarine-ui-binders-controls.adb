with Ada.Strings.Unbounded;
with Pomarine.Text_Areas;
with Pomarine.UI.Arenas;
with Pomarine.UI.Syncing;
with Pomarine.Widgets.Canvases;
with Pomarine.Widgets.Canvases.Callbacks;
with Pomarine.Widgets.Editors.Callbacks;
with Pomarine.Widgets.Bindings;
with Pomarine.Widgets.Callbacks;
with Pomarine.Widgets.Frames.Handlers;
with Pomarine.Widgets.Progress_Bars;
with Pomarine.Widgets.Switches;

package body Pomarine.UI.Binders.Controls is

   package Buttons renames Pomarine.Widgets.Buttons;
   package Labels renames Pomarine.Widgets.Labels;
   package Checks renames Pomarine.Widgets.Checks;
   package Lists renames Pomarine.Widgets.Lists;
   package Progress_Bars renames Pomarine.Widgets.Progress_Bars;
   package Switches renames Pomarine.Widgets.Switches;
   package Text_Fields renames Pomarine.Widgets.Text_Fields;

   use type Widgets.Widget_Access;

   --  What is kept of a binding. Each is allocated in the arena of its scope, with
   --  pointers to the adapters (library level) and the model (borrowed), and the
   --  handles of the widgets, which it checks before it uses them: a record of a
   --  scope outlives nothing, but it does not take it on trust.

   type Text_Binding is new Pomarine.UI.Binding with record
      Kind   : Control_Kind := Label_Control;
      Index  : Natural := 0;
      Handle : Handle_Data;
      Text   : Text_Adapter_Ref;
      Data   : System.Address := System.Null_Address;
      Seen   : VM.Watch;
   end record;

   overriding
   procedure Refresh (Item : in out Text_Binding; Within : in out View'Class; Forced : Boolean);

   type Field_Binding is new Pomarine.UI.Binding with record
      Index     : Natural := 0;
      Handle    : Handle_Data;
      Text      : Text_Adapter_Ref;
      Data      : System.Address := System.Null_Address;
      Seen      : VM.Watch;
      Link      : Widgets.Bindings.Text_Link;
      Deferred  : Boolean := False;
      --  The model's text is not yet shown: the person is composing.
      Known     : Ada.Strings.Unbounded.Unbounded_String;
      --  The text the field and the model last agreed on: what was shown, or what the person's edit gave.
      --  A change of the document to the same text (an input method cancelled, an edit undone) is no edit.
      Replacing : Replacement := Caret_At_End;
   end record;

   overriding
   procedure Collect (Item : in out Field_Binding; Within : in out View'Class);
   overriding
   procedure Refresh (Item : in out Field_Binding; Within : in out View'Class; Forced : Boolean);

   type Command_Binding is new Pomarine.UI.Binding with record
      Which  : Natural := 0;
      --  The number of the command, or not used if there is an Action.
      Action : Action_Adapter_Ref;
      Hooks  : Hooks_Ref;
      Data   : System.Address := System.Null_Address;
   end record;

   overriding
   function Can_Execute (Item : Command_Binding; Index : Natural) return Boolean;
   overriding
   procedure Execute (Item : in out Command_Binding; Index : Natural);
   overriding
   function Key (Item : Command_Binding) return Command_Key;
   overriding
   function Is_Command (Item : Command_Binding) return Boolean;

   type Action_Tags is array (1 .. Pomarine.Models.Max_Actions) of Integer;
   type Frame_Ref is access all Widgets.Frames.Frame;
   type Event_Command_Binding is new Command_Binding with record
      Home             : View_Ref;
      Target           : Widgets.Widget_Access;
      Frame            : Frame_Ref;
      Kind             : Widgets.Event_Kind := Widgets.Click;
      Index            : Natural := 0;
      Index_From_Event : Boolean := False;
      Row_Actions      : Boolean := False;
      Tags             : Action_Tags := [others => 0];
      Hooked           : Boolean := False;
      --  The binding is of an editor's or a canvas's hook, not of its Kind of event.
      Canvased         : Boolean := False;
      --  Of a canvas's: Line_Hook is the hook, not Hook.
      Hook             : Editor_Hook := Tool_Used;
      Line_Hook        : Canvas_Hook := Line_Selected;
   end record;
   overriding
   procedure Detach (Item : in out Event_Command_Binding; Within : in out View'Class);
   package Event_Callbacks is new Widgets.Callbacks (Event_Command_Binding);
   package Frame_Callbacks is new Widgets.Frames.Handlers (Event_Command_Binding);
   package Editor_Callbacks is new Widgets.Editors.Callbacks (Event_Command_Binding);
   package Canvas_Callbacks is new Widgets.Canvases.Callbacks (Event_Command_Binding);
   type Event_Command_Store is access Event_Command_Binding;
   for Event_Command_Store'Storage_Pool use Pomarine.UI.Arenas.Pool;

   procedure Event_Heard
     (Self : in out Event_Command_Binding; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event)
   is
      Tag   : Integer := Self.Tag;
      Index : Natural := Self.Index;
   begin
      if Self.Row_Actions then
         if Event.Action not in Self.Tags'Range or else Self.Tags (Event.Action) = 0 or else Event.Row = 0 then
            return;
         end if;
         Tag := Self.Tags (Event.Action);
         Index := Event.Row;
      elsif Self.Index_From_Event then
         if Source in Lists.List'Class and then Event.Kind in Widgets.Click | Widgets.Submit then
            Index := Lists.Selected (Lists.List (Source));
            if Index = 0 then
               return;
            end if;
         else
            Index := (if Event.Kind in Widgets.Choose | Widgets.Act then Event.Row else Event.Index);
         end if;
      end if;
      Syncing.Hear (Self.Home.all, (Kind => Widgets.Click, Tag => Tag, Index => Index));
   end Event_Heard;

   procedure Tool_Heard
     (Self : in out Event_Command_Binding; Source : in out Widgets.Editors.Editor'Class; Tool : Positive)
   is
      pragma Unreferenced (Source);
   begin
      Syncing.Hear
        (Self.Home.all,
         (Kind  => Widgets.Click,
          Tag   => Self.Tag,
          Index => (if Self.Index_From_Event then Self.Index * Widgets.Editors.Tool_Capacity + Tool else Self.Index)));
   end Tool_Heard;

   procedure Line_Selected_Heard
     (Self : in out Event_Command_Binding; Source : in out Widgets.Canvases.Canvas'Class; Tag : Natural)
   is
      pragma Unreferenced (Source);
   begin
      Syncing.Hear
        (Self.Home.all,
         (Kind => Widgets.Click, Tag => Self.Tag, Index => (if Self.Index_From_Event then Tag else Self.Index)));
   end Line_Selected_Heard;

   procedure Line_Deleted_Heard (Self : in out Event_Command_Binding; Source : in out Widgets.Canvases.Canvas'Class) is
      pragma Unreferenced (Source);
   begin
      Syncing.Hear (Self.Home.all, (Kind => Widgets.Click, Tag => Self.Tag, Index => Self.Index));
   end Line_Deleted_Heard;

   procedure Link_Heard (Self : in out Event_Command_Binding; Source : in out Widgets.Editors.Editor'Class) is
      pragma Unreferenced (Source);
   begin
      Syncing.Hear (Self.Home.all, (Kind => Widgets.Click, Tag => Self.Tag, Index => Self.Index));
   end Link_Heard;

   overriding
   procedure Detach (Item : in out Event_Command_Binding; Within : in out View'Class) is
      pragma Unreferenced (Within);
   begin
      if Item.Canvased and then Item.Target /= null then
         declare
            Hooked : Widgets.Canvases.Canvas'Class renames Widgets.Canvases.Canvas'Class (Item.Target.all);
         begin
            case Item.Line_Hook is
               when Line_Selected =>
                  Canvas_Callbacks.Off_Select (Hooked);

               when Line_Deleted  =>
                  Canvas_Callbacks.Off_Delete (Hooked);
            end case;
         end;
         Item.Target := null;
         return;
      elsif Item.Hooked and then Item.Target /= null then
         declare
            Hooked : Widgets.Editors.Editor'Class renames Widgets.Editors.Editor'Class (Item.Target.all);
         begin
            case Item.Hook is
               when Tool_Used     =>
                  Editor_Callbacks.Off_Tool (Hooked);

               when Link_Followed =>
                  Editor_Callbacks.Off_Follow (Hooked);

               when Link_Asked    =>
                  Editor_Callbacks.Off_Ask_Link (Hooked);
            end case;
         end;
         Item.Target := null;
         return;
      end if;
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
      Handle : Handle_Data;
      Choice : Choice_Adapter_Ref;
      Data   : System.Address := System.Null_Address;
      Seen   : VM.Watch;
      Last   : Natural := 0;
      --  The id of the chosen row as the model and the list last agreed.
   end record;

   overriding
   procedure Collect (Item : in out List_Binding; Within : in out View'Class);
   overriding
   procedure Refresh (Item : in out List_Binding; Within : in out View'Class; Forced : Boolean);

   type Reveal_Binding is new Pomarine.UI.Binding with record
      Handle : Handle_Data;
      Count  : Count_Adapter_Ref;
      Data   : System.Address := System.Null_Address;
      After  : Command_Key;
      Before : Natural := 0;
   end record;

   overriding
   procedure Before_Command (Item : in out Reveal_Binding; Which : Command_Key);
   overriding
   procedure After_Command (Item : in out Reveal_Binding; Which : Command_Key);

   type Flag_Binding is new Pomarine.UI.Binding with record
      Index        : Natural := 0;
      Handle       : Handle_Data;
      Kind         : Control_Kind;
      Flag         : Flag_Adapter_Ref;
      Data         : System.Address := System.Null_Address;
      Known        : Boolean := False;
      Availability : Boolean := False;
      --  What the widget and the model last agreed on, for a flag the person can set.
   end record;

   overriding
   procedure Collect (Item : in out Flag_Binding; Within : in out View'Class);
   overriding
   procedure Refresh (Item : in out Flag_Binding; Within : in out View'Class; Forced : Boolean);

   type Shown_Binding is new Pomarine.UI.Binding with record
      Index  : Natural := 0;
      Handle : Handle_Data;
      Flag   : Flag_Adapter_Ref;
      Data   : System.Address := System.Null_Address;
   end record;

   overriding
   procedure Refresh (Item : in out Shown_Binding; Within : in out View'Class; Forced : Boolean);

   type Panel_Binding is new Pomarine.UI.Binding with record
      Index  : Natural := 0;
      Screen : Pomarine.UI.Layout;
      Flag   : Flag_Adapter_Ref;
      Data   : System.Address := System.Null_Address;
   end record;

   overriding
   procedure Refresh (Item : in out Panel_Binding; Within : in out View'Class; Forced : Boolean);

   type Focus_Binding is new Pomarine.UI.Binding with record
      Index  : Natural := 0;
      Handle : Handle_Data;
      Flag   : Flag_Adapter_Ref;
      Data   : System.Address := System.Null_Address;
      Raised : Boolean := False;
      --  Whether the flag was true when last looked at.
   end record;

   overriding
   procedure Refresh (Item : in out Focus_Binding; Within : in out View'Class; Forced : Boolean);

   type Progress_Binding is new Pomarine.UI.Binding with record
      Handle : Handle_Data;
      Done   : Fraction_Adapter_Ref;
      Data   : System.Address := System.Null_Address;
   end record;

   overriding
   procedure Refresh (Item : in out Progress_Binding; Within : in out View'Class; Forced : Boolean);

   type Slider_Binding is new Pomarine.UI.Binding with record
      Handle : Handle_Data;
      Value  : Fraction_Adapter_Ref;
      Data   : System.Address := System.Null_Address;
      Shown  : Float := 0.0;
      Ready  : Boolean := False;
   end record;
   overriding
   procedure Collect (Item : in out Slider_Binding; Within : in out View'Class);
   overriding
   procedure Refresh (Item : in out Slider_Binding; Within : in out View'Class; Forced : Boolean);
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

   type Text_Store is access Text_Binding;
   for Text_Store'Storage_Pool use Pomarine.UI.Arenas.Pool;
   type Field_Store is access Field_Binding;
   for Field_Store'Storage_Pool use Pomarine.UI.Arenas.Pool;
   type Command_Store is access Command_Binding;
   for Command_Store'Storage_Pool use Pomarine.UI.Arenas.Pool;
   type List_Store is access List_Binding;
   for List_Store'Storage_Pool use Pomarine.UI.Arenas.Pool;
   type Reveal_Store is access Reveal_Binding;
   for Reveal_Store'Storage_Pool use Pomarine.UI.Arenas.Pool;

   --  Labels and button captions share the same versioned text adapter.

   overriding
   procedure Refresh (Item : in out Text_Binding; Within : in out View'Class; Forced : Boolean) is
      Changed : constant Boolean := VM.Changed (Item.Seen, Stamp (Item.Text.all, Item.Data, Item.Index));
      Found   : constant Widgets.Widget_Access := Resolve (Within, Item.Handle, Item.Kind);
   begin
      if Found /= null and then (Forced or else Changed) then
         declare
            Now : constant String := Current (Item.Text.all, Item.Data, Item.Index);
         begin
            case Item.Kind is
               when Label_Control  =>
                  if Labels.Text (Labels.Label (Found.all)) /= Now then
                     Labels.Set_Text (Labels.Label (Found.all), Now);
                     Within.Touched := True;
                  end if;

               when Button_Control =>
                  if Buttons.Label (Buttons.Button (Found.all)) /= Now then
                     Buttons.Set_Label (Buttons.Button (Found.all), Now);
                     Within.Touched := True;
                  end if;

               when others         =>
                  raise Program_Error with "a text binding needs a label or button";
            end case;
         end;
      end if;
   end Refresh;

   --  Check, switch, visibility, progress. These compare with the widget at every turn: they are cheap,
   --  and a click that the model did not take is undone.

   function Shown_By (Found : Widgets.Widget_Access; Kind : Control_Kind) return Boolean
   is (if Kind = Button_Control
       then Buttons.Is_Selected (Buttons.Button (Found.all))
       elsif Kind = Check_Control
       then Checks.Is_Checked (Checks.Check (Found.all))
       else Switches.Is_On (Switches.Switch (Found.all)));

   overriding
   procedure Collect (Item : in out Flag_Binding; Within : in out View'Class) is
      Found : constant Widgets.Widget_Access := Resolve (Within, Item.Handle, Item.Kind);
   begin
      if Found /= null
        and then Item.Kind /= Button_Control
        and then Item.Flag.Can_Assign
        and then Shown_By (Found, Item.Kind) /= Item.Known
      then
         Item.Known := Shown_By (Found, Item.Kind);
         Assign (Item.Flag.all, Item.Data, Item.Known, Item.Index);
         Within.Touched := True;
      end if;
   end Collect;

   overriding
   procedure Refresh (Item : in out Flag_Binding; Within : in out View'Class; Forced : Boolean) is
      pragma Unreferenced (Forced);
      Found : constant Widgets.Widget_Access := Resolve (Within, Item.Handle, Item.Kind);
   begin
      if Found = null then
         return;
      end if;
      declare
         Wanted : constant Boolean := Current (Item.Flag.all, Item.Data, Item.Index);
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

   overriding
   procedure Refresh (Item : in out Shown_Binding; Within : in out View'Class; Forced : Boolean) is
      pragma Unreferenced (Forced);
      Slot : constant Natural := Item.Handle.Slot;
   begin
      if Item.Handle.View /= Within.Number
        or else Slot not in 1 .. Natural (Within.Controls.Length)
        or else Within.Controls (Slot).Kind = Free_Slot
        or else Within.Controls (Slot).Generation /= Item.Handle.Generation
      then
         return;
      end if;
      declare
         Found  : constant Widgets.Widget_Access := Within.Controls (Slot).Widget;
         Wanted : constant Boolean := Current (Item.Flag.all, Item.Data, Item.Index);
      begin
         if Widgets.Is_Visible (Found.all) /= Wanted then
            Widgets.Set_Visible (Found.all, Wanted);
            Within.Touched := True;
         end if;
      end;
   end Refresh;

   overriding
   procedure Refresh (Item : in out Panel_Binding; Within : in out View'Class; Forced : Boolean) is
      pragma Unreferenced (Forced);
   begin
      if Item.Screen.Node = null or else Item.Screen.Node.Made = null or else not Is_Live (Within, Item.Screen) then
         return;
      end if;
      declare
         Found  : constant Widgets.Widget_Access := Item.Screen.Node.Made;
         Wanted : constant Boolean := Current (Item.Flag.all, Item.Data, Item.Index);
      begin
         if Widgets.Is_Visible (Found.all) /= Wanted then
            Widgets.Set_Visible (Found.all, Wanted);
            Within.Touched := True;
         end if;
      end;
   end Refresh;

   overriding
   procedure Refresh (Item : in out Focus_Binding; Within : in out View'Class; Forced : Boolean) is
      pragma Unreferenced (Forced);
      Now   : constant Boolean := Current (Item.Flag.all, Item.Data, Item.Index);
      Found : Widgets.Widget_Access := Resolve (Within, Item.Handle, Field_Control);
   begin
      if Now and then not Item.Raised then
         if Found = null then
            Found := Resolve (Within, Item.Handle, Button_Control);
         end if;
         if Found /= null and then Widgets.Is_Attached (Found.all) and then Widgets.Is_Showing (Found.all) then
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

   overriding
   procedure Refresh (Item : in out Progress_Binding; Within : in out View'Class; Forced : Boolean) is
      pragma Unreferenced (Forced);
      Found : constant Widgets.Widget_Access := Resolve (Within, Item.Handle, Progress_Control);
   begin
      if Found = null then
         return;
      end if;
      declare
         Wanted : constant Float := Float'Max (0.0, Float'Min (1.0, Current (Item.Done.all, Item.Data)));
         Bar    : Progress_Bars.Progress_Bar renames Progress_Bars.Progress_Bar (Found.all);
      begin
         if Progress_Bars.Value (Bar) /= Wanted then
            Progress_Bars.Set_Value (Bar, Wanted);
         end if;
      end;
   end Refresh;

   overriding
   procedure Collect (Item : in out Slider_Binding; Within : in out View'Class) is
      Found : constant Widgets.Widget_Access := Resolve (Within, Item.Handle, Custom_Control);
   begin
      if Found /= null and then Item.Ready then
         declare
            Value : constant Float := Widgets.Sliders.Value (Widgets.Sliders.Slider (Found.all));
         begin
            if Value /= Item.Shown then
               Item.Shown := Value;
               Assign (Item.Value.all, Item.Data, Value);
            end if;
         end;
      end if;
   end Collect;

   overriding
   procedure Refresh (Item : in out Slider_Binding; Within : in out View'Class; Forced : Boolean) is
      pragma Unreferenced (Forced);
      Found : constant Widgets.Widget_Access := Resolve (Within, Item.Handle, Custom_Control);
   begin
      if Found /= null then
         declare
            Slider : Widgets.Sliders.Slider renames Widgets.Sliders.Slider (Found.all);
            Wanted : constant Float := Float'Max (0.0, Float'Min (1.0, Current (Item.Value.all, Item.Data)));
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

   function Is_Composing (Field : in out Text_Fields.Text_Field) return Boolean
   is (Text_Areas.Is_Composing (Widgets.Editors.Area (Widgets.Editors.Editor (Field)).all));

   procedure Place_Caret
     (Field : in out Text_Fields.Text_Field; Doc : Docs.Document; Rule : Replacement; Before : Texts.Position)
   is
      Where : Texts.Position := Docs.Text_End (Doc);
   begin
      case Rule is
         when Caret_At_End   =>
            null;

         when Caret_At_Start =>
            Where := (Paragraph => 1, Index => 1);

         when Caret_Kept     =>
            if Docs.Is_Position (Doc, (Paragraph => 1, Index => Before.Index)) then
               Where := (Paragraph => 1, Index => Before.Index);
            end if;
      end case;
      Text_Areas.Select_Range (Widgets.Editors.Area (Widgets.Editors.Editor (Field)).all, Where, Where);
   end Place_Caret;

   overriding
   procedure Collect (Item : in out Field_Binding; Within : in out View'Class) is
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
                  Assign (Item.Text.all, Item.Data, Now, Item.Index);
                  Within.Touched := True;
               end if;
            end;
         end if;
      end;
   end Collect;

   overriding
   procedure Refresh (Item : in out Field_Binding; Within : in out View'Class; Forced : Boolean) is
      Changed : constant Boolean := VM.Changed (Item.Seen, Stamp (Item.Text.all, Item.Data, Item.Index));
      Found   : constant Widgets.Widget_Access := Resolve (Within, Item.Handle, Field_Control);
   begin
      if Found = null or else not (Forced or else Changed or else Item.Deferred) then
         return;
      end if;
      declare
         Field  : Text_Fields.Text_Field renames Text_Fields.Text_Field (Found.all);
         Doc    : constant Docs.Document_Access := Within.Controls (Item.Handle.Slot).Document;
         Wanted : constant String := Current (Item.Text.all, Item.Data, Item.Index);
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

   overriding
   function Can_Execute (Item : Command_Binding; Index : Natural) return Boolean
   is (if Item.Action /= null
       then Index = 0 and then May_Perform (Item.Action.all, Item.Data)
       else Item.Hooks.Can_Execute (Item.Data, Item.Which, Index));

   overriding
   procedure Execute (Item : in out Command_Binding; Index : Natural) is
   begin
      if Item.Action /= null then
         Run_Action (Item.Action.all, Item.Data);
      else
         Item.Hooks.Execute (Item.Data, Item.Which, Index);
      end if;
   end Execute;

   overriding
   function Key (Item : Command_Binding) return Command_Key
   is ((Model => Item.Data, Which => (if Item.Action = null then Item.Which else Natural'Last)));
   --  An action has no number: it is no command that an effect (Reveal_After) can be about.

   overriding
   function Is_Command (Item : Command_Binding) return Boolean is
      pragma Unreferenced (Item);
   begin
      return True;
   end Is_Command;

   --  List

   overriding
   procedure Collect (Item : in out List_Binding; Within : in out View'Class) is
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
            Choose (Item.Choice.all, Item.Data, Now);
            Within.Touched := True;
         end if;
      end;
   end Collect;

   overriding
   procedure Refresh (Item : in out List_Binding; Within : in out View'Class; Forced : Boolean) is
      Changed : constant Boolean := VM.Changed (Item.Seen, Stamp (Item.Choice.all, Item.Data));
      Found   : constant Widgets.Widget_Access := Resolve (Within, Item.Handle, List_Control);
   begin
      if Found /= null and then (Forced or else Changed) then
         declare
            Shown  : Lists.List renames Lists.List (Found.all);
            Wanted : constant Natural := Chosen (Item.Choice.all, Item.Data);
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

   overriding
   procedure Before_Command (Item : in out Reveal_Binding; Which : Command_Key) is
   begin
      if Which = Item.After then
         Item.Before := Current (Item.Count.all, Item.Data);
      end if;
   end Before_Command;

   overriding
   procedure After_Command (Item : in out Reveal_Binding; Which : Command_Key) is
   begin
      if Which = Item.After then
         declare
            Now : constant Natural := Current (Item.Count.all, Item.Data);
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

   --  Making a command binding for a widget that triggers it.

   procedure Wire_Command
     (Self    : Context'Class;
      Home    : in out Pomarine.UI.View'Class;
      Widget  : in out Widgets.Widget'Class;
      Which   : Natural;
      Index   : Natural;
      Reflect : Boolean;
      Action  : Action_Adapter_Ref := null)
   is
      Where : constant Subpools.Subpool_Handle := Arena_Of (Home, Self.Scope);
      Made  : constant Command_Store := new (Where) Command_Binding;
   begin
      Made.Which := Which;
      Made.Action := Action;
      Made.Hooks := Self.Hooks;
      Made.Data := Self.Data;
      Made.Tag := Command_Tag (Home);
      Add_Binding (Home, Self.Scope, Made.all'Unchecked_Access);
      Widgets.Set_Tag (Widget, Made.Tag, Index, Reflects => Reflect);
   end Wire_Command;

   procedure Wire_Label
     (Self   : Context'Class;
      Home   : in out Pomarine.UI.View'Class;
      Handle : Pomarine.UI.Label_Handle;
      Text   : not null Text_Adapter_Ref;
      Index  : Natural := 0)
   is
      Where : constant Subpools.Subpool_Handle := Arena_Of (Home, Self.Scope);
      Made  : constant Text_Store := new (Where) Text_Binding;
   begin
      Made.Handle := Handle_Data (Handle);
      Made.Text := Text;
      Made.Data := Self.Data;
      Made.Index := Index;
      Add_Binding (Home, Self.Scope, Made.all'Unchecked_Access);
   end Wire_Label;

   procedure Wire_Field
     (Self      : Context'Class;
      Home      : in out Pomarine.UI.View'Class;
      Handle    : Pomarine.UI.Field_Handle;
      Text      : not null Text_Adapter_Ref;
      Replacing : Replacement;
      Index     : Natural := 0)
   is
      Where : constant Subpools.Subpool_Handle := Arena_Of (Home, Self.Scope);
      Made  : constant Field_Store := new (Where) Field_Binding;
   begin
      Made.Handle := Handle_Data (Handle);
      Made.Text := Text;
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
     (Self      : Context'Class;
      Home      : in out Pomarine.UI.View'Class;
      Handle    : Pomarine.UI.List_Handle;
      Rows      : not null Rows_Adapter_Ref;
      Selection : not null Choice_Adapter_Ref)
   is
      Where : constant Subpools.Subpool_Handle := Arena_Of (Home, Self.Scope);
      Made  : constant List_Store := new (Where) List_Binding;
   begin
      Lists.Set_Model (Widget_Of (Home, Handle).all, Rows_Of (Rows.all, Self.Data));
      Made.Handle := Handle_Data (Handle);
      Made.Choice := Selection;
      Made.Data := Self.Data;
      Add_Binding (Home, Self.Scope, Made.all'Unchecked_Access);
   end Wire_List;

   procedure Called (Home : in out Pomarine.UI.View'Class; Handle : Handle_Data; Kind : Control_Kind; Name : String) is
   begin
      if Name /= "" then
         Widgets.Set_Accessible_Name (Resolve (Home, Handle, Kind).all, Name);
      end if;
   end Called;

   procedure Look_Of
     (Home   : in out Pomarine.UI.View'Class;
      Handle : Pomarine.UI.Label_Handle;
      Style  : Pomarine.Line_Texts.Style;
      Ink    : Pomarine.Themes.Slot)
   is
      use type Pomarine.Line_Texts.Style;
      use type Pomarine.Themes.Slot;
   begin
      if Style /= Pomarine.Line_Texts.Regular then
         Labels.Set_Style (Widget_Of (Home, Handle).all, Style);
      end if;
      if Ink /= 0 then
         Labels.Set_Ink (Widget_Of (Home, Handle).all, Ink);
      end if;
   end Look_Of;
   --  What a label is made to look like, when it is not the plain one.

   function Label
     (Self  : Context'Class;
      Text  : not null Text_Adapter_Ref;
      Index : Natural;
      Style : Pomarine.Line_Texts.Style;
      Ink   : Pomarine.Themes.Slot) return Pomarine.UI.Label_Handle
   is
      Home   : constant not null View_Ref := View_Of (Self);
      Handle : constant Pomarine.UI.Label_Handle := New_Label (Home.all, Self.Scope);
   begin
      Wire_Label (Self, Home.all, Handle, Text, Index);
      Look_Of (Home.all, Handle, Style, Ink);
      return Handle;
   end Label;

   function Label
     (Self : Context'Class; Caption : String; Style : Pomarine.Line_Texts.Style; Ink : Pomarine.Themes.Slot)
      return Pomarine.UI.Label_Handle
   is
      Home   : constant not null View_Ref := View_Of (Self);
      Handle : constant Pomarine.UI.Label_Handle := New_Label (Home.all, Self.Scope);
   begin
      Labels.Set_Text (Widget_Of (Home.all, Handle).all, Caption);
      Look_Of (Home.all, Handle, Style, Ink);
      return Handle;
   end Label;

   function Button
     (Self      : Context'Class;
      Caption   : String;
      Which     : Natural;
      Look      : Pomarine.Widgets.Buttons.Kind;
      Index     : Natural;
      Focusable : Boolean) return Pomarine.UI.Button_Handle
   is
      Home   : constant not null View_Ref := View_Of (Self);
      Handle : constant Pomarine.UI.Button_Handle := New_Button (Home.all, Self.Scope, Caption, Look, Focusable);
   begin
      Wire_Command (Self, Home.all, Widget_Of (Home.all, Handle).all, Which, Index, Reflect => True);
      return Handle;
   end Button;

   function Button
     (Self    : Context'Class;
      Caption : String;
      Action  : not null Action_Adapter_Ref;
      Look    : Pomarine.Widgets.Buttons.Kind;
      Index   : Natural) return Pomarine.UI.Button_Handle
   is
      Home   : constant not null View_Ref := View_Of (Self);
      Handle : constant Pomarine.UI.Button_Handle := New_Button (Home.all, Self.Scope, Caption, Look);
   begin
      Wire_Command (Self, Home.all, Widget_Of (Home.all, Handle).all, 0, Index, Reflect => True, Action => Action);
      return Handle;
   end Button;

   function Button
     (Self    : Context'Class;
      Look    : Pomarine.Widgets.Buttons.Settings;
      Which   : Natural;
      Index   : Natural;
      Reflect : Boolean) return Pomarine.UI.Button_Handle
   is
      Home   : constant not null View_Ref := View_Of (Self);
      Handle : constant Pomarine.UI.Button_Handle := New_Button (Home.all, Self.Scope, Look);
   begin
      Wire_Command (Self, Home.all, Widget_Of (Home.all, Handle).all, Which, Index, Reflect => Reflect);
      return Handle;
   end Button;

   function Grip
     (Self : Context'Class; Look : Pomarine.UI.Grip_Look; Which : Natural; Index : Natural; Name : String)
      return Pomarine.UI.Grip_Handle
   is
      Home   : constant not null View_Ref := View_Of (Self);
      Handle : constant Pomarine.UI.Grip_Handle := New_Grip (Home.all, Self.Scope, Look);
   begin
      Wire_Command (Self, Home.all, Widget_Of (Home.all, Handle).all, Which, Index, Reflect => False);
      Called (Home.all, Handle_Data (Handle), Grip_Control, Name);
      return Handle;
   end Grip;

   function Plain_Grip (Self : Context'Class; Look : Pomarine.UI.Grip_Look) return Pomarine.UI.Grip_Handle is
      Home : constant not null View_Ref := View_Of (Self);
   begin
      return New_Grip (Home.all, Self.Scope, Look, Unheard => True);
   end Plain_Grip;

   function Plain_Button
     (Self : Context'Class; Look : Pomarine.Widgets.Buttons.Settings) return Pomarine.UI.Button_Handle
   is
      Home : constant not null View_Ref := View_Of (Self);
   begin
      return New_Button (Home.all, Self.Scope, Look, Unheard => True);
   end Plain_Button;

   function Text_Field
     (Self        : Context'Class;
      Text        : not null Text_Adapter_Ref;
      Submit      : not null Action_Adapter_Ref;
      Placeholder : String;
      Name        : String;
      Replacing   : Replacement;
      Index       : Natural) return Pomarine.UI.Field_Handle
   is
      Home   : constant not null View_Ref := View_Of (Self);
      Handle : constant Pomarine.UI.Field_Handle := New_Field (Home.all, Self.Scope, Placeholder);
   begin
      Wire_Field (Self, Home.all, Handle, Text, Replacing, Index);
      Called (Home.all, Handle_Data (Handle), Field_Control, Name);
      Wire_Command (Self, Home.all, Widget_Of (Home.all, Handle).all, 0, 0, Reflect => False, Action => Submit);
      return Handle;
   end Text_Field;

   function Text_Field
     (Self        : Context'Class;
      Text        : not null Text_Adapter_Ref;
      Placeholder : String;
      Name        : String;
      Replacing   : Replacement;
      Index       : Natural) return Pomarine.UI.Field_Handle
   is
      Home   : constant not null View_Ref := View_Of (Self);
      Handle : constant Pomarine.UI.Field_Handle := New_Field (Home.all, Self.Scope, Placeholder);
   begin
      Wire_Field (Self, Home.all, Handle, Text, Replacing, Index);
      Called (Home.all, Handle_Data (Handle), Field_Control, Name);
      return Handle;
   end Text_Field;

   function Text_Field
     (Self        : Context'Class;
      Text        : not null Text_Adapter_Ref;
      Submit      : Natural;
      Placeholder : String;
      Name        : String;
      Replacing   : Replacement;
      Index       : Natural) return Pomarine.UI.Field_Handle
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
     (Self         : Context'Class;
      Home         : in out Pomarine.UI.View'Class;
      Handle       : Handle_Data;
      Kind         : Control_Kind;
      Flag         : not null Flag_Adapter_Ref;
      Index        : Natural := 0;
      Availability : Boolean := False)
   is
      Where : constant Subpools.Subpool_Handle := Arena_Of (Home, Self.Scope);
      Made  : constant Flag_Store := new (Where) Flag_Binding;
   begin
      Made.Handle := Handle;
      Made.Kind := Kind;
      Made.Index := Index;
      Made.Availability := Availability;
      Made.Flag := Flag;
      Made.Data := Self.Data;
      Add_Binding (Home, Self.Scope, Made.all'Unchecked_Access);
   end Wire_Flag;

   procedure Enabled_When
     (Self : Context'Class; Target : Pomarine.UI.Button_Handle; Allowed : not null Flag_Adapter_Ref; Index : Natural)
   is
      Home : constant not null View_Ref := View_Of (Self);
   begin
      Require_Handle (Home.all, Handle_Data (Target), Button_Control);
      Wire_Flag (Self, Home.all, Handle_Data (Target), Button_Control, Allowed, Index, Availability => True);
   end Enabled_When;

   procedure Selected_When
     (Self : Context'Class; Target : Pomarine.UI.Button_Handle; Selected : not null Flag_Adapter_Ref; Index : Natural)
   is
      Home : constant not null View_Ref := View_Of (Self);
   begin
      Require_Handle (Home.all, Handle_Data (Target), Button_Control);
      Wire_Flag (Self, Home.all, Handle_Data (Target), Button_Control, Selected, Index);
   end Selected_When;

   function Check
     (Self    : Context'Class;
      Caption : String;
      Checked : not null Flag_Adapter_Ref;
      Which   : Natural;
      Form    : Pomarine.Widgets.Checks.Kind;
      Index   : Natural;
      Name    : String) return Pomarine.UI.Check_Handle
   is
      Home   : constant not null View_Ref := View_Of (Self);
      Handle : constant Pomarine.UI.Check_Handle := New_Check (Home.all, Self.Scope, Caption, Form);
   begin
      Wire_Flag (Self, Home.all, Handle_Data (Handle), Check_Control, Checked, Index);
      Wire_Command (Self, Home.all, Widget_Of (Home.all, Handle).all, Which, Index, Reflect => True);
      Called (Home.all, Handle_Data (Handle), Check_Control, Name);
      return Handle;
   end Check;

   function Check
     (Self    : Context'Class;
      Caption : String;
      Checked : not null Flag_Adapter_Ref;
      Form    : Pomarine.Widgets.Checks.Kind;
      Name    : String) return Pomarine.UI.Check_Handle
   is
      Home   : constant not null View_Ref := View_Of (Self);
      Handle : constant Pomarine.UI.Check_Handle := New_Check (Home.all, Self.Scope, Caption, Form);
   begin
      Wire_Flag (Self, Home.all, Handle_Data (Handle), Check_Control, Checked);
      Called (Home.all, Handle_Data (Handle), Check_Control, Name);
      return Handle;
   end Check;

   function Switch
     (Self    : Context'Class;
      Caption : String;
      On      : not null Flag_Adapter_Ref;
      Which   : Natural;
      Index   : Natural;
      Name    : String) return Pomarine.UI.Switch_Handle
   is
      Home   : constant not null View_Ref := View_Of (Self);
      Handle : constant Pomarine.UI.Switch_Handle := New_Switch (Home.all, Self.Scope, Caption);
   begin
      Wire_Flag (Self, Home.all, Handle_Data (Handle), Switch_Control, On, Index);
      Wire_Command (Self, Home.all, Widget_Of (Home.all, Handle).all, Which, Index, Reflect => True);
      Called (Home.all, Handle_Data (Handle), Switch_Control, Name);
      return Handle;
   end Switch;

   function Progress (Self : Context'Class; Done : not null Fraction_Adapter_Ref) return Pomarine.UI.Progress_Handle is
      Home   : constant not null View_Ref := View_Of (Self);
      Handle : constant Pomarine.UI.Progress_Handle := New_Progress (Home.all, Self.Scope);
      Where  : constant Subpools.Subpool_Handle := Arena_Of (Home.all, Self.Scope);
      Made   : constant Progress_Store := new (Where) Progress_Binding;
   begin
      Made.Handle := Handle_Data (Handle);
      Made.Done := Done;
      Made.Data := Self.Data;
      Add_Binding (Home.all, Self.Scope, Made.all'Unchecked_Access);
      return Handle;
   end Progress;

   procedure Focus_When
     (Self : Context'Class; Target : Pomarine.UI.Focus_Target; Raised : not null Flag_Adapter_Ref; Index : Natural)
   is
      Home  : constant not null View_Ref := View_Of (Self);
      Where : constant Subpools.Subpool_Handle := Arena_Of (Home.all, Self.Scope);
      Made  : constant Focus_Store := new (Where) Focus_Binding;
   begin
      Require_Open (Home.all, Self.Scope);
      Made.Handle := Data_Of (Target);
      Made.Flag := Raised;
      Made.Data := Self.Data;
      Made.Index := Index;
      Add_Binding (Home.all, Self.Scope, Made.all'Unchecked_Access);
   end Focus_When;

   procedure Show_When
     (Self : Context'Class; Target : Pomarine.UI.Control_Ref; Shown : not null Flag_Adapter_Ref; Index : Natural)
   is
      Home  : constant not null View_Ref := View_Of (Self);
      Where : constant Subpools.Subpool_Handle := Arena_Of (Home.all, Self.Scope);
      Made  : constant Shown_Store := new (Where) Shown_Binding;
   begin
      Require_Open (Home.all, Self.Scope);
      Made.Handle := Data_Of (Target);
      Made.Flag := Shown;
      Made.Index := Index;
      Made.Data := Self.Data;
      Add_Binding (Home.all, Self.Scope, Made.all'Unchecked_Access);
   end Show_When;

   procedure Show_When
     (Self : Context'Class; Target : Pomarine.UI.Layout; Shown : not null Flag_Adapter_Ref; Index : Natural)
   is
      Home  : constant not null View_Ref := View_Of (Self);
      Where : constant Subpools.Subpool_Handle := Arena_Of (Home.all, Self.Scope);
      Made  : constant Panel_Store := new (Where) Panel_Binding;
   begin
      Require_Open (Home.all, Self.Scope);
      Made.Screen := Target;
      Made.Flag := Shown;
      Made.Index := Index;
      Made.Data := Self.Data;
      Add_Binding (Home.all, Self.Scope, Made.all'Unchecked_Access);
   end Show_When;

   function List
     (Self : Context'Class; Rows : not null Rows_Adapter_Ref; Selection : not null Choice_Adapter_Ref; Name : String)
      return Pomarine.UI.List_Handle
   is
      Home   : constant not null View_Ref := View_Of (Self);
      Handle : constant Pomarine.UI.List_Handle := New_List (Home.all, Self.Scope);
   begin
      Wire_List (Self, Home.all, Handle, Rows, Selection);
      Called (Home.all, Handle_Data (Handle), List_Control, Name);
      return Handle;
   end List;

   procedure Focus_Initially (Self : Context'Class; Target : Pomarine.UI.Focus_Target) is
      Home : constant not null View_Ref := View_Of (Self);
   begin
      Require_Open (Home.all, Self.Scope);
      Set_Focus_Initially (Home.all, Target);
   end Focus_Initially;

   procedure Reveal_After
     (Self : Context'Class; Which : Natural; Target : Pomarine.UI.Reveal_Target; Count : not null Count_Adapter_Ref)
   is
      Home  : constant not null View_Ref := View_Of (Self);
      Where : constant Subpools.Subpool_Handle := Arena_Of (Home.all, Self.Scope);
      Made  : constant Reveal_Store := new (Where) Reveal_Binding;
   begin
      Require_Open (Home.all, Self.Scope);
      Require_Handle (Home.all, Data_Of (Target), List_Control);
      Made.Handle := Data_Of (Target);
      Made.Count := Count;
      Made.Data := Self.Data;
      Made.After := (Model => Self.Data, Which => Which);
      Add_Binding (Home.all, Self.Scope, Made.all'Unchecked_Access);
   end Reveal_After;

   --  Borrowing

   function Borrow_Label
     (Self : Context'Class; Existing : in out Labels.Label; Text : not null Text_Adapter_Ref)
      return Pomarine.UI.Label_Handle
   is
      Home   : constant not null View_Ref := View_Of (Self);
      Handle : constant Pomarine.UI.Label_Handle := Pomarine.UI.Borrow_Label (Home.all, Self.Scope, Existing);
   begin
      Wire_Label (Self, Home.all, Handle, Text);
      return Handle;
   end Borrow_Label;

   function Borrow_Button
     (Self     : Context'Class;
      Existing : in out Pomarine.Widgets.Buttons.Button;
      Which    : Natural;
      Index    : Natural;
      Reflect  : Boolean) return Pomarine.UI.Button_Handle
   is
      Home   : constant not null View_Ref := View_Of (Self);
      Handle : constant Pomarine.UI.Button_Handle := Pomarine.UI.Borrow_Button (Home.all, Self.Scope, Existing);
   begin
      Wire_Command (Self, Home.all, Existing, Which, Index, Reflect => Reflect);
      return Handle;
   end Borrow_Button;

   procedure Caption_From
     (Self : Context'Class; Target : Pomarine.UI.Button_Handle; Text : not null Text_Adapter_Ref; Index : Natural)
   is
      Home : constant not null View_Ref := View_Of (Self);
   begin
      Require_Handle (Home.all, Handle_Data (Target), Button_Control);
      declare
         Where : constant Subpools.Subpool_Handle := Arena_Of (Home.all, Self.Scope);
         Made  : constant Text_Store := new (Where) Text_Binding;
      begin
         Made.Kind := Button_Control;
         Made.Handle := Handle_Data (Target);
         Made.Text := Text;
         Made.Data := Self.Data;
         Made.Index := Index;
         Add_Binding (Home.all, Self.Scope, Made.all'Unchecked_Access);
      end;
   end Caption_From;

   function Borrow_Field
     (Self      : Context'Class;
      Existing  : in out Text_Fields.Text_Field;
      Backing   : aliased in out Texts.Documents.Document;
      Text      : not null Text_Adapter_Ref;
      Replacing : Replacement) return Pomarine.UI.Field_Handle
   is
      Home   : constant not null View_Ref := View_Of (Self);
      Handle : constant Pomarine.UI.Field_Handle := Pomarine.UI.Borrow_Field (Home.all, Self.Scope, Existing, Backing);
   begin
      Wire_Field (Self, Home.all, Handle, Text, Replacing);
      return Handle;
   end Borrow_Field;

   procedure On_Frame_Event
     (Self   : Context'Class;
      Target : in out Widgets.Frames.Frame;
      Kind   : Widgets.Event_Kind;
      Which  : Natural;
      Index  : Natural)
   is
      Home : constant not null View_Ref := View_Of (Self);
   begin
      Require_Open (Home.all, Self.Scope);
      if Kind
         not in Widgets.Double_Click
              | Widgets.Submit
              | Widgets.Blur
              | Widgets.Minimize
              | Widgets.Restore
              | Widgets.Close
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
         Made  : constant Event_Command_Store := new (Where) Event_Command_Binding;
      begin
         Made.Which := Which;
         Made.Hooks := Self.Hooks;
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

   function Bind_Event
     (Self             : Context'Class;
      Target           : Pomarine.UI.Control_Ref;
      Kind             : Widgets.Event_Kind;
      Which            : Natural;
      Index            : Natural;
      Index_From_Event : Boolean;
      Hooked           : Boolean := False;
      Hook             : Editor_Hook := Tool_Used;
      Canvased         : Boolean := False;
      Line_Hook        : Canvas_Hook := Line_Selected) return Event_Command_Store
   is
      Home   : constant not null View_Ref := View_Of (Self);
      Handle : constant Handle_Data := Data_Of (Target);
   begin
      Require_Open (Home.all, Self.Scope);
      if Handle.View /= 0 and then Handle.View /= Home.Number then
         raise Foreign_Handle with "event control belongs to another view";
      elsif Handle.Slot not in 1 .. Natural (Home.Controls.Length) then
         raise Stale_Handle with "event control outlived its scope";
      end if;
      Require_Handle (Home.all, Handle, Home.Controls (Handle.Slot).Kind);
      if Home.Controls (Handle.Slot).Scope /= Self.Scope.Slot then
         raise Program_Error with "event binding must belong to the control's scope";
      end if;
      declare
         Found : constant Widgets.Widget_Access := Resolve (Home.all, Handle, Home.Controls (Handle.Slot).Kind);
      begin
         for Binding of Home.Bindings loop
            if Binding /= null and then Binding.all in Event_Command_Binding'Class then
               declare
                  Other : Event_Command_Binding renames Event_Command_Binding (Binding.all);
                  use type Widgets.Event_Kind;
               begin
                  if Other.Target = Found
                    and then Other.Hooked = Hooked
                    and then Other.Canvased = Canvased
                    and then (if Canvased
                              then Other.Line_Hook = Line_Hook
                              elsif Hooked
                              then Other.Hook = Hook
                              else Other.Kind = Kind)
                  then
                     raise Program_Error with "widget event already bound";
                  end if;
               end;
            end if;
         end loop;
         declare
            Where : constant Subpools.Subpool_Handle := Arena_Of (Home.all, Self.Scope);
            Made  : constant Event_Command_Store := new (Where) Event_Command_Binding;
         begin
            Made.Which := Which;
            Made.Hooks := Self.Hooks;
            Made.Data := Self.Data;
            Made.Tag := Command_Tag (Home.all);
            Made.Home := Home;
            Made.Target := Found;
            Made.Kind := Kind;
            Made.Index := Index;
            Made.Index_From_Event := Index_From_Event;
            Made.Hooked := Hooked;
            Made.Canvased := Canvased;
            Made.Hook := Hook;
            Made.Line_Hook := Line_Hook;
            Add_Binding (Home.all, Self.Scope, Made.all'Unchecked_Access);
            if not Hooked and then not Canvased then
               Event_Callbacks.On (Found.all, Kind, Made.all'Unchecked_Access, Event_Heard'Access);
            end if;
            return Made;
         end;
      end;
   end Bind_Event;

   procedure On_Event
     (Self             : Context'Class;
      Target           : Pomarine.UI.Control_Ref;
      Kind             : Widgets.Event_Kind;
      Which            : Natural;
      Index            : Natural;
      Index_From_Event : Boolean)
   is
      Made : constant Event_Command_Store := Bind_Event (Self, Target, Kind, Which, Index, Index_From_Event);
      pragma Unreferenced (Made);
   begin
      null;
   end On_Event;

   procedure On_Editor_Event
     (Self             : Context'Class;
      Target           : Pomarine.UI.Widget_Handle;
      Hook             : Editor_Hook;
      Which            : Natural;
      Index            : Natural;
      Index_From_Event : Boolean)
   is
      Home : constant not null View_Ref := View_Of (Self);
   begin
      if Widget_Of (Home.all, Target).all not in Widgets.Editors.Editor'Class then
         raise Program_Error with "editor hooks require an editor";
      end if;
      declare
         Made   : constant Event_Command_Store :=
           Bind_Event
             (Self,
              Pomarine.UI.Any (Target),
              Widgets.Click,
              Which,
              Index,
              Index_From_Event,
              Hooked => True,
              Hook   => Hook);
         Editor : Widgets.Editors.Editor'Class renames Widgets.Editors.Editor'Class (Made.Target.all);
      begin
         case Hook is
            when Tool_Used     =>
               Editor_Callbacks.On_Tool (Editor, Made, Tool_Heard'Access);

            when Link_Followed =>
               Editor_Callbacks.On_Follow (Editor, Made, Link_Heard'Access);

            when Link_Asked    =>
               Editor_Callbacks.On_Ask_Link (Editor, Made, Link_Heard'Access);
         end case;
      end;
   end On_Editor_Event;

   procedure On_Canvas_Event
     (Self             : Context'Class;
      Target           : Pomarine.UI.Widget_Handle;
      Hook             : Canvas_Hook;
      Which            : Natural;
      Index            : Natural;
      Index_From_Event : Boolean)
   is
      Home : constant not null View_Ref := View_Of (Self);
   begin
      if Widget_Of (Home.all, Target).all not in Widgets.Canvases.Canvas'Class then
         raise Program_Error with "canvas hooks require a canvas";
      end if;
      declare
         Made   : constant Event_Command_Store :=
           Bind_Event
             (Self,
              Pomarine.UI.Any (Target),
              Widgets.Click,
              Which,
              Index,
              Index_From_Event,
              Canvased  => True,
              Line_Hook => Hook);
         Canvas : Widgets.Canvases.Canvas'Class renames Widgets.Canvases.Canvas'Class (Made.Target.all);
      begin
         case Hook is
            when Line_Selected =>
               Canvas_Callbacks.On_Select (Canvas, Made, Line_Selected_Heard'Access);

            when Line_Deleted  =>
               Canvas_Callbacks.On_Delete (Canvas, Made, Line_Deleted_Heard'Access);
         end case;
      end;
   end On_Canvas_Event;

   procedure On_List_Actions (Self : Context'Class; Target : Pomarine.UI.Widget_Handle; Actions : Which_Array) is
      Home : constant not null View_Ref := View_Of (Self);
   begin
      if Widget_Of (Home.all, Target).all not in Lists.List'Class then
         raise Program_Error with "row actions require a list";
      end if;
      --  Validate the scope and duplicate event through the normal discrete binding path.
      declare
         Made  : constant Event_Command_Store :=
           Bind_Event (Self, Pomarine.UI.Any (Target), Widgets.Act, Actions (1), 0, False);
         Where : constant Subpools.Subpool_Handle := Arena_Of (Home.all, Self.Scope);
      begin
         Made.Row_Actions := True;
         for Number in Actions'Range loop
            declare
               Action : constant Command_Store := new (Where) Command_Binding;
            begin
               Action.Which := Actions (Number);
               Action.Hooks := Self.Hooks;
               Action.Data := Self.Data;
               Action.Tag := Command_Tag (Home.all);
               Add_Binding (Home.all, Self.Scope, Action.all'Unchecked_Access);
               Made.Tags (Number) := Action.Tag;
            end;
         end loop;
      end;
   end On_List_Actions;

   function Borrow_Slider
     (Self : Context'Class; Existing : in out Widgets.Sliders.Slider; Value : not null Fraction_Adapter_Ref)
      return Pomarine.UI.Widget_Handle
   is
      Home   : constant not null View_Ref := View_Of (Self);
      Handle : constant Pomarine.UI.Widget_Handle := Pomarine.UI.Borrow_Widget (Home.all, Self.Scope, Existing);
      Where  : constant Subpools.Subpool_Handle := Arena_Of (Home.all, Self.Scope);
      Made   : constant Slider_Store := new (Where) Slider_Binding;
   begin
      Made.Handle := Handle_Data (Handle);
      Made.Value := Value;
      Made.Data := Self.Data;
      Add_Binding (Home.all, Self.Scope, Made.all'Unchecked_Access);
      Home.Controls (Made.Handle.Slot).Handled := Widgets.Change;
      Home.Controls (Made.Handle.Slot).Heard := True;
      Syncing.Install (Home.all, Existing, Widgets.Change, Edits_Only => True);
      return Handle;
   end Borrow_Slider;

   function Borrow_Widget
     (Self : Context'Class; Existing : in out Pomarine.Widgets.Widget'Class) return Pomarine.UI.Widget_Handle
   is
      Home : constant not null View_Ref := View_Of (Self);
   begin
      return Pomarine.UI.Borrow_Widget (Home.all, Self.Scope, Existing);
   end Borrow_Widget;

   function Borrow_List
     (Self      : Context'Class;
      Existing  : in out Lists.List;
      Rows      : not null Rows_Adapter_Ref;
      Selection : not null Choice_Adapter_Ref) return Pomarine.UI.List_Handle
   is
      Home   : constant not null View_Ref := View_Of (Self);
      Handle : constant Pomarine.UI.List_Handle := Pomarine.UI.Borrow_List (Home.all, Self.Scope, Existing);
   begin
      Wire_List (Self, Home.all, Handle, Rows, Selection);
      return Handle;
   end Borrow_List;

end Pomarine.UI.Binders.Controls;
