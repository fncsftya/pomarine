with Pomarine.Widgets.Callbacks;

package body Pomarine.UI.Syncing is

   use type Widgets.Event_Kind;

   package Hub_Callbacks is new Widgets.Callbacks (Hub);

   procedure Heard (Self : in out Hub; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event) is
      pragma Unreferenced (Source);
   begin
      if Self.Owner /= null then
         Hear (Self.Owner.all, Event);
      end if;
   end Heard;

   procedure Edited (Self : in out Hub; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event) is
      pragma Unreferenced (Source, Event);
   begin
      if Self.Owner /= null then
         Hear (Self.Owner.all, (Kind => Widgets.Change, Tag => Widgets.No_Tag, Index => 0));
      end if;
   end Edited;

   procedure Install
     (Within     : in out View'Class;
      Item       : in out Widgets.Widget'Class;
      Kind       : Widgets.Event_Kind;
      Edits_Only : Boolean := False) is
   begin
      if Edits_Only then
         Hub_Callbacks.On (Item, Kind, Within.Judge'Unchecked_Access, Edited'Access);
      else
         Hub_Callbacks.On (Item, Kind, Within.Judge'Unchecked_Access, Heard'Access);
      end if;
   end Install;

   procedure Uninstall (Item : in out Widgets.Widget'Class; Kind : Widgets.Event_Kind) is
   begin
      Hub_Callbacks.Off (Item, Kind);
   end Uninstall;

   --  Walking the bindings by number, not by cursor: a binding made while it
   --  goes on is not skipped or seen twice by a vector that moved.

   procedure Collect_All (Within : in out View'Class) is
      Number : Positive := 1;
   begin
      while Number <= Natural (Within.Bindings.Length) loop
         declare
            Item : constant Binding_Ref := Within.Bindings (Number);
         begin
            if Item /= null then
               Collect (Item.all, Within);
            end if;
         end;
         Number := Number + 1;
      end loop;
   end Collect_All;

   procedure Refresh_All (Within : in out View'Class; Forced : Boolean) is
      Number : Positive := 1;
   begin
      while Number <= Natural (Within.Bindings.Length) loop
         declare
            Item : constant Binding_Ref := Within.Bindings (Number);
         begin
            if Item /= null then
               Refresh (Item.all, Within, Forced);
            end if;
         end;
         Number := Number + 1;
      end loop;
   end Refresh_All;

   procedure Tell_All (Within : in out View'Class; Which : Command_Key; Before : Boolean) is
      Number : Positive := 1;
   begin
      while Number <= Natural (Within.Bindings.Length) loop
         declare
            Item : constant Binding_Ref := Within.Bindings (Number);
         begin
            if Item /= null then
               if Before then
                  Before_Command (Item.all, Which);
               else
                  After_Command (Item.all, Which);
               end if;
            end if;
         end;
         Number := Number + 1;
      end loop;
   end Tell_All;

   procedure Do_Command (Within : in out View'Class; Event : Widgets.Widget_Event) is
      use Tag_Maps;
      Found : constant Cursor :=
        (if Event.Kind in Widgets.Click | Widgets.Submit | Widgets.Change
         then Within.Commands.Find (Event.Tag)
         else No_Element);
   begin
      if Found = No_Element then
         return;
      end if;
      declare
         Item : constant Binding_Ref := Element (Found);
      begin
         if Item = null or else not Is_Command (Item.all) then
            return;
         end if;
         declare
            Which : constant Command_Key := Key (Item.all);
         begin
            Tell_All (Within, Which, Before => True);
            if Can_Execute (Item.all, Event.Index) then
               Execute (Item.all, Event.Index);
               Within.Touched := True;
            end if;
            Tell_All (Within, Which, Before => False);
         end;
      end;
   end Do_Command;

   --  One turn: passes, then the events that came meanwhile.

   procedure Run (Within : in out View'Class; First : Boolean; Event : Widgets.Widget_Event; Forced : Boolean) is
      Passes  : Natural := 0;
      Doing   : Boolean := First;
      Changed : Boolean := False;
   begin
      Within.Syncing := True;
      begin
         loop
            Within.Again := False;
            Within.Touched := Forced and then Passes = 0;
            Collect_All (Within);
            if Doing then
               Do_Command (Within, Event);
               Doing := False;
            end if;
            Refresh_All (Within, Forced => Forced and then Passes = 0);
            if Within.Touched then
               Changed := True;
               Widgets.Revalidate (Within.Tree.all);
            end if;
            Passes := Passes + 1;
            exit when not (Within.Again or else Within.Touched) or else Passes >= Synchronization_Passes_Limit;
         end loop;
      exception
         when others =>
            Within.Syncing := False;
            raise;
      end;
      Within.Syncing := False;
      if Changed and then Within.Watcher /= null then
         Within.Watcher.Turned;
      end if;
   end Run;

   procedure Drain (Within : in out View'Class) is
   begin
      while not Within.Pending.Is_Empty and then not Within.Syncing loop
         declare
            Next : constant Widgets.Widget_Event := Within.Pending.First_Element;
         begin
            Within.Pending.Delete_First;
            Run (Within, First => True, Event => Next, Forced => False);
         end;
      end loop;
   end Drain;

   procedure Synchronize (Within : in out View'Class) is
   begin
      if Within.Tearing_Down then
         return;
      elsif Within.Syncing then
         Within.Again := True;
         return;
      end if;
      Run (Within, First => False, Event => (Kind => Widgets.Click, others => <>), Forced => False);
      Drain (Within);
   end Synchronize;

   procedure Hear (Within : in out View'Class; Event : Widgets.Widget_Event) is
   begin
      if Within.Tearing_Down then
         return;
      elsif Within.Syncing then
         Within.Pending.Append (Event);
         return;
      end if;
      Run (Within, First => True, Event => Event, Forced => False);
      Drain (Within);
   end Hear;

   procedure Show_All (Within : in out View'Class) is
   begin
      Run (Within, First => False, Event => (Kind => Widgets.Click, others => <>), Forced => True);
      Drain (Within);
   end Show_All;

   function Validate (Within : View'Class; Tag : Integer; Index : Natural) return Widgets.Command_State is
      use Tag_Maps;
      Found : constant Cursor := Within.Commands.Find (Tag);
   begin
      if Found = No_Element or else Element (Found) = null then
         return Widgets.Not_Offered;
      end if;
      return (if Can_Execute (Element (Found).all, Index) then Widgets.Enabled else Widgets.Disabled);
   end Validate;

end Pomarine.UI.Syncing;
