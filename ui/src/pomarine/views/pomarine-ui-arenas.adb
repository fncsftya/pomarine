with Ada.Unchecked_Deallocate_Subpool;
with Ada.Unchecked_Deallocation;

package body Pomarine.UI.Arenas is

   use type System.Address;

   Block_Size : constant Storage_Count := 16 * 1024;
   --  A block is at least this, or as much as one object and its alignment need.

   procedure Free is new Ada.Unchecked_Deallocation (Storage_Array, Storage_Block);
   procedure Free is new Ada.Unchecked_Deallocation (Block, Block_Access);

   procedure Free is new Ada.Unchecked_Deallocation (Arena, Arena_Access);

   protected Count is
      procedure Made;
      procedure Gone;
      function Value return Natural;
   private
      Live : Natural := 0;
   end Count;

   protected body Count is
      procedure Made is
      begin
         Live := Live + 1;
      end Made;
      procedure Gone is
      begin
         Live := Live - 1;
      end Gone;
      function Value return Natural
      is (Live);
   end Count;

   function Live_Arenas return Natural
   is (Count.Value);

   function Home_Of (Item : not null Handle) return access Arena
   is (Arena (Item.all)'Unrestricted_Access);

   overriding
   function Create_Subpool (Self : in out Pool_Type) return not null Handle is
      Made : constant Arena_Access := new Arena;
   begin
      Subpools.Set_Pool_Of_Subpool (Subpools.Subpool_Handle (Made), Self);
      Count.Made;
      return Subpools.Subpool_Handle (Made);
   end Create_Subpool;

   overriding
   function Default_Subpool_For_Pool (Self : in out Pool_Type) return not null Handle is
   begin
      raise Program_Error with "an object of a view is allocated in an arena: new (Arena) ...";
      return Self.Default_Subpool_For_Pool;
   end Default_Subpool_For_Pool;

   function Aligned (Where : System.Address; Alignment : Storage_Count) return Storage_Count
   is ((Alignment - Storage_Count (To_Integer (Where) mod Integer_Address (Alignment))) mod Alignment);
   --  How far on from Where an address with that alignment is.

   overriding
   procedure Allocate_From_Subpool
     (Self                     : in out Pool_Type;
      Storage_Address          : out System.Address;
      Size_In_Storage_Elements : System.Storage_Elements.Storage_Count;
      Alignment                : System.Storage_Elements.Storage_Count;
      Subpool                  : not null Handle)
   is
      pragma Unreferenced (Self);
      Home  : constant not null access Arena := Home_Of (Subpool);
      Align : constant Storage_Count := Storage_Count'Max (Alignment, 1);
   begin
      --  The next byte has no array index when the block is exactly full.
      if Home.Blocks /= null and then Home.Blocks.Used < Home.Blocks.Data'Length then
         declare
            Top  : Block renames Home.Blocks.all;
            Skip : constant Storage_Count := Aligned (Top.Data (Top.Data'First + Top.Used)'Address, Align);
         begin
            if Top.Used + Skip + Size_In_Storage_Elements <= Top.Data'Length then
               Storage_Address := Top.Data (Top.Data'First + Top.Used + Skip)'Address;
               Top.Used := Top.Used + Skip + Size_In_Storage_Elements;
               return;
            end if;
         end;
      end if;
      declare
         Wanted : constant Storage_Count := Storage_Count'Max (Block_Size, Size_In_Storage_Elements + Align);
         Data   : Storage_Block := new Storage_Array (0 .. Wanted - 1);
         Fresh  : Block_Access;
         Skip   : constant Storage_Count := Aligned (Data (0)'Address, Align);
      begin
         begin
            Fresh := new Block'(Data => Data, Used => Skip + Size_In_Storage_Elements, Next => Home.Blocks);
         exception
            when others =>
               Free (Data);
               raise;
         end;
         Home.Blocks := Fresh;
         Home.Count := Home.Count + 1;
         Home.Held := Home.Held + Natural (Wanted);
         Storage_Address := Data (Skip)'Address;
      end;
   end Allocate_From_Subpool;

   overriding
   procedure Deallocate_Subpool (Self : in out Pool_Type; Subpool : in out Handle) is
      pragma Unreferenced (Self);
      Home : constant not null access Arena := Home_Of (Subpool);
      Next : Block_Access;
   begin
      while Home.Blocks /= null loop
         Next := Home.Blocks.Next;
         Free (Home.Blocks.Data);
         Free (Home.Blocks);
         Home.Blocks := Next;
      end loop;
      declare
         Whole : Arena_Access := Arena_Access'(Arena (Subpool.all)'Unrestricted_Access);
      begin
         Free (Whole);
         Subpool := null;
         Count.Gone;
      end;
   end Deallocate_Subpool;

   function Make return not null Handle is
   begin
      return Create_Subpool (Pool);
   end Make;

   procedure Destroy (Item : in out Handle) is
   begin
      if Item /= null then
         Ada.Unchecked_Deallocate_Subpool (Item);
      end if;
   end Destroy;

   function Bytes_Held (Item : not null Handle) return Natural
   is (Home_Of (Item).Held);

   function Block_Count (Item : not null Handle) return Natural
   is (Home_Of (Item).Count);

end Pomarine.UI.Arenas;
