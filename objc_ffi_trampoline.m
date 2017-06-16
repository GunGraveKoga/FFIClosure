#import <ObjFW/ObjFW.h>
#import "objc_ffi_trampoline.h"
#import "objc_signature.h"
#import "objc_types_conversion.h"
#include <ffi.h>
#include <stdarg.h>

typedef struct objc_impl_placeholder_s {
    __unsafe_unretained id _object;
    SEL _selector;
    IMP _implementation;

} objc_impl_placeholder_t;
#if defined(OF_HAVE_BLOCKS)
typedef struct block_trampoline_ctx_s {
    ffi_cif _cif;
    unsigned int _argc;
    void * _placeholder;

} block_trampoline_ctx_t;
#endif
typedef struct selector_trampoline_ctx_s {
    ffi_cif _cif;
    unsigned int _argc;
    void * _placeholder;

} selector_trampoline_ctx_t;

typedef struct closure_ctx_s {
    ffi_cif _cif;
    unsigned int _argc;
    ffi_closure * _placeholder;
} closure_ctx_t;

typedef struct trampoline_pair_s {
    union {
#if defined(OF_HAVE_BLOCKS)
        block_trampoline_ctx_t _block;
#endif
        selector_trampoline_ctx_t _sel;
    };
    closure_ctx_t _closure;
    int _type;

} trampoline_pair_t;

#if defined(OF_HAVE_BLOCKS)
#define BLOCK_TYPE(self)  (&(self)->_block)
#endif
#define SEL_TYPE(self)    (&(self)->_sel)
#define FFI_CLOSURE(self) (&(self)->_closure)

typedef struct allocator_buffer_s {
    size_t _current;
    void * _pool;
} allocator_buffer_t;

typedef struct allocator_buffers_set_s {
    allocator_buffer_t _buffer;
    struct allocator_buffers_set_s * _next;
} allocator_buffers_set_t;

typedef struct ffi_trampoline_s {
    trampoline_pair_t _pair;
    void (* _call)(ffi_cif *, void *, void **, void *);
    void * _function;
    allocator_buffers_set_t * _memoryPool;

} ffi_trampoline_t;

static OF_INLINE uintptr_t DISGUISE(void * value) {
    return ~(uintptr_t)(value);
}

static OF_INLINE void * UNDISGUISE(uintptr_t uptr) {
    return (void *)(~uptr);
}

static size_t _pageSize = 0;

static of_once_t _pgsz_control = OF_ONCE_INIT;

static void _getPageSize(void) {
    _pageSize = [OFSystemInfo pageSize];
}

allocator_buffers_set_t * new_allocator(void) {
    of_once(&_pgsz_control, &_getPageSize);

    allocator_buffers_set_t * allocator = calloc(1, sizeof(struct allocator_buffers_set_s));

    if (NULL != allocator) {
        allocator_buffer_t * buffer = (__typeof__(buffer))allocator;
        buffer->_pool = calloc(_pageSize, sizeof(uint8_t));

        if (NULL != (buffer->_pool)) {
            buffer->_current = 0;

            allocator->_next = NULL;

            return allocator;
        }

        free(allocator);
    }

    return NULL;
} /* new_allocator */

static void * _buffer_alloc(allocator_buffer_t * buffer, size_t size) {
    of_once(&_pgsz_control, &_getPageSize);

    void * res = NULL;

    if ((_pageSize - buffer->_current) > size) {
        res = ((uint8_t *)buffer->_pool) + buffer->_current;

        memset(res, 0, size);

        buffer->_current += size;

        return res;
    }

    return NULL;
}


void * allocator_alloc(allocator_buffers_set_t * allocator, size_t size) {

    void * res = NULL;

    __typeof__(allocator) ptr = NULL;

    for (ptr = allocator; ptr != NULL; ptr = ptr->_next) {
        if ((res = _buffer_alloc((allocator_buffer_t *)ptr, size)) != NULL)
            return res;
    }

    __typeof__(allocator) _new = new_allocator();

    if (NULL != _new) {
        res = _buffer_alloc((allocator_buffer_t *)_new, size);

        if (NULL != res) {
            ptr->_next = _new;

            return res;
        }

        free(_new);
    }

    return NULL;
} /* allocator_alloc */

