# Build your first Pomarine app

Build a window with a greeting and a **Say hello** button. The button runs a model command, and the label
updates from the model. You can also use Tab and Return.

![The initial greeting and button](images/tutorial-hello.png)
![The greeting after one click](images/tutorial-clicked.png)

## Run the reference

You need macOS, Xcode Command Line Tools, Alire with an Ada 2022 GNAT compiler and GPRbuild, and SDL3 and
SDL3_image on the linker search path (Homebrew: `sdl3` and `sdl3_image`). CoreText ships with macOS; Yoga is
built from vendored sources.

From a directory where you want the checkout:

```sh
git clone --recursive https://github.com/fncsftya/pomarine.git
cd pomarine/tutorial
alr build
alr run first_app
```

Click the button, or press Tab then Return. In a Bonxie checkout, initialize the submodules with
`git submodule update --init --recursive` from the Bonxie root, then run `alr build` and `alr run first_app`
from `pomarine/tutorial`.

The complete source is in [`tutorial/`](../tutorial/). The following steps explain how it fits together.

## Define the model

The model holds the count and the rules for changing it. It does not depend on widgets. In
[`src/view_models/greeter_vm.ads`](../tutorial/src/view_models/greeter_vm.ads):

```ada
with Pomarine.View_Models;

package Greeter_VM is
   type Command is (Say_Hello);
   package Commands is new Pomarine.View_Models.Command_Models (Command);
   type Model is limited new Commands.Observed_Model with private;

   function Count (Self : Model) return Natural;
   function Message (Self : Model) return String;

   overriding
   function Can_Execute (Self : Model; What : Command; Index : Natural := 0) return Boolean;
   overriding
   procedure Perform (Self : in out Model; What : Command; Index : Natural := 0)
   with Post => Count (Self) = Count (Self)'Old + 1;

private
   type Model is limited new Commands.Observed_Model with record
      Greetings : Natural := 0;
   end record;
end Greeter_VM;
```

`Command_Models` gives this model a command interface for its enumeration. `Can_Execute` says whether a command
is available; `Index` identifies an item for commands that act on one. This command has no item, so it uses zero.
`Perform` does the work; its postcondition describes the expected result.

In [`greeter_vm.adb`](../tutorial/src/view_models/greeter_vm.adb), the message depends on the count, and the
command is available while the count can still increase:

```ada
package body Greeter_VM is
   function Count (Self : Model) return Natural is (Self.Greetings);

   function Message (Self : Model) return String
   is (if Count (Self) = 0 then "Hello, world!" else "Hello again, x" & Count (Self)'Image & "!");

   overriding
   function Can_Execute (Self : Model; What : Command; Index : Natural := 0) return Boolean
   is (case What is
         when Say_Hello => Index = 0 and then Count (Self) < Natural'Last);

   overriding
   procedure Perform (Self : in out Model; What : Command; Index : Natural := 0) is
      pragma Unreferenced (Index);
   begin
      case What is
         when Say_Hello =>
            Self.Greetings := @ + 1;
      end case;
   end Perform;
end Greeter_VM;
```

Call `Execute` to run a command from application code. `Observed_Model.Execute` calls `Perform` and marks the
model changed, so bindings know to refresh. UI command routing checks `Can_Execute`; direct calls to `Execute`
are subject to its precondition and assertion, whose enforcement depends on assertion policy. The tutorial enables
contracts and runtime checks. Do not call `Perform` directly: it bypasses `Execute`'s check and change tracking.
When a setter changes displayed state outside a command, call `Mark_Changed` or account for the change through
`Parts_Version`; see [`Pomarine.View_Models`](../vm/src/pomarine-view_models.ads).

## Bind and build the view

The view describes controls and their bindings. In [`src/greeter.ads`](../tutorial/src/greeter.ads), instantiate a
context for the model and expose `Message` as a read-only text property:

```ada
with Greeter_VM;
with Pomarine.UI;
with Pomarine.UI.Contexts;

package Greeter is
   package UI renames Pomarine.UI;
   package Controls is new UI.Contexts (Greeter_VM.Commands, Greeter_VM.Model);

   Greeting : constant Controls.Text_Property := Controls.Showing (Greeter_VM.Message'Access);

   procedure Build (Screen : in out UI.View; Model : not null access Greeter_VM.Model);
   --  Model must outlive Screen.
end Greeter;
```

In [`greeter.adb`](../tutorial/src/greeter.adb), `Bind` connects the view to the model. The label reads the
property, the button invokes the command, and `Mount` installs the layout:

