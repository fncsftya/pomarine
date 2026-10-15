with Interfaces;

package body Pomarine.System_Settings is

   function Settings_Native return Interfaces.Unsigned_32
     with Import, Convention => C, External_Name => "pn_display_settings";

   use type Interfaces.Unsigned_32;

   function Reduce_Motion return Boolean is ((Settings_Native and 1) /= 0);
   function Increase_Contrast return Boolean is ((Settings_Native and 2) /= 0);
   function Reduce_Transparency return Boolean is ((Settings_Native and 4) /= 0);

end Pomarine.System_Settings;
