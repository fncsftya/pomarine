with Pomarine.Events;
with Pomarine.Widgets.Panels;
with Texts.Documents;

--  The view of a view-model (see Pomarine.View_Models): widgets, and what ties
--  them to it. The view holds no rule of its own. Properties go one way, to
--  the widgets, whenever the view-model's Version is not what the view last
--  saw; what the person does goes the other, as a call on the view-model (a
--  command, a Set).
--
--     type Window is limited new Widgets.Listener and Bindings.Syncable with record
--        Root : aliased Bindings.Sync_Root;
--        Seen : View_Models.Watch;
--        ...
--     overriding procedure Sync (Item : in out Window) is
--     begin
--        if Binding.Changed (Item.Seen, Item.Model.all) then
--           Labels.Set_Text (Item.Summary, Summary (Item.Model.all));
--           Widgets.Revalidate (Item.Root);
--        end if;
--     end Sync;
--
--  The setters are given what the widget has already and do nothing then, so
--  a Sync that sets everything is cheap; Changed is so that it need not look.
--  For the commands of a view-model, see Pomarine.Widgets.Bindings.For_Commands.
package Pomarine.Widgets.Bindings is

   type Syncable is limited interface;

   procedure Sync (Self : in out Syncable) is abstract;
   --  Show what the view-model says, and tell it what the widgets say.

   type Sync_Root is new Pomarine.Widgets.Panels.Panel with private;
   --  The root of a view's widgets, which has the view Sync each turn the
   --  tree is updated, so that a change that came from anywhere (a thread, a
   --  timer) shows. A handler calls Sync itself, to be in step with its event.

   procedure Set_Owner (Item : in out Sync_Root; Owner : not null access Syncable'Class);
   --  The view to Sync; it must be there as long as the root is used.

   overriding procedure Update (Item : in out Sync_Root; Now : Pomarine.Events.Milliseconds);

   type Text_Link is limited private;
   --  What ties a field's document to a text of the view-model, both ways,
   --  without either hearing its own change as the other's.

   function Edited (Link : in out Text_Link; Document : Texts.Documents.Document) return Boolean;
   --  Whether the document has been changed since it was last shown (Show) or
   --  asked about (Edited), as by typing, and so is the person's word:
   --
   --     if Bindings.Edited (Item.Link, Item.Typed) then
   --        Set_Draft (Item.Model.all, Texts.Documents.Whole (Item.Typed));
   --     end if;

   procedure Show
     (Link     : in out Text_Link;
      Document : in out Texts.Documents.Document;
      Text     : String);
   --  Have the document say Text, unless it does, and take that as seen, so
   --  that Edited is not True for what the view-model said itself. Ask
   --  Edited first, or what was typed is lost.

private

   type Sync_Root is new Pomarine.Widgets.Panels.Panel with record
      Owner : access Syncable'Class;
   end record;

   type Text_Link is limited record
      Seen : Natural := 0;
      --  The document's State as last shown or asked about.
   end record;

end Pomarine.Widgets.Bindings;
