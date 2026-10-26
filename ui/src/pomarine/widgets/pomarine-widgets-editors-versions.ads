with Pomarine.Events;

private package Pomarine.Widgets.Editors.Versions is

   procedure Build_Bubbles (Item : in out Editor);

   procedure Close_Cycle (Item : in out Editor);

   procedure Refresh_Bubbles (Item : in out Editor);

   procedure Track_Writing (Item : in out Editor);

   procedure Cycle_Version (Item : in out Editor; From : Texts.Position; By : Integer);

   procedure Begin_Writing (Item : in out Editor);

   procedure Finish_Writing (Item : in out Editor; Keep : Boolean);

   procedure Track_Pointer (Item : in out Editor; Event : Pomarine.Events.Event);

   function Cycling_From (Item : Editor; From : out Texts.Position) return Boolean;

end Pomarine.Widgets.Editors.Versions;