void allocator_free(allocator_buffers_set_t * allocator, void * ptr) {
    (void)allocator;
    (void)ptr;
}

void delete_allocator(allocator_buffers_set_t * allocator) {

    __typeof__(allocator) ptr = allocator;

    while (ptr != NULL) {
        __typeof__(allocator) cur = ptr;

        ptr = cur->_next;

        free(((allocator_buffer_t *)cur)->_pool);
        free(cur);
    }

}
#if defined(OF_HAVE_BLOCKS)
static void of_call_block(ffi_cif * cif, void * ret, void ** args, void * userdata);
static void of_call_imp_block(ffi_cif * cif, void * ret, void ** args, void * userdata);
#endif
static void of_call_IMP(ffi_cif * cif, void * ret, void ** args, void * userdata);

static ffi_trampoline_t * new_trampoline(int type) {
    ffi_trampoline_t * trampoline = calloc(1, sizeof(struct ffi_trampoline_s));

    memset(trampoline, 0, sizeof(struct ffi_trampoline_s));

    if (NULL != trampoline) {

        trampoline->_memoryPool = new_allocator();

        if (NULL != (trampoline->_memoryPool)) {
            switch (type) {
#if defined(OF_HAVE_BLOCKS)
                case FFI_TRAMPOLINE_BLOCK:
                    trampoline->_call = &of_call_block;
                    break;
                case FFI_TRAMPOLINE_BLOCK_IMP:
                    trampoline->_call = &of_call_imp_block;
                    break;
#endif
                case FFI_TRAMPOLINE_SEL_IMP:
                {
                    trampoline_pair_t * _ctx = (__typeof__(_ctx))trampoline;
                    SEL_TYPE(_ctx)->_placeholder = calloc(1, sizeof(struct objc_impl_placeholder_s));

                    if (NULL == SEL_TYPE(_ctx)->_placeholder) {
                        delete_allocator(trampoline->_memoryPool);
                        free(trampoline);

                        return NULL;
                    }
                    trampoline->_call = &of_call_IMP;
                }
                break;
                default: {
                    delete_allocator(trampoline->_memoryPool);
                    free(trampoline);
                    return NULL;
                }
            } /* switch */

            trampoline->_pair._type = type;

            return trampoline;
        }

        free(trampoline);
    }

    return NULL;
} /* new_trampoline */


