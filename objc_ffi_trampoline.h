#import <ObjFW/OFObject.h>

enum {
#if defined(OF_HAVE_BLOCKS)
    FFI_TRAMPOLINE_BLOCK = 0,
    FFI_TRAMPOLINE_BLOCK_IMP = 1,
#endif
    FFI_TRAMPOLINE_SEL_IMP = 2
};

typedef uintptr_t ffi_handle_t;

#define FFI_INVALID_HANDLE (ffi_handle_t)0


ffi_handle_t ffi_closure_new(int type, ...);

void ffi_closure_delete(ffi_handle_t handle);

void * ffi_closure_function(ffi_handle_t handle);
