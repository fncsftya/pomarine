//! A flat C interface to AccessKit for Pomarine's Ada binding.
//!
//! Nodes arrive as plain structs (`AkNode`), a whole update at a time; what
//! an assistive technology asks for goes back through one callback. Roles
//! and actions are numbered by Pomarine (see accesskit.ads, which must
//! agree with the tables here).
//!
//! Everything here is called on the application's main thread.

#![allow(clippy::missing_safety_doc)]

#[cfg(target_os = "macos")]
mod menu;

use accesskit::{
    Action, ActionData, ActionHandler, ActionRequest, ActivationHandler, Invalid, Live, Node,
    NodeId, Rect, Role, TextPosition, TextSelection, Toggled, TreeId, TreeInfo, TreeUpdate,
};
use std::ffi::c_void;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

#[repr(C)]
pub struct AkNode {
    pub id: u64,
    pub role: u8,
    pub toggled: u8, // 0 none, 1 off, 2 on, 3 mixed
    pub flags: u32,
    pub actions: u32,
    pub left: f64,
    pub top: f64,
    pub right: f64,
    pub bottom: f64,
    pub name: *const u8,
    pub name_len: u32,
    pub value: *const u8,
    pub value_len: u32,
    pub help: *const u8,
    pub help_len: u32,
    pub number: f64,
    pub minimum: f64,
    pub maximum: f64,
    pub step: f64,
    pub anchor_node: u64,
    pub anchor_chars: u32,
    pub caret_node: u64,
    pub caret_chars: u32,
    pub children: *const u64,
    pub child_count: u32,
    pub position: u32,
    pub set_size: u32,
}

const F_DISABLED: u32 = 1 << 0;
const F_SELECTED: u32 = 1 << 1;
const F_EXPANDED: u32 = 1 << 2;
const F_HAS_EXPANDED: u32 = 1 << 3;
const F_READ_ONLY: u32 = 1 << 4;
const F_INVALID: u32 = 1 << 5;
const F_MODAL: u32 = 1 << 6;
const F_LIVE: u32 = 1 << 7;
const F_HAS_NUMBER: u32 = 1 << 8;
const F_HAS_SELECTION: u32 = 1 << 9;
const F_NAMED: u32 = 1 << 10;

/// Roles, as Pomarine.Semantics.Role is numbered by AccessKit.Role_Code.
fn role_of(code: u8, toggled: u8, named: bool) -> Role {
    match code {
        1 => Role::Window,
        2 => if named { Role::Group } else { Role::GenericContainer },
        3 => Role::Label,
        4 => Role::Heading,
        5 => Role::Button,
        6 => Role::Button, // a toggle button: Button with a toggled state
        7 => Role::CheckBox,
        8 => Role::RadioButton,
        9 => Role::Switch,
        10 => Role::Slider,
        11 => Role::ProgressIndicator,
        12 => Role::TextInput,
        13 => Role::MultilineTextInput,
        14 => Role::Menu,
        15 => if toggled != 0 { Role::MenuItemCheckBox } else { Role::MenuItem },
        16 => Role::List,
        17 => Role::ListItem,
        18 => Role::ScrollView,
        19 => Role::Image,
        20 => Role::Canvas,
        21 => Role::Dialog,
        22 => Role::Tooltip,
        23 => Role::Status,
        24 => Role::GenericContainer, // a separator: nothing to say
        25 => Role::Document,
        26 => Role::TextRun,
        _ => Role::Unknown,
    }
}

/// Actions, as Pomarine.Semantics.Action is numbered by AccessKit.Action_Code.
fn action_of(code: u32) -> Option<Action> {
    Some(match code {
        0 => Action::Click,
        1 => Action::Focus,
        2 => Action::Blur,
        3 => Action::Increment,
        4 => Action::Decrement,
        5 => Action::SetValue,
        6 => Action::Expand,
        7 => Action::Collapse,
        8 => Action::ShowContextMenu,
        9 => Action::ScrollIntoView,
        10 => Action::ScrollUp,
        11 => Action::ScrollDown,
        12 => Action::ScrollLeft,
        13 => Action::ScrollRight,
        14 => Action::ReplaceSelectedText,
        15 => Action::SetTextSelection,
        16 => Action::ShowTooltip,
        17 => Action::HideTooltip,
        _ => return None,
    })
}

fn code_of(action: Action) -> Option<u32> {
    Some(match action {
        Action::Click => 0,
        Action::Focus => 1,
        Action::Blur => 2,
        Action::Increment => 3,
        Action::Decrement => 4,
        Action::SetValue => 5,
        Action::Expand => 6,
        Action::Collapse => 7,
        Action::ShowContextMenu => 8,
        Action::ScrollIntoView => 9,
        Action::ScrollUp => 10,
        Action::ScrollDown => 11,
        Action::ScrollLeft => 12,
        Action::ScrollRight => 13,
        Action::ReplaceSelectedText => 14,
        Action::SetTextSelection => 15,
        Action::ShowTooltip => 16,
        Action::HideTooltip => 17,
        _ => return None,
    })
}

