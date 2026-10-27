with Ada.Strings.Unbounded;
with Pomarine.Searches;
with Texts.Documents;

package body Pomarine.Text_Areas.Finding is

   package Docs renames Texts.Documents;

   function Search_Position (Item : Text_Area; Offset : Positive) return Position is
      Left : Positive := Offset;
   begin
      for Para in 1 .. Docs.Count (Item.Doc.all) loop
         if Left <= Docs.Byte_Length (Item.Doc.all, Para) + 1 then
            return (Para, Left);
         end if;
         Left := Left - Docs.Byte_Length (Item.Doc.all, Para) - 1;
      end loop;
      return Docs.Text_End (Item.Doc.all);
   end Search_Position;

   procedure Refresh (Item : in out Text_Area; Term : String) is
   begin
      Pomarine.Searches.Clear (Item.Found);
      Item.Search_Term := Ada.Strings.Unbounded.To_Unbounded_String (Term);
      Item.Search_Seen := Docs.Current (Item.Doc.all);
      Item.Search_Serial := Docs.Serial (Item.Doc.all);
      if Term /= "" then
         Pomarine.Searches.Find (Item.Found, Docs.Whole (Item.Doc.all), Term);
      end if;
   end Refresh;

end Pomarine.Text_Areas.Finding;
