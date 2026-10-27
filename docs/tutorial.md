# Build your first Pomarine app

This guide builds a macOS window with a greeting and a button. Clicking **Say hello** updates the greeting;
the same command works from the keyboard. The model has no widgets, and the screen declares its bindings with
`Pomarine.UI`. The code is the tested `hello_gui` example.

## Prerequisites and a first run

Use macOS, Xcode Command Line Tools, Alire with an Ada 2022 GNAT compiler and GPRbuild, and SDL3 plus SDL3_image.
The SDL projects link `-lSDL3` and `-lSDL3_image`; their libraries must be in your linker's search path.
For a Homebrew installation these are the `sdl3` and `sdl3_image` formulae. CoreText comes with macOS; Yoga's
vendored C++ sources build with the project. Rust/Cargo is needed for the optional native accessibility/menu
crate and the library test suite.

```sh
git clone --recursive https://github.com/fncsftya/pomarine.git
cd pomarine/examples
alr build
alr run hello_gui
```

In a Bonxie checkout, Pomarine is already a submodule: run `git submodule update --init --recursive` from
Bonxie, then `cd pomarine/examples`. `alr run gallery_gui` opens the control gallery; scroll to reach the lower
sections in a shorter window.

## Make an application of your own

Create a new crate outside that checkout:

```sh
alr init --bin first_app
cd first_app
mkdir -p vendor src/view_models
git clone --recursive https://github.com/fncsftya/pomarine.git vendor/pomarine
cp vendor/pomarine/examples/src/greeter.ads src/
cp vendor/pomarine/examples/src/greeter.adb src/
cp vendor/pomarine/examples/src/view_models/greeter_vm.ads src/view_models/
cp vendor/pomarine/examples/src/view_models/greeter_vm.adb src/view_models/
```

Keep the generated metadata in `alire.toml` and add these dependencies and local pins. Pin all the sibling
crates at the application root so Alire resolves one coherent checkout. You can keep `vendor/pomarine` as a Git
submodule instead of a clone when your application has a repository.

```toml
[[depends-on]]
pomarine_ui = "*"
pomarine_vm = "*"

[[pins]]
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

Replace `first_app.gpr` with:

```gpr
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

Replace `src/first_app.adb` with:

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

Run `alr build` and `alr run`. Click **Say hello**, or press Tab and Return. Close the window to finish.

`Run_Window` makes the window, the tree and the view in the order that is their lifetime order (the window
outlives the tree, the tree outlives the view) and has `Greeter.Build` make the screen of the model, which the
caller declares first, as it must outlive the view. A program that needs the pieces itself (a second window, a
borrowed control kept beside the view) declares them as `Pomarine.Windows`, `Pomarine.Widgets.Tree` and
`Pomarine.UI.View` say. A view owns controls it creates through a context, but only borrows app-owned controls.

## How the greeting changes

Read `src/view_models/greeter_vm.ads` and `.adb`. `Greeter_VM.Model` derives from a command model. Its
`Count` and `Message` queries describe state. `Can_Execute` permits the command only at index zero and while
incrementing cannot overflow; `Perform` increments the count, and the `Observed_Model` it derives from counts
the change (`Mark_Changed`, which a property set by a widget calls itself) and refuses an unavailable command.
Its postcondition checks the resulting count. Keep rules and persistence here, independent of widgets.

Read `src/greeter.ads`. It instantiates `UI.Contexts` for that model and its commands, then makes a property of
the model's own `Message` function with `Showing`. A label reads model text through it when its watched version
changes.

In `src/greeter.adb`, `Build` binds the model and makes the controls and the layout in one expression:

```ada
UI.Column ([Bound.Label (Greeting, Centered => True, Width => 200.0, Height => 24.0),
            Bound.Button ("Say hello", Greeter_VM.Say_Hello, Look => Pomarine.Widgets.Buttons.Primary,
                          Focusable => True, Width => 120.0, Height => 32.0)],
           Align => UI.Layouts.Center, Spread => UI.Layouts.Center, Padding => 16.0, Gap => 12.0, Grow => 1.0);
```

`Build` builds the layout once and calls `UI.Mount`. Later turns refresh the affected bindings without rebuilding the component. Button
availability follows `Can_Execute`. Geometry, focus, drawing and continuous gestures belong in the view.
Layouts use points; the window supplies display density. Use `Grow` for flexible space instead of computing
screen coordinates. See [UI.md](../UI.md) for fields, lists, indexed commands and borrowed controls.

## Test behavior before drawing

The checked-in example already has an offscreen integration test:

```sh
cd vendor/pomarine/examples/tests
alr exec -- gprbuild -P todo_tests.gpr
bin/example_views_test
bin/gallery_vm_test
bin/gallery_view_test
```

`example_views_test.adb` checks the greeting's model contract, clicks the button by semantic name, exercises
Tab/Return, and checks that a change made directly to the model reaches the view on the next turn. A test's
basic shape is:

```ada
Greeter.Build (Screen, Model'Access);
Pomarine.Testing.Open (Session, Tree, 320, 160);
Pomarine.Testing.Click_On (Session, "Say hello");
pragma Assert (Greeter_VM.Count (Model) = 1);
pragma Assert (Pomarine.Testing.Shows (Session, "Hello again, x 1!"));
```

Declare the tree, model, view and session as in that test. Give controls useful accessible names; labels often
supply them automatically. `Testing.Act_On` can request accessibility actions by name, such as Focus,
Increment or Collapse. Test model rules alone first, production bindings through `Pomarine.Testing`, and
appearance through goldens. [TESTING.md](../TESTING.md) describes the commands and image-review workflow.

## Next controls

The gallery's `Specimens` shows how to borrow an app-owned control with `Borrow_Widget`. It includes
`Choice_Groups` for tabs, segments and radio groups, `Number_Fields` for typed integers, `Steppers` for
incrementing, `Splitters`, `Disclosures`, and a rich-text editor with its own document. A number field commits
on Return or focus loss, retains invalid drafts without changing its value, and restores on Escape; listen
for Change to update your model. Programmatic setters stay quiet.

`Selects` opens its own choice menu. `Menus` with `Overlays` provides context menus; `Popovers` and
`Dialogs` provide anchored or modal content. Keep overlay content under the root outside any scroller.
`Pomarine.Dialogs.Open_File` and `Save_File` are asynchronous native file panels: check `File_State` in the
application's loop or idle callback, copy `File_Path` when Chosen, then `Reset_File`.

The alpha targets macOS and one native window loop. Tree/table views, date/colour pickers, bidi/RTL,
localization, touch gestures, secondary-window routing and drag and drop remain outside this alpha.