```ada
with Pomarine.Widgets.Buttons;

package body Greeter is
   procedure Build (Screen : in out UI.View; Model : not null access Greeter_VM.Model) is
      Bound : constant Controls.Context'Class := Controls.Bind (Screen, Model);
      Whole : constant UI.Layout :=
        UI.Column
          ([Bound.Label (Greeting, Centered => True, Width => 200.0, Height => 24.0),
            Bound.Button
              ("Say hello", Greeter_VM.Say_Hello,
               Look => Pomarine.Widgets.Buttons.Primary, Focusable => True,
               Width => 120.0, Height => 32.0)],
           Align => UI.Layouts.Center, Spread => UI.Layouts.Center,
           Padding => 16.0, Gap => 12.0, Grow => 1.0);
   begin
      UI.Mount (Screen, Whole);
   end Build;
end Greeter;
```

The layout is built once. Bindings refresh when the model version changes, and button availability follows
`Can_Execute`. `Focusable => True` lets the button take keyboard focus. Dimensions are in points; the window
supplies display density. The explicit sizes give this example its pictured proportions; controls also have default
sizes. Keep application rules and persistence in the model; geometry, focus, painting, and continuous gestures
belong in the view.

## Open the window

[`src/first_app.adb`](../tutorial/src/first_app.adb) instantiates `Run_Window` with the model type and the build
procedure, then opens the window:

```ada
with Greeter;
with Greeter_VM;
with Pomarine.UI.Run_Window;

procedure First_App is
   procedure Show is new Pomarine.UI.Run_Window (Greeter_VM.Model, Greeter.Build);
   Model : aliased Greeter_VM.Model;
begin
   Show (Model, "My first app", 320, 160);
end First_App;
```

The model must outlive every use of the view. Here `Model` lives for the whole call to `Show`, and `Run_Window`
manages the window, tree, and view in lifetime order. See [UI.md](../UI.md) for constructing those objects yourself.

## Make your own copy

From the root of a Pomarine checkout, copy the application sources and vendor Pomarine into the new project:

```sh
mkdir -p first_app/vendor
cp -R tutorial/src first_app/
cd first_app
git clone --recursive https://github.com/fncsftya/pomarine.git vendor/pomarine
```

Create `alire.toml` in `first_app` with the application dependencies and pins pointing to the same checkout:

```toml
name = "first_app"
description = "My first Pomarine app"
version = "0.1.0-dev"
licenses = "MIT"
executables = ["first_app"]

[available.'case(os)']
macos = true
'...' = false

[[depends-on]]
pomarine_ui = "*"
pomarine_vm = "*"

[[pins]]
pomarine = { path = "vendor/pomarine" }
pomarine_ui = { path = "vendor/pomarine/ui" }
pomarine_vm = { path = "vendor/pomarine/vm" }
pomarine_model = { path = "vendor/pomarine/model" }
coretext = { path = "vendor/pomarine/coretext" }
sdl3 = { path = "vendor/pomarine/sdl3" }
texts = { path = "vendor/pomarine/texts" }
typeset = { path = "vendor/pomarine/typeset" }
yoga = { path = "vendor/pomarine/yoga" }

[build-switches]
"*".ada_version = "Ada2022"
"*".contracts = "Yes"
"*".runtime_checks = "Everything"
```

Create `first_app.gpr` alongside it:

```ada
with "pomarine_ui.gpr";
with "pomarine_vm.gpr";
project First_App is
   for Source_Dirs use ("src", "src/view_models");
   for Object_Dir use "obj";
   for Exec_Dir use "bin";
   for Create_Missing_Dirs use "True";
   for Main use ("first_app.adb");
   package Compiler is
      for Default_Switches ("Ada") use ("-gnat2022", "-gnata", "-gnatyM120");
   end Compiler;
end First_App;
```

From `first_app`, run `alr build` and `alr run first_app`. The copied `src/capture.adb` is not a main in this
project and can be removed; it belongs to the reference's screenshot workflow and needs `pomarine_testing`.

## Test and capture

The reference's [`capture`](../tutorial/src/capture.adb) program builds the tutorial view offscreen, checks the
initial greeting, clicks the button by semantic name, and checks the result. It paints both states with SDL's
software renderer and saves PNGs. From the Pomarine repository root:

```sh
cd tutorial
alr build
alr run capture
```

Run it from `tutorial`: it writes to `../docs/images/` relative to that directory. The separate example greeter's
model, bindings, and keyboard interaction are checked by `example_views_test`. From the Pomarine repository root:

```sh
cd examples/tests
alr exec -- gprbuild -P todo_tests.gpr
bin/example_views_test
```

That test exercises the example greeter in `examples/src`, not the tutorial source. Test model rules without
widgets, bindings through `Pomarine.Testing`, and drawing through goldens. See [TESTING.md](../TESTING.md) for the
test and image-review workflows, [UI.md](../UI.md) for more controls and bindings, and the gallery
(`alr run gallery_gui` from `examples/`) for examples.
