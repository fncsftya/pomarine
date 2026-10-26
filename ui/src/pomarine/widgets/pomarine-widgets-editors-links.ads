with Pomarine.Events;

private package Pomarine.Widgets.Editors.Links is

   function Address_Of (Words : String) return String;
   --  What Words says to link to: itself if it is an address, https:// and it if it is a bare domain.

   function Field_Address (Item : Editor) return String;

   function Link_Acceptable (Item : Editor) return Boolean;

   procedure Refresh_Link (Item : in out Editor);

   function Pointer_Link (Item : in out Editor; X, Y : Float) return String;

   function Link_Under (Item : in out Editor; Event : Pomarine.Events.Event) return String;

   procedure Set_Address (Item : in out Editor; To : String);

   procedure Ask (Item : in out Editor);

   procedure Choose (Item : in out Editor; Which : Positive);

   procedure Finish (Item : in out Editor; Keep : Boolean);

end Pomarine.Widgets.Editors.Links;
