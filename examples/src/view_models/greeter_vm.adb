package body Greeter_VM is
   function Count (Self : Model) return Natural is (Self.Greetings);

   function Message (Self : Model) return String is
     (if Count (Self) = 0 then "Hello, world!" else "Hello again, x" & Count (Self)'Image & "!");

   overriding function Can_Execute (Self : Model; What : Command; Index : Natural := 0) return Boolean is
     (case What is when Say_Hello => Index = 0 and then Count (Self) < Natural'Last);

   overriding procedure Perform (Self : in out Model; What : Command; Index : Natural := 0) is
      pragma Unreferenced (Index);
   begin
      case What is
         when Say_Hello => Self.Greetings := @ + 1;
      end case;
   end Perform;
end Greeter_VM;