unsafe fn text(pointer: *const u8, length: u32) -> String {
    if pointer.is_null() || length == 0 {
        return String::new();
    }
    String::from_utf8_lossy(std::slice::from_raw_parts(pointer, length as usize)).into_owned()
}

/// For a run of text: how many bytes each character takes, and where the
/// words start, in characters.
fn run_measures(value: &str) -> (Vec<u8>, Vec<u8>) {
    let mut lengths = Vec::with_capacity(value.len());
    let mut starts = Vec::new();
    let mut in_word = false;
    for (index, character) in value.chars().enumerate() {
        lengths.push(character.len_utf8() as u8);
        let word = !character.is_whitespace();
        if word && !in_word && index <= u8::MAX as usize {
            starts.push(index as u8);
        }
        in_word = word;
    }
    (lengths, starts)
}

unsafe fn build(raw: &AkNode) -> Node {
    let named = raw.flags & F_NAMED != 0;
    let mut node = Node::new(role_of(raw.role, raw.toggled, named));
    let label = text(raw.name, raw.name_len);
    let value = text(raw.value, raw.value_len);
    let help = text(raw.help, raw.help_len);
    if raw.role == 26 {
        // A run of text carries its characters, not a label.
        let (lengths, starts) = run_measures(&value);
        node.set_value(value);
        node.set_character_lengths(lengths);
        node.set_word_starts(starts);
    } else {
        if !label.is_empty() {
            node.set_label(label);
        }
        if !value.is_empty() {
            node.set_value(value);
        }
    }
    if !help.is_empty() {
        node.set_description(help);
    }
    if raw.role == 4 {
        node.set_level(1);
    }
    node.set_bounds(Rect { x0: raw.left, y0: raw.top, x1: raw.right, y1: raw.bottom });
    if raw.flags & F_DISABLED != 0 {
        node.set_disabled();
    }
    if raw.flags & F_SELECTED != 0 {
        node.set_selected(true);
    }
    if raw.flags & F_HAS_EXPANDED != 0 {
        node.set_expanded(raw.flags & F_EXPANDED != 0);
    }
    if raw.flags & F_READ_ONLY != 0 {
        node.set_read_only();
    }
    if raw.flags & F_INVALID != 0 {
        node.set_invalid(Invalid::True);
    }
    if raw.flags & F_MODAL != 0 {
        node.set_modal();
    }
    if raw.flags & F_LIVE != 0 {
        node.set_live(Live::Polite);
    }
    match raw.toggled {
        1 => node.set_toggled(Toggled::False),
        2 => node.set_toggled(Toggled::True),
        3 => node.set_toggled(Toggled::Mixed),
        _ => {}
    }
    if raw.flags & F_HAS_NUMBER != 0 {
        node.set_numeric_value(raw.number);
        node.set_min_numeric_value(raw.minimum);
        node.set_max_numeric_value(raw.maximum);
        if raw.step > 0.0 {
            node.set_numeric_value_step(raw.step);
        }
    }
    for code in 0..32u32 {
        if raw.actions & (1 << code) != 0 {
            if let Some(action) = action_of(code) {
                node.add_action(action);
            }
        }
    }
    if raw.flags & F_HAS_SELECTION != 0 {
        node.set_text_selection(TextSelection {
            anchor: TextPosition {
                node: NodeId(raw.anchor_node),
                character_index: raw.anchor_chars as usize,
            },
            focus: TextPosition {
                node: NodeId(raw.caret_node),
                character_index: raw.caret_chars as usize,
            },
        });
    }
    if raw.set_size > 0 {
        node.set_size_of_set(raw.set_size as usize);
        node.set_position_in_set(raw.position as usize);
    }
    if raw.child_count > 0 && !raw.children.is_null() {
        let ids = std::slice::from_raw_parts(raw.children, raw.child_count as usize);
        node.set_children(ids.iter().map(|id| NodeId(*id)).collect::<Vec<_>>());
    }
    node
}

pub struct Update {
    nodes: Vec<(NodeId, Node)>,
    root: u64,
    focus: u64,
    whole: bool,
}

/// Begin an update of the tree whose root is `root` and whose focus is
/// `focus`. `whole` is for a tree that is all there is of it.
#[no_mangle]
pub extern "C" fn ak_update_new(root: u64, focus: u64, whole: u8) -> *mut Update {
    Box::into_raw(Box::new(Update { nodes: Vec::new(), root, focus, whole: whole != 0 }))
}

#[no_mangle]
pub unsafe extern "C" fn ak_update_add(update: *mut Update, raw: *const AkNode) {
    let update = &mut *update;
    let raw = &*raw;
    update.nodes.push((NodeId(raw.id), build(raw)));
}

