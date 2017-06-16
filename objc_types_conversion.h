#import <ObjFW/OFObject.h>

#include <ffi.h>

int of_cfunction_argc(const char * signature);

ffi_type ** of_cfunction_args_list(const char * signature, int * argc, ffi_type ** rvalue, void *(*allocator)(void *, size_t), void * ctx);

ffi_type * of_ctype_to_ffi_type(const char * type, void *(*allocator)(void *, size_t), void * ctx);

ffi_type * of_cstruct_to_ffi_struct(const char * type, void *(*allocator)(void *, size_t), void * ctx);
