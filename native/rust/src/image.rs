//! Native image conversion through Apple's ImageIO framework.

use std::ffi::{c_char, c_void, CStr};
use std::ptr;

type CFTypeRef = *const c_void;
type CFAllocatorRef = CFTypeRef;
type CFIndex = isize;
type CFURLRef = *const c_void;
type CFStringRef = *const c_void;
type CGImageRef = *const c_void;
type CGImageSourceRef = *const c_void;
type CGImageDestinationRef = *mut c_void;

#[link(name = "CoreFoundation", kind = "framework")]
unsafe extern "C" {
    static kCFAllocatorDefault: CFAllocatorRef;
    fn CFRelease(value: CFTypeRef);
    fn CFURLCreateFromFileSystemRepresentation(
        allocator: CFAllocatorRef,
        bytes: *const u8,
        length: CFIndex,
        is_directory: bool,
    ) -> CFURLRef;
    fn CFStringCreateWithCString(
        allocator: CFAllocatorRef,
        value: *const c_char,
        encoding: u32,
    ) -> CFStringRef;
}

#[link(name = "ImageIO", kind = "framework")]
unsafe extern "C" {
    fn CGImageSourceCreateWithURL(url: CFURLRef, options: CFTypeRef) -> CGImageSourceRef;
    fn CGImageSourceCreateImageAtIndex(
        source: CGImageSourceRef,
        index: CFIndex,
        options: CFTypeRef,
    ) -> CGImageRef;
    fn CGImageDestinationCreateWithURL(
        url: CFURLRef,
        image_type: CFStringRef,
        count: CFIndex,
        options: CFTypeRef,
    ) -> CGImageDestinationRef;
    fn CGImageDestinationAddImage(
        destination: CGImageDestinationRef,
        image: CGImageRef,
        properties: CFTypeRef,
    );
    fn CGImageDestinationFinalize(destination: CGImageDestinationRef) -> bool;
}

unsafe fn url(path: &CStr) -> CFURLRef {
    CFURLCreateFromFileSystemRepresentation(
        kCFAllocatorDefault,
        path.to_bytes().as_ptr(),
        path.to_bytes().len() as CFIndex,
        false,
    )
}

/// Convert the first frame of a system-supported image file to PNG.
#[no_mangle]
pub unsafe extern "C" fn pn_image_to_png(input: *const c_char, output: *const c_char) -> i32 {
    if input.is_null() || output.is_null() {
        return 0;
    }
    let input = CStr::from_ptr(input);
    let output = CStr::from_ptr(output);
    let source_url = url(input);
    if source_url.is_null() {
        return 0;
    }
    let output_url = url(output);
    if output_url.is_null() {
        CFRelease(source_url);
        return 0;
    }
    let source = CGImageSourceCreateWithURL(source_url, ptr::null());
    let image_type = CFStringCreateWithCString(
        kCFAllocatorDefault,
        c"public.png".as_ptr(),
        0x0800_0100,
    );
    let image = if source.is_null() {
        ptr::null()
    } else {
        CGImageSourceCreateImageAtIndex(source, 0, ptr::null())
    };
    let destination = if image.is_null() || image_type.is_null() {
        ptr::null_mut()
    } else {
        CGImageDestinationCreateWithURL(output_url, image_type, 1, ptr::null())
    };
    let result = if destination.is_null() {
        false
    } else {
        CGImageDestinationAddImage(destination, image, ptr::null());
        CGImageDestinationFinalize(destination)
    };

    if !destination.is_null() {
        CFRelease(destination);
    }
    if !image.is_null() {
        CFRelease(image);
    }
    if !image_type.is_null() {
        CFRelease(image_type);
    }
    if !source.is_null() {
        CFRelease(source);
    }
    CFRelease(output_url);
    CFRelease(source_url);
    i32::from(result)
}
