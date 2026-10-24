package body Pomarine.Widgets.Bindings is

   package Documents renames Texts.Documents;

   procedure Set_Owner (Item : in out Sync_Root; Owner : not null access Syncable'Class) is
   begin
      Item.Owner := Owner;
   end Set_Owner;

   overriding procedure Update (Item : in out Sync_Root; Now : Pomarine.Events.Milliseconds) is
      pragma Unreferenced (Now);
   begin
      if Item.Owner /= null then
         Sync (Item.Owner.all);
      end if;
   end Update;

   function Edited (Link : in out Text_Link; Document : Texts.Documents.Document) return Boolean is
   begin
      if Documents.State (Document) = Link.Seen then
         return False;
      end if;
      Link.Seen := Documents.State (Document);
      return True;
   end Edited;

   procedure Show
     (Link     : in out Text_Link;
      Document : in out Texts.Documents.Document;
      Text     : String) is
   begin
      if Documents.Whole (Document) /= Text then
         Documents.Load (Document, Text);
      end if;
      Link.Seen := Documents.State (Document);
   end Show;

end Pomarine.Widgets.Bindings;