static void delete_trampoline(ffi_trampoline_t * trampoline) {
    trampoline_pair_t * _ctx = (__typeof__(_ctx))trampoline;

    if (NULL != FFI_CLOSURE(_ctx)->_placeholder)
        ffi_closure_free(FFI_CLOSURE(_ctx)->_placeholder);

    trampoline->_call = NULL;

#if defined(OF_HAVE_BLOCKS)
    if (_ctx->_type == FFI_TRAMPOLINE_BLOCK ||
        _ctx->_type == FFI_TRAMPOLINE_BLOCK_IMP) {

        if ((BLOCK_TYPE(_ctx)->_placeholder) != NULL)
            Block_release(BLOCK_TYPE(_ctx)->_placeholder);

    } else if (_ctx->_type == FFI_TRAMPOLINE_SEL_IMP) {
#else
    if (_ctx->_type == FFI_TRAMPOLINE_SEL_IMP) {
#endif
        free(SEL_TYPE(_ctx)->_placeholder);
    }

    delete_allocator(trampoline->_memoryPool);

    free(trampoline);

} /* delete_trampoline */

#if defined(OF_HAVE_BLOCKS)
static void of_call_block(ffi_cif * cif, void * ret, void ** args, void * userdata) {

    (void)cif;

    trampoline_pair_t * tramp = (__typeof__(tramp))userdata;

    void ** argv = calloc(BLOCK_TYPE(tramp)->_argc, sizeof(void *));

    if (NULL == argv) {
        @throw [OFOutOfMemoryException exceptionWithRequestedSize:(BLOCK_TYPE(tramp)->_argc * sizeof(*argv))];
    }

    argv[0] = &(BLOCK_TYPE(tramp)->_placeholder);

    memmove(argv + 1, args, FFI_CLOSURE(tramp)->_argc * sizeof(*args));


    of_block_literal_t * block = BLOCK_TYPE(tramp)->_placeholder;


    @try {
        ffi_call(&(BLOCK_TYPE(tramp)->_cif), (void (*)(void))block->invoke, ret, argv);
    } @finally {
        free(argv);
    }


} /* of_call_block */


static void of_call_imp_block(ffi_cif * cif, void * ret, void ** args, void * userdata) {

    (void)cif;

    trampoline_pair_t * tramp = (__typeof__(tramp))userdata;

    void * object = args[0];

    args[0] = &(BLOCK_TYPE(tramp)->_placeholder);
    args[1] = object;

    of_block_literal_t * block = BLOCK_TYPE(tramp)->_placeholder;

    ffi_call(&(BLOCK_TYPE(tramp)->_cif), (void (*)(void))block->invoke, ret, args);

} /* of_call_imp_block */
#endif /* if defined(OF_HAVE_BLOCKS) */

static void of_call_IMP(ffi_cif * cif, void * ret, void ** args, void * userdata) {
    (void)cif;

    trampoline_pair_t * tramp = (__typeof__(tramp))userdata;

    void ** argv = (void **)calloc(SEL_TYPE(tramp)->_argc, sizeof(void *));

    if (NULL == argv)
        @throw [OFOutOfMemoryException exceptionWithRequestedSize:(SEL_TYPE(tramp)->_argc * sizeof(*argv))];

    objc_impl_placeholder_t * _objc_imp = SEL_TYPE(tramp)->_placeholder;

    argv[0] = &(_objc_imp->_object);
    argv[1] = &(_objc_imp->_selector);

    memmove(argv + 2, args, FFI_CLOSURE(tramp)->_argc * sizeof(*args));

    @try {
        ffi_call(&(SEL_TYPE(tramp)->_cif), (void (*)(void))_objc_imp->_implementation, ret, argv);
    } @finally {
        free(argv);
    }

} /* of_call_IMP */

#if defined(OF_HAVE_BLOCKS)
static ffi_handle_t ffi_closure_block(ffi_trampoline_t * trampoline, void * block);
static ffi_handle_t ffi_closure_imp_implementation_with_block(ffi_trampoline_t * trampoline, void * block);
#endif
static ffi_handle_t ffi_closure_implementation(ffi_trampoline_t * trampoline, id self, SEL cmd);

ffi_handle_t ffi_closure_new(int type, ...) {
    ffi_handle_t new_closure = FFI_INVALID_HANDLE;

    ffi_trampoline_t * trampoline = NULL;

    va_list args;

    switch (type) {
#if defined(OF_HAVE_BLOCKS)
        case FFI_TRAMPOLINE_BLOCK:
        case FFI_TRAMPOLINE_BLOCK_IMP:
#endif
        case FFI_TRAMPOLINE_SEL_IMP:
        {
            trampoline = new_trampoline(type);

            if (NULL != trampoline) {
                trampoline_pair_t * _ctx = (__typeof__(_ctx))trampoline;

                FFI_CLOSURE(_ctx)->_placeholder = ffi_closure_alloc(sizeof(ffi_closure), &(trampoline->_function));

                if (NULL == (FFI_CLOSURE(_ctx)->_placeholder)) {
                    delete_trampoline(trampoline);
                    trampoline = NULL;

                    break;
                }

                va_start(args, type);
            }
        }
        break;
        default:
            break;
    } /* switch */

    if (NULL != trampoline) {
#if defined(OF_HAVE_BLOCKS)
        if ((type == FFI_TRAMPOLINE_BLOCK) || (type == FFI_TRAMPOLINE_BLOCK_IMP)) {
            void * block = va_arg(args, void *);

            trampoline_pair_t * _ctx = (__typeof__(_ctx))trampoline;
            BLOCK_TYPE(_ctx)->_placeholder = Block_copy(block);

            new_closure = ((type == FFI_TRAMPOLINE_BLOCK) ? ffi_closure_block(trampoline, block) : ffi_closure_imp_implementation_with_block(trampoline, block));

        } else if (type == FFI_TRAMPOLINE_SEL_IMP) {
#else
        if (type == FFI_TRAMPOLINE_SEL_IMP) {
#endif
            id self = va_arg(args, id);
            SEL cmd = va_arg(args, SEL);

            new_closure = ffi_closure_implementation(trampoline, self, cmd);
        }

        va_end(args);

        if (FFI_INVALID_HANDLE == new_closure) {

            delete_trampoline(trampoline);

            trampoline = NULL;
        }
    }

    return new_closure;
} /* ffi_closure_new */

#if defined(OF_HAVE_BLOCKS)
static ffi_handle_t ffi_closure_block(ffi_trampoline_t * trampoline, void * block) {

    const char * blockSignature = of_block_signature(block);

    if (NULL != blockSignature) {
        int argc = 0;
        ffi_type * ret = NULL;

        ffi_type ** argv = NULL;

        @try {
            argv = of_cfunction_args_list(blockSignature, &argc, &ret, (void *(*)(void *, size_t)) & allocator_alloc, (trampoline->_memoryPool));
        } @catch (...) {
            return FFI_INVALID_HANDLE;
        }

        trampoline_pair_t * _ctx = (__typeof__(_ctx))trampoline;

        BLOCK_TYPE(_ctx)->_argc = (__typeof__(BLOCK_TYPE(_ctx)->_argc))argc;

        ffi_status rc;

        if ((rc = ffi_prep_cif(&(BLOCK_TYPE(_ctx)->_cif), FFI_DEFAULT_ABI, BLOCK_TYPE(_ctx)->_argc, ret, argv)) != FFI_OK)
            return FFI_INVALID_HANDLE;

        FFI_CLOSURE(_ctx)->_argc = (BLOCK_TYPE(_ctx)->_argc - 1);

        argv++;

        if ((rc = ffi_prep_cif(&(FFI_CLOSURE(_ctx)->_cif), FFI_DEFAULT_ABI, FFI_CLOSURE(_ctx)->_argc, ret, argv)) != FFI_OK)
            return FFI_INVALID_HANDLE;


        if ((rc = ffi_prep_closure_loc(FFI_CLOSURE(_ctx)->_placeholder, &(FFI_CLOSURE(_ctx)->_cif), trampoline->_call, _ctx, trampoline->_function)) != FFI_OK)
            return FFI_INVALID_HANDLE;

        return DISGUISE(trampoline);

    }

    return FFI_INVALID_HANDLE;
} /* ffi_closure_block */

static ffi_handle_t ffi_closure_imp_implementation_with_block(ffi_trampoline_t * trampoline, void * block) {
    const char * blockSignature = of_block_signature(block);

    if (NULL != blockSignature) {
        int argc = 0;
        ffi_type * ret = NULL;

        ffi_type ** argv = NULL;

        @try {
            argv = of_cfunction_args_list(blockSignature, &argc, &ret, (void *(*)(void *, size_t)) & allocator_alloc, (trampoline->_memoryPool));
        } @catch (...) {
            return FFI_INVALID_HANDLE;
        }

        trampoline_pair_t * _ctx = (__typeof__(_ctx))trampoline;

        BLOCK_TYPE(_ctx)->_argc = (__typeof__(BLOCK_TYPE(_ctx)->_argc))argc;

        ffi_status rc;

        if ((rc = ffi_prep_cif(&(BLOCK_TYPE(_ctx)->_cif), FFI_DEFAULT_ABI, BLOCK_TYPE(_ctx)->_argc, ret, argv)) != FFI_OK)
            return FFI_INVALID_HANDLE;

        FFI_CLOSURE(_ctx)->_argc = BLOCK_TYPE(_ctx)->_argc;

        if ((rc = ffi_prep_cif(&(FFI_CLOSURE(_ctx)->_cif), FFI_DEFAULT_ABI, FFI_CLOSURE(_ctx)->_argc, ret, argv)) != FFI_OK)
            return FFI_INVALID_HANDLE;


        if ((rc = ffi_prep_closure_loc(FFI_CLOSURE(_ctx)->_placeholder, &(FFI_CLOSURE(_ctx)->_cif), trampoline->_call, _ctx, trampoline->_function)) != FFI_OK)
            return FFI_INVALID_HANDLE;

        return DISGUISE(trampoline);

    }

    return FFI_INVALID_HANDLE;
} /* ffi_closure_imp_implementation_with_block */
#endif /* if defined(OF_HAVE_BLOCKS) */

static ffi_handle_t ffi_closure_implementation(ffi_trampoline_t * trampoline, id self, SEL cmd) {
    const char * methodSignature = [self typeEncodingForSelector:cmd];

    if (NULL != methodSignature) {
        IMP methodImplementation = [self methodForSelector:cmd];

        if (NULL != methodImplementation) {
            trampoline_pair_t * _ctx = (__typeof__(_ctx))trampoline;

            objc_impl_placeholder_t * _objc_imp = SEL_TYPE(_ctx)->_placeholder;

            _objc_imp->_object = self;
            _objc_imp->_selector = cmd;
            _objc_imp->_implementation = methodImplementation;

            int argc = 0;
            ffi_type * ret = NULL;

            ffi_type ** argv = NULL;

            @try {
                argv = of_cfunction_args_list(methodSignature, &argc, &ret, (void *(*)(void *, size_t)) & allocator_alloc, (trampoline->_memoryPool));
            } @catch (...) {
                return FFI_INVALID_HANDLE;
            }

            SEL_TYPE(_ctx)->_argc = (__typeof__(SEL_TYPE(_ctx)->_argc))argc;

            ffi_status rc;

            if ((rc = ffi_prep_cif(&(SEL_TYPE(_ctx)->_cif), FFI_DEFAULT_ABI, SEL_TYPE(_ctx)->_argc, ret, argv)) != FFI_OK)
                return FFI_INVALID_HANDLE;

            FFI_CLOSURE(_ctx)->_argc = (SEL_TYPE(_ctx)->_argc - 2);

            if ((rc = ffi_prep_cif(&(FFI_CLOSURE(_ctx)->_cif), FFI_DEFAULT_ABI, FFI_CLOSURE(_ctx)->_argc, ret, (argv + 2))) != FFI_OK)
                return FFI_INVALID_HANDLE;

            if ((rc = ffi_prep_closure_loc(FFI_CLOSURE(_ctx)->_placeholder, &(FFI_CLOSURE(_ctx)->_cif), trampoline->_call, _ctx, trampoline->_function)) != FFI_OK)
                return FFI_INVALID_HANDLE;

            return DISGUISE(trampoline);
        }
    }

    return FFI_INVALID_HANDLE;
} /* ffi_closure_implementation */


void ffi_closure_delete(ffi_handle_t handle) {
    ffi_trampoline_t * trampoline = (__typeof__(trampoline))UNDISGUISE(handle);

    if (trampoline != NULL)
        delete_trampoline(trampoline);
}

void * ffi_closure_function(ffi_handle_t handle) {
    ffi_trampoline_t * trampoline = (__typeof__(trampoline))UNDISGUISE(handle);

    if (trampoline != NULL)
        return trampoline->_function;

    return NULL;
}
