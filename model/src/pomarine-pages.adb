with Ada.Unchecked_Deallocation;

package body Pomarine.Pages is

   procedure Release is new Ada.Unchecked_Deallocation (Page, Page_Access);

   procedure Free (Item : in out Page_Access) is
   begin
      Release (Item);
   end Free;

   procedure Release_Sizes is
     new Ada.Unchecked_Deallocation (Size_Array, Size_Array_Access);

   procedure Free (Item : in out Size_Array_Access) is
   begin
      Release_Sizes (Item);
   end Free;

end Pomarine.Pages;
