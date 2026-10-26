with Pomarine.Events;
with Pomarine.Widgets.Text_Fields;
with Texts.Documents;

--  A decimal integer typed into an ordinary single-line editor, with growing draft storage.
--  Return or loss of focus commits a valid draft, saying Change only if the value changed. Return also says
--  Submit on success. An invalid or out-of-range draft stays visible, outlined in danger, and leaves Value alone.
--  Escape restores the last committed value. Clipboard, selection, undo and input methods are the editor's.
package Pomarine.Widgets.Number_Fields is
   type Number_Field is new Text_Fields.Text_Field with private;

   overriding procedure Configure (Item : in out Number_Field; Family : String; Size : Float)
     with Pre => not Is_Configured (Item), Post => Is_Configured (Item) and then Value (Item) = 0;

   procedure Configure
     (Item : in out Number_Field; Family : String; Size : Float;
      Min : Integer; Max : Integer; Start : Integer := 0)
     with Pre => Min <= Max and then Start in Min .. Max and then not Is_Configured (Item),
          Post => Is_Configured (Item) and then Value (Item) = Start;
   --  Owns its document; do not Attach another document. Configure before layout.

   function Minimum (Item : Number_Field) return Integer;
   function Maximum (Item : Number_Field) return Integer;
   function Value (Item : Number_Field) return Integer
     with Post => Value'Result in Minimum (Item) .. Maximum (Item);

   procedure Set_Value (Item : in out Number_Field; To : Integer)
     with Pre => Is_Configured (Item) and then To in Minimum (Item) .. Maximum (Item),
          Post => Value (Item) = To and then Valid (Draft (Item), Minimum (Item), Maximum (Item));
   --  Replace draft and value without saying Change, including an unchanged value with an invalid draft.

   procedure Set_Range (Item : in out Number_Field; Min, Max : Integer)
     with Pre => Is_Configured (Item) and then Min <= Max,
          Post => Value (Item) in Min .. Max;
   --  Clamps the committed value and restores its text, without saying Change.

   function Draft (Item : Number_Field) return String
     with Pre => Is_Configured (Item);
   function Valid (Text : String; Min : Integer; Max : Integer) return Boolean
     with Pre => Min <= Max;
   --  Optional leading + or -, then decimal digits only; no spaces, based literals or exponents.
   function Can_Commit (Item : Number_Field) return Boolean;
   procedure Commit (Item : in out Number_Field)
     with Pre => Can_Commit (Item);
   procedure Restore (Item : in out Number_Field)
     with Pre => Is_Configured (Item), Post => Valid (Draft (Item), Minimum (Item), Maximum (Item));

   overriding procedure Handle
     (Item : in out Number_Field; Event : Pomarine.Events.Event; Handled : out Boolean);
   overriding procedure Update (Item : in out Number_Field; Now : Pomarine.Events.Milliseconds);
   overriding procedure Focus_Changed (Item : in out Number_Field; Focused : Boolean);

private
   type Number_Field is new Text_Fields.Text_Field with record
      Doc : aliased Texts.Documents.Document;
      Low : Integer := Integer'First;
      High : Integer := Integer'Last;
      Current : Integer := 0;
   end record;
end Pomarine.Widgets.Number_Fields;