#[no_mangle]
pub unsafe extern "C" fn ak_update_free(update: *mut Update) {
    if !update.is_null() {
        drop(Box::from_raw(update));
    }
}

type ActivationFn = extern "C" fn(user: *mut c_void);
type ActionFn = extern "C" fn(
    user: *mut c_void,
    action: u32,
    node: u64,
    number: f64,
    value: *const u8,
    value_len: u32,
    anchor_node: u64,
    anchor_chars: u32,
    focus_node: u64,
    focus_chars: u32,
);

struct User(*mut c_void);
unsafe impl Send for User {}

struct Activation {
    user: User,
    callback: ActivationFn,
    active: Arc<AtomicBool>,
}

impl ActivationHandler for Activation {
    fn request_initial_tree(&mut self) -> Option<TreeUpdate> {
        // The tree is sent from the application's next turn, which this
        // wakes: it cannot be made from here.
        self.active.store(true, Ordering::SeqCst);
        (self.callback)(self.user.0);
        None
    }
}

struct Actions {
    user: User,
    callback: ActionFn,
}

impl ActionHandler for Actions {
    fn do_action(&mut self, request: ActionRequest) {
        let Some(code) = code_of(request.action) else { return };
        let (mut number, mut value, mut sel) = (0.0f64, String::new(), (0u64, 0u32, 0u64, 0u32));
        match request.data {
            Some(ActionData::NumericValue(n)) => number = n,
            Some(ActionData::Value(v)) => value = v.into_string(),
            Some(ActionData::SetTextSelection(s)) => {
                sel = (
                    s.anchor.node.0,
                    s.anchor.character_index as u32,
                    s.focus.node.0,
                    s.focus.character_index as u32,
                )
            }
            _ => {}
        }
        (self.callback)(
            self.user.0,
            code,
            request.target_node.0,
            number,
            value.as_ptr(),
            value.len() as u32,
            sel.0,
            sel.1,
            sel.2,
            sel.3,
        );
    }
}

#[cfg(target_os = "macos")]
pub struct Adapter {
    inner: accesskit_macos::SubclassingAdapter,
    active: Arc<AtomicBool>,
}

/// Make the window's accessibility, which stays quiet until an assistive
/// technology asks: then `activated` is called, and the application is to
/// send the whole tree. `window` is the NSWindow.
#[cfg(target_os = "macos")]
#[no_mangle]
pub unsafe extern "C" fn ak_adapter_new(
    window: *mut c_void,
    activated: ActivationFn,
    acted: ActionFn,
    user: *mut c_void,
) -> *mut Adapter {
    let active = Arc::new(AtomicBool::new(false));
    let inner = accesskit_macos::SubclassingAdapter::for_window(
        window,
        Activation { user: User(user), callback: activated, active: active.clone() },
        Actions { user: User(user), callback: acted },
    );
    Box::into_raw(Box::new(Adapter { inner, active }))
}

#[cfg(target_os = "macos")]
#[no_mangle]
pub unsafe extern "C" fn ak_adapter_free(adapter: *mut Adapter) {
    if !adapter.is_null() {
        drop(Box::from_raw(adapter));
    }
}

/// Whether an assistive technology has asked for the tree.
#[cfg(target_os = "macos")]
#[no_mangle]
pub unsafe extern "C" fn ak_adapter_is_active(adapter: *const Adapter) -> u8 {
    (*adapter).active.load(Ordering::SeqCst) as u8
}

/// Send the update, and free it. Nothing is done if no assistive
/// technology has asked.
#[cfg(target_os = "macos")]
#[no_mangle]
pub unsafe extern "C" fn ak_adapter_send(
    adapter: *mut Adapter,
    update: *mut Update,
    title: *const u8,
    title_len: u32,
) {
    let adapter = &mut *adapter;
    let update = Box::from_raw(update);
    let _ = (title, title_len);
    let Update { nodes, root, focus, whole } = *update;
    let events = adapter.inner.update_if_active(move || TreeUpdate {
        nodes,
        tree: if whole {
            Some(TreeInfo {
                root: NodeId(root),
                toolkit_name: Some("Pomarine".to_string()),
                toolkit_version: Some(env!("CARGO_PKG_VERSION").to_string()),
            })
        } else {
            None
        },
        tree_id: TreeId::ROOT,
        focus: NodeId(focus),
    });
    if let Some(events) = events {
        events.raise();
    }
}

/// The window has gained or lost the focus.
#[cfg(target_os = "macos")]
#[no_mangle]
pub unsafe extern "C" fn ak_adapter_window_focus(adapter: *mut Adapter, focused: u8) {
    if let Some(events) = (*adapter).inner.update_view_focus_state(focused != 0) {
        events.raise();
    }
}
