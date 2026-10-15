//! The application's menu bar, and the system's settings that Pomarine
//! looks at. macOS only; everything is on the main thread.

use objc2::rc::Id;
use objc2::runtime::{AnyObject, NSObject};
use objc2::{declare_class, msg_send_id, mutability, sel, ClassType, DeclaredClass};
use objc2_app_kit::{NSApplication, NSEventModifierFlags, NSMenu, NSMenuItem, NSWorkspace};
use objc2_foundation::{MainThreadMarker, NSString};
use std::cell::RefCell;
use std::ffi::c_void;
use std::sync::Mutex;

type MenuFn = extern "C" fn(user: *mut c_void, tag: i32);

struct Handler {
    callback: MenuFn,
    user: usize,
}

static HANDLER: Mutex<Option<Handler>> = Mutex::new(None);

declare_class!(
    struct MenuTarget;

    unsafe impl ClassType for MenuTarget {
        type Super = NSObject;
        type Mutability = mutability::MainThreadOnly;
        const NAME: &'static str = "PomarineMenuTarget";
    }

    impl DeclaredClass for MenuTarget {}

    unsafe impl MenuTarget {
        #[method(fire:)]
        fn fire(&self, sender: &NSMenuItem) {
            let tag = unsafe { sender.tag() } as i32;
            if let Some(handler) = HANDLER.lock().unwrap().as_ref() {
                (handler.callback)(handler.user as *mut c_void, tag);
            }
        }
    }
);

struct State {
    target: Id<MenuTarget>,
    items: Vec<(i32, Id<NSMenuItem>)>,
}

thread_local! {
    static STATE: RefCell<Option<State>> = const { RefCell::new(None) };
}

fn text(pointer: *const u8, length: u32) -> String {
    if pointer.is_null() || length == 0 {
        return String::new();
    }
    unsafe { String::from_utf8_lossy(std::slice::from_raw_parts(pointer, length as usize)).into_owned() }
}

/// Be told, with `tag`, when a menu item is chosen.
#[no_mangle]
pub extern "C" fn pn_menu_install(callback: MenuFn, user: *mut c_void) -> u8 {
    let Some(mtm) = MainThreadMarker::new() else { return 0 };
    *HANDLER.lock().unwrap() = Some(Handler { callback, user: user as usize });
    STATE.with(|state| {
        let mut state = state.borrow_mut();
        if state.is_none() {
            let target: Id<MenuTarget> = unsafe { msg_send_id![mtm.alloc::<MenuTarget>(), init] };
            *state = Some(State { target, items: Vec::new() });
        }
    });
    1
}

/// A menu in the menu bar, after those there are; its handle.
#[no_mangle]
pub unsafe extern "C" fn pn_menu_add_menu(title: *const u8, length: u32) -> *mut c_void {
    let Some(mtm) = MainThreadMarker::new() else { return std::ptr::null_mut() };
    let app = NSApplication::sharedApplication(mtm);
    let bar = match app.mainMenu() {
        Some(bar) => bar,
        None => {
            let bar = NSMenu::new(mtm);
            app.setMainMenu(Some(&bar));
            bar
        }
    };
    let name = NSString::from_str(&text(title, length));
    let menu = NSMenu::initWithTitle(mtm.alloc(), &name);
    menu.setAutoenablesItems(false);
    let entry = NSMenuItem::new(mtm);
    entry.setTitle(&name);
    entry.setSubmenu(Some(&menu));
    bar.addItem(&entry);
    Id::into_raw(menu) as *mut c_void
}

/// An item of the menu, that says `tag` when chosen; `key` is its key
/// equivalent (empty for none); `modifiers`: 1 Command, 2 Shift, 4 Option, 8
/// Control.
#[no_mangle]
pub unsafe extern "C" fn pn_menu_add_item(
    menu: *mut c_void,
    title: *const u8,
    title_length: u32,
    key: *const u8,
    key_length: u32,
    modifiers: u32,
    tag: i32,
) {
    let Some(mtm) = MainThreadMarker::new() else { return };
    let menu: &NSMenu = &*(menu as *const NSMenu);
    let title = NSString::from_str(&text(title, title_length));
    let key = NSString::from_str(&text(key, key_length));
    STATE.with(|state| {
        let mut state = state.borrow_mut();
        let Some(state) = state.as_mut() else { return };
        let item = NSMenuItem::initWithTitle_action_keyEquivalent(
            mtm.alloc(),
            &title,
            Some(sel!(fire:)),
            &key,
        );
        let mut mask = NSEventModifierFlags::empty();
        if modifiers & 1 != 0 { mask |= NSEventModifierFlags::NSEventModifierFlagCommand; }
        if modifiers & 2 != 0 { mask |= NSEventModifierFlags::NSEventModifierFlagShift; }
        if modifiers & 4 != 0 { mask |= NSEventModifierFlags::NSEventModifierFlagOption; }
        if modifiers & 8 != 0 { mask |= NSEventModifierFlags::NSEventModifierFlagControl; }
        item.setKeyEquivalentModifierMask(mask);
        item.setTag(tag as isize);
        let target: &AnyObject = &*state.target;
        item.setTarget(Some(target));
        menu.addItem(&item);
        state.items.push((tag, item));
    });
}

#[no_mangle]
pub unsafe extern "C" fn pn_menu_add_separator(menu: *mut c_void) {
    let Some(mtm) = MainThreadMarker::new() else { return };
    let menu: &NSMenu = &*(menu as *const NSMenu);
    menu.addItem(&NSMenuItem::separatorItem(mtm));
}

/// What the command is for now: whether it is offered at all, can be done,
/// and is in force (ticked).
#[no_mangle]
pub extern "C" fn pn_menu_set_state(tag: i32, offered: u8, enabled: u8, ticked: u8) {
    STATE.with(|state| {
        if let Some(state) = state.borrow().as_ref() {
            for (item_tag, item) in &state.items {
                if *item_tag == tag {
                    unsafe {
                        item.setHidden(offered == 0);
                        item.setEnabled(enabled != 0);
                        item.setState(if ticked != 0 { 1 } else { 0 });
                    }
                }
            }
        }
    });
}

/// Whether the system is set to reduce motion (bit 0), increase contrast
/// (bit 1), or reduce transparency (bit 2).
#[no_mangle]
pub extern "C" fn pn_display_settings() -> u32 {
    let workspace = unsafe { NSWorkspace::sharedWorkspace() };
    let mut bits = 0;
    unsafe {
        if workspace.accessibilityDisplayShouldReduceMotion() { bits |= 1; }
        if workspace.accessibilityDisplayShouldIncreaseContrast() { bits |= 2; }
        if workspace.accessibilityDisplayShouldReduceTransparency() { bits |= 4; }
    }
    bits
}
