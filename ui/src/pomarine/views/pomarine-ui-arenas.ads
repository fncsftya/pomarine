with System;
with System.Storage_Elements;
with System.Storage_Pools.Subpools;

--  Where a view keeps what it owns: widgets, documents, binding records and
--  layout descriptions. One pool serves every view; each construction scope
--  (and the mounted screen) is a subpool of it, an arena of growing blocks.
--
--  An object made in an arena has a stable address for as long as the arena
--  lives, since blocks are only added, never moved. Nothing is freed one at a
--  time. Destroying the arena finalizes every controlled object made in it
--  (in reverse order of creation, which is what GNAT's finalization of a
--  subpool does) and then gives the blocks back.
--
--  Access types that allocate here are pool-specific, and declared at library
--  level (in a package, or a generic instantiated in one): Ada refuses
--  anything deeper, which is part of the lifetime rules of Pomarine.UI.
--
--     type Label_Ref is access Labels.Label;
--     for Label_Ref'Storage_Pool use Arenas.Pool;
--     ...
--     Home : Arenas.Handle := Arenas.Make;
--     Item : constant Label_Ref := new (Home) Labels.Label;
--     ...
--     Arenas.Destroy (Home);
package Pomarine.UI.Arenas is

   package Subpools renames System.Storage_Pools.Subpools;

   subtype Handle is Subpools.Subpool_Handle;

   type Pool_Type is new Subpools.Root_Storage_Pool_With_Subpools with null record;

   use type Subpools.Subpool_Handle;

   function Make return not null Handle;
   --  A new, empty arena.

   procedure Destroy (Item : in out Handle)
     with Post => Item = null;
   --  Finalize what is in it, then free it. Does nothing for null.

   function Live_Arenas return Natural;
   --  How many arenas are made and not yet destroyed, in all views, for tests that look for leaks.

   function Bytes_Held (Item : not null Handle) return Natural;
   --  How much storage its blocks hold, for tests that check it is given back
   --  and grows rather than stops.

   function Block_Count (Item : not null Handle) return Natural;

   overriding function Create_Subpool (Self : in out Pool_Type) return not null Handle;

   overriding procedure Allocate_From_Subpool
     (Self                     : in out Pool_Type;
      Storage_Address          : out System.Address;
      Size_In_Storage_Elements : System.Storage_Elements.Storage_Count;
      Alignment                : System.Storage_Elements.Storage_Count;
      Subpool                  : not null Handle);

   overriding procedure Deallocate_Subpool (Self : in out Pool_Type; Subpool : in out Handle);

   overriding procedure Deallocate
     (Self                     : in out Pool_Type;
      Storage_Address          : System.Address;
      Size_In_Storage_Elements : System.Storage_Elements.Storage_Count;
      Alignment                : System.Storage_Elements.Storage_Count) is null;
   --  An object is given back with its arena.

   overriding function Default_Subpool_For_Pool (Self : in out Pool_Type) return not null Handle;
   --  Raises Program_Error: every allocation names its arena.
   Pool : Pool_Type;
   --  Stateless: everything it knows is in the subpools.

private

   use System.Storage_Elements;

   type Block;
   type Block_Access is access Block;
   type Storage_Block is access Storage_Array;

   type Block is record
      Data : Storage_Block;
      Used : Storage_Count := 0;
      Next : Block_Access;
   end record;

   type Arena;
   type Arena_Access is access all Arena;

   type Arena is new Subpools.Root_Subpool with record
      Blocks : Block_Access;
      Count  : Natural := 0;
      Held   : Natural := 0;
   end record;

end Pomarine.UI.Arenas;
