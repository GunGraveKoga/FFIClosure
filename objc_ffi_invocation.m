#import <ObjFW/ObjFW.h>
#import "objc_ffi_invocation.h"
#import "objc_signature.h"
#import "objc_types_conversion.h"

#include <ffi.h>

typedef struct allocator_buffer_s allocator_buffer_t;
typedef struct allocator_buffers_set_s allocator_buffers_set_t;

extern allocator_buffers_set_t * new_allocator(void);
extern void * allocator_alloc(allocator_buffers_set_t * allocator, size_t size);
extern void delete_allocator(allocator_buffers_set_t * allocator);

typedef struct objc_invocation_ctx_s {
    __unsafe_unretained id _self;
    SEL _cmd;
    IMP _imp;

} objc_invocation_ctx_t;

typedef struct ffi_invocation_s {
    objc_invocation_ctx_t _ctx;
    ffi_cif _cif;
    unsigned int _argc;
    void * _ret;
    allocator_buffers_set_t * _memoryPool;

} ffi_invocation_t;


#define INVOCATION_CTX(self) (&(self)->_ctx)

static OF_INLINE uintptr_t DISGUISE(void * value) {
    return ~(uintptr_t)(value);
}

static OF_INLINE void * UNDISGUISE(uintptr_t uptr) {
    return (void *)(~uptr);
}


static ffi_invocation_t * new_invocation(void) {
    ffi_invocation_t * invocation = calloc(1, sizeof(struct ffi_invocation_s));

    if (NULL != invocation) {
        INVOCATION_CTX(invocation)->_self = nil;
        INVOCATION_CTX(invocation)->_cmd = NULL;
        INVOCATION_CTX(invocation)->_imp = NULL;
        invocation->_memoryPool = new_allocator();

        if (NULL != (invocation->_memoryPool))
            return invocation;

        free(invocation);
    }

    return NULL;
}

static void delete_invocation(ffi_invocation_t * invocation) {
    delete_allocator((invocation->_memoryPool));

    INVOCATION_CTX(invocation)->_self = nil;
    INVOCATION_CTX(invocation)->_cmd = NULL;
    INVOCATION_CTX(invocation)->_imp = NULL;

    free(invocation);
}


ffi_handle_t ffi_invocation_new(const char * method_signature) {
    ffi_invocation_t * invocation = new_invocation();

    if (NULL != invocation) {
        ffi_type * ret = NULL;
        int argc = 0;
        ffi_type ** argv = NULL;

        @try {
            argv = of_cfunction_args_list(method_signature, &argc, &ret, (void *(*)(void *, size_t)) & allocator_alloc, (invocation->_memoryPool));
        } @catch (...) {
            delete_invocation(invocation);

            return FFI_INVALID_HANDLE;
        }

        invocation->_argc = (__typeof__(invocation->_argc))argc;

        ffi_status rc;

        if ((rc = ffi_prep_cif(&(invocation->_cif), FFI_DEFAULT_ABI, invocation->_argc, ret, argv)) == FFI_OK) {
            return DISGUISE(invocation);
        }

        delete_invocation(invocation);
    }

    return FFI_INVALID_HANDLE;
} /* ffi_invocation_new */
